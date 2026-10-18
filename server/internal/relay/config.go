// Package relay implementa o Delivery Service do Nenures (docs/protocolo.md).
//
// O servidor ordena commits MLS e retransmite bytes opacos. Ele não decifra
// nem interpreta conteúdo, não grava nada em disco e não registra em log
// salas, tokens, IPs ou conteúdo.
package relay

import "time"

// Config reúne os limites da seção 8 de docs/protocolo.md. Os testes usam
// valores menores para os prazos.
type Config struct {
	KeyLifetime       time.Duration // P3: sala sem segundo participante expira
	ResumeWindow      time.Duration // D9: janela de retomada após queda
	JoinTimeout       time.Duration // pedido de entrada sem resposta
	FirstMessageWait  time.Duration // prazo para a primeira mensagem
	PingInterval      time.Duration
	PingTimeout       time.Duration
	WriteTimeout      time.Duration
	MaxMsgData        int // D10: bytes de `data` em `msg`
	MaxControlData    int // D10: bytes de commit, proposal, welcome, req
	MaxFrame          int64
	MaxMembers        int // D6
	MaxPendingJoins   int
	MaxResumeBytes    int
	MsgRate           float64 // mensagens por segundo por conexão
	MsgBurst          float64
	MaxConnsPerIP     int
	CreatesPerMinute  int
	JoinsPerMinute    int
	MaxRooms          int
	MaxConns          int
	SendQueue         int  // mensagens pendentes por conexão antes de cortá-la
	TrustForwardedFor bool // usar X-Forwarded-For quando a conexão vem do proxy local
}

// DefaultConfig devolve os valores iniciais aprovados.
func DefaultConfig() Config {
	return Config{
		KeyLifetime:       10 * time.Minute,
		ResumeWindow:      60 * time.Second,
		JoinTimeout:       30 * time.Second,
		FirstMessageWait:  10 * time.Second,
		PingInterval:      20 * time.Second,
		PingTimeout:       15 * time.Second,
		WriteTimeout:      10 * time.Second,
		MaxMsgData:        8 << 10,
		MaxControlData:    64 << 10,
		MaxFrame:          96 << 10,
		MaxMembers:        50,
		MaxPendingJoins:   5,
		MaxResumeBytes:    1 << 20,
		MsgRate:           20,
		MsgBurst:          40,
		MaxConnsPerIP:     16,
		CreatesPerMinute:  10,
		JoinsPerMinute:    30,
		MaxRooms:          10_000,
		MaxConns:          50_000,
		SendQueue:         256,
		TrustForwardedFor: true,
	}
}
