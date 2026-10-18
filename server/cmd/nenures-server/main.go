// Comando nenures-server: retransmissor do Nenures.
//
// O TLS fica no proxy (Caddy ou equivalente); este processo escuta só em
// endereço local. Configuração por variável de ambiente:
//
//	NENURES_ADDR  endereço de escuta (padrão 127.0.0.1:8080)
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"nenures/server/internal/httpserver"
)

func main() {
	addr := os.Getenv("NENURES_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	srv := httpserver.New(addr)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	errc := make(chan error, 1)
	go func() { errc <- srv.ListenAndServe() }()
	slog.Info("servidor iniciado")

	select {
	case err := <-errc:
		if !errors.Is(err, http.ErrServerClosed) {
			slog.Error("servidor parou", "erro", err)
			os.Exit(1)
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			slog.Error("encerramento com erro", "erro", err)
			os.Exit(1)
		}
		slog.Info("servidor encerrado")
	}
}
