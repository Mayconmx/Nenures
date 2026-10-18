package relay

import (
	"context"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"
)

// client é uma conexão WebSocket. Os campos room, memberID e pending são
// protegidos por Hub.mu; o resto pertence às goroutines da conexão.
type client struct {
	hub  *Hub
	conn *websocket.Conn
	ip   ipKey

	send      chan []byte
	quit      chan struct{}
	quitOnce  sync.Once
	writeDone chan struct{}

	room     *room
	memberID uint32
	pending  bool
}

func (c *client) attach(r *room, id uint32, pending bool) {
	c.room, c.memberID, c.pending = r, id, pending
}

func (c *client) detachFromRoom() { c.room, c.memberID, c.pending = nil, 0, false }

// enqueue nunca bloqueia. Se o cliente não acompanha o ritmo, a conexão é
// cortada; o que ficou para trás está na fila de retomada (D9).
func (c *client) enqueue(frame []byte) {
	select {
	case <-c.quit:
	case c.send <- frame:
	default:
		c.kick()
	}
}

// kick pede o fechamento: o escritor envia o que já estava na fila e fecha.
func (c *client) kick() { c.quitOnce.Do(func() { close(c.quit) }) }

func (c *client) closing() bool {
	select {
	case <-c.quit:
		return true
	default:
		return false
	}
}

func (c *client) writeLoop() {
	defer close(c.writeDone)
	cfg := &c.hub.cfg
	ping := time.NewTicker(cfg.PingInterval)
	defer ping.Stop()
	write := func(frame []byte) bool {
		ctx, cancel := context.WithTimeout(context.Background(), cfg.WriteTimeout)
		defer cancel()
		return c.conn.Write(ctx, websocket.MessageText, frame) == nil
	}
	for {
		select {
		case frame := <-c.send:
			if !write(frame) {
				c.kick()
				c.conn.CloseNow()
				return
			}
		case <-ping.C:
			ctx, cancel := context.WithTimeout(context.Background(), cfg.PingTimeout)
			err := c.conn.Ping(ctx)
			cancel()
			if err != nil {
				c.kick()
				c.conn.CloseNow()
				return
			}
		case <-c.quit:
			for {
				select {
				case frame := <-c.send:
					if !write(frame) {
						c.conn.CloseNow()
						return
					}
				default:
					c.conn.Close(websocket.StatusNormalClosure, "")
					return
				}
			}
		}
	}
}

func (c *client) readLoop() {
	cfg := &c.hub.cfg
	bucket := newBucket(cfg.MsgRate, cfg.MsgBurst, c.hub.now())
	first := true
	for !c.closing() {
		ctx, cancel := context.Background(), context.CancelFunc(func() {})
		if first {
			ctx, cancel = context.WithTimeout(ctx, cfg.FirstMessageWait)
		}
		typ, data, err := c.conn.Read(ctx)
		cancel()
		if err != nil {
			return
		}
		if typ != websocket.MessageText {
			c.hub.fail(c, errBadRequest, "use frames de texto")
			c.kick()
			continue
		}
		if !bucket.allow(c.hub.now()) {
			c.hub.fail(c, errRateLimit, "")
			continue
		}
		req, perr := parseRequest(data, cfg)
		if perr != nil {
			c.hub.fail(c, perr.code, perr.detail)
			c.kick()
			continue
		}
		if first && req.t != "create" && req.t != "join" && req.t != "resume" {
			c.hub.fail(c, errBadRequest, "primeira mensagem precisa ser create, join ou resume")
			c.kick()
			continue
		}
		first = false
		c.hub.handle(c, req)
	}
}

// clientIP usa o endereço da conexão. Atrás do proxy local, usa a última
// entrada de X-Forwarded-For (a que o próprio proxy acrescentou).
func clientIP(r *http.Request, trustProxy bool) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	if trustProxy {
		if ip := net.ParseIP(host); ip != nil && ip.IsLoopback() {
			if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
				parts := strings.Split(xff, ",")
				if last := strings.TrimSpace(parts[len(parts)-1]); last != "" {
					return last
				}
			}
		}
	}
	return host
}

// ServeHTTP atende /v1. Nenhum log por conexão.
func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	c := &client{
		hub:       h,
		ip:        h.ips.key(clientIP(r, h.cfg.TrustForwardedFor), h.now()),
		send:      make(chan []byte, h.cfg.SendQueue),
		quit:      make(chan struct{}),
		writeDone: make(chan struct{}),
	}
	if ok, code := h.admit(c); !ok {
		status := http.StatusTooManyRequests
		if code == errBusy {
			status = http.StatusServiceUnavailable
		}
		http.Error(w, code, status)
		return
	}
	// O http.Server aplica ReadTimeout/WriteTimeout à conexão e esses prazos
	// continuam valendo depois do upgrade (net/http, documentação de Hijack).
	// Sem limpá-los, toda conversa cairia após 15 s. Os prazos do WebSocket
	// são controlados aqui (ping, WriteTimeout, FirstMessageWait).
	rc := http.NewResponseController(w)
	_ = rc.SetReadDeadline(time.Time{})
	_ = rc.SetWriteDeadline(time.Time{})
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		CompressionMode: websocket.CompressionDisabled,
	})
	if err != nil {
		h.mu.Lock()
		h.conns--
		h.mu.Unlock()
		h.ips.releaseConn(c.ip)
		return
	}
	conn.SetReadLimit(h.cfg.MaxFrame)
	c.conn = conn

	go c.writeLoop()
	c.readLoop()
	c.kick()
	h.detach(c)
	h.ips.releaseConn(c.ip)
	<-c.writeDone
}
