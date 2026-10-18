// Package httpserver monta o servidor HTTP do Nenures.
//
// Fase 2: só o esqueleto (timeouts, /healthz, encerramento). As salas e o
// WebSocket chegam na Fase 4, depois da aprovação do protocolo (D1).
//
// Regra de logs: nenhum log por requisição. Nunca registrar IP, caminho com
// identificadores, conteúdo, convite ou ID de sala.
package httpserver

import (
	"net/http"
	"time"
)

// Limites de tempo aplicados a toda conexão HTTP.
const (
	ReadHeaderTimeout = 5 * time.Second
	ReadTimeout       = 15 * time.Second
	WriteTimeout      = 15 * time.Second
	IdleTimeout       = 60 * time.Second
	MaxHeaderBytes    = 8 << 10
)

// NewHandler devolve as rotas do servidor.
func NewHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write([]byte("ok\n"))
	})
	return mux
}

// New devolve um *http.Server com os limites do projeto.
func New(addr string) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           NewHandler(),
		ReadHeaderTimeout: ReadHeaderTimeout,
		ReadTimeout:       ReadTimeout,
		WriteTimeout:      WriteTimeout,
		IdleTimeout:       IdleTimeout,
		MaxHeaderBytes:    MaxHeaderBytes,
	}
}
