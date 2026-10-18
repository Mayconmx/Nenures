// Package httpserver monta o servidor HTTP do Nenures.
//
// Regra de logs: nenhum log por requisição. Nunca registrar IP, caminho com
// identificadores, conteúdo, convite ou ID de sala.
package httpserver

import (
	"net/http"
	"time"
)

// Limites de tempo aplicados à fase HTTP. As conexões WebSocket de /v1 têm
// seus próprios prazos (internal/relay).
const (
	ReadHeaderTimeout = 5 * time.Second
	ReadTimeout       = 15 * time.Second
	WriteTimeout      = 15 * time.Second
	IdleTimeout       = 60 * time.Second
	MaxHeaderBytes    = 8 << 10
)

// NewHandler devolve as rotas do servidor. relay atende o WebSocket em /v1;
// nil deixa a rota de fora (usado em testes do HTTP puro).
func NewHandler(relay http.Handler) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write([]byte("ok\n"))
	})
	if relay != nil {
		mux.Handle("GET /v1", relay)
	}
	return mux
}

// New devolve um *http.Server com os limites do projeto.
//
// ReadTimeout e WriteTimeout do http.Server não valem para conexões
// WebSocket já aceitas (a conexão é sequestrada); elas usam os prazos do relay.
func New(addr string, relay http.Handler) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           NewHandler(relay),
		ReadHeaderTimeout: ReadHeaderTimeout,
		ReadTimeout:       ReadTimeout,
		WriteTimeout:      WriteTimeout,
		IdleTimeout:       IdleTimeout,
		MaxHeaderBytes:    MaxHeaderBytes,
	}
}
