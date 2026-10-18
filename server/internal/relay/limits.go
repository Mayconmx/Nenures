package relay

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"sync"
	"time"
)

// bucket limita mensagens por conexão (balde de fichas). Usado só pela
// goroutine de leitura da conexão; não precisa de trava.
type bucket struct {
	rate, burst, tokens float64
	last                time.Time
}

func newBucket(rate, burst float64, now time.Time) *bucket {
	return &bucket{rate: rate, burst: burst, tokens: burst, last: now}
}

func (b *bucket) allow(now time.Time) bool {
	b.tokens += now.Sub(b.last).Seconds() * b.rate
	if b.tokens > b.burst {
		b.tokens = b.burst
	}
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// ipKey é o HMAC-SHA256 do IP. O IP em claro nunca é guardado (D11).
type ipKey [32]byte

type ipState struct {
	conns   int
	creates []time.Time
	joins   []time.Time
}

// ipLimiter guarda contadores em memória, indexados pelo HMAC do IP com uma
// chave aleatória trocada a cada hora. Entradas sem conexões e sem eventos
// recentes são apagadas na limpeza periódica.
type ipLimiter struct {
	mu        sync.Mutex
	secret    [32]byte
	rotatedAt time.Time
	state     map[ipKey]*ipState
	cfg       *Config
}

func newIPLimiter(cfg *Config, now time.Time) *ipLimiter {
	l := &ipLimiter{state: map[ipKey]*ipState{}, cfg: cfg}
	l.rotate(now)
	return l
}

func (l *ipLimiter) rotate(now time.Time) {
	if _, err := rand.Read(l.secret[:]); err != nil {
		panic("relay: sem fonte de aleatoriedade")
	}
	l.rotatedAt = now
}

func (l *ipLimiter) key(ip string, now time.Time) ipKey {
	l.mu.Lock()
	defer l.mu.Unlock()
	if now.Sub(l.rotatedAt) >= time.Hour {
		l.rotate(now)
	}
	m := hmac.New(sha256.New, l.secret[:])
	m.Write([]byte(ip))
	var k ipKey
	copy(k[:], m.Sum(nil))
	return k
}

func (l *ipLimiter) get(k ipKey) *ipState {
	s := l.state[k]
	if s == nil {
		s = &ipState{}
		l.state[k] = s
	}
	return s
}

// acquireConn reserva uma conexão para o IP; false se passou do limite.
func (l *ipLimiter) acquireConn(k ipKey) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	s := l.get(k)
	if s.conns >= l.cfg.MaxConnsPerIP {
		return false
	}
	s.conns++
	return true
}

func (l *ipLimiter) releaseConn(k ipKey) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if s := l.state[k]; s != nil && s.conns > 0 {
		s.conns--
	}
}

func recent(ts []time.Time, now time.Time) []time.Time {
	out := ts[:0]
	for _, t := range ts {
		if now.Sub(t) < time.Minute {
			out = append(out, t)
		}
	}
	return out
}

// allowEvent registra um create ou join; false se passou do limite por minuto.
func (l *ipLimiter) allowEvent(k ipKey, kind string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	s := l.get(k)
	switch kind {
	case "create":
		s.creates = recent(s.creates, now)
		if len(s.creates) >= l.cfg.CreatesPerMinute {
			return false
		}
		s.creates = append(s.creates, now)
	case "join":
		s.joins = recent(s.joins, now)
		if len(s.joins) >= l.cfg.JoinsPerMinute {
			return false
		}
		s.joins = append(s.joins, now)
	}
	return true
}

// sweep apaga entradas ociosas. Chamado periodicamente pelo Hub.
func (l *ipLimiter) sweep(now time.Time) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if now.Sub(l.rotatedAt) >= time.Hour {
		l.rotate(now)
	}
	for k, s := range l.state {
		s.creates = recent(s.creates, now)
		s.joins = recent(s.joins, now)
		if s.conns == 0 && len(s.creates) == 0 && len(s.joins) == 0 {
			delete(l.state, k)
		}
	}
}

func (l *ipLimiter) size() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.state)
}
