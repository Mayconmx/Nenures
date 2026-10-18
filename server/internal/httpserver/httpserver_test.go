package httpserver

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthz(t *testing.T) {
	srv := httptest.NewServer(NewHandler(nil))
	defer srv.Close()

	res, err := http.Get(srv.URL + "/healthz")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)

	if res.StatusCode != http.StatusOK || string(body) != "ok\n" {
		t.Fatalf("got %d %q, want 200 \"ok\\n\"", res.StatusCode, body)
	}
	if got := res.Header.Get("Cache-Control"); got != "no-store" {
		t.Fatalf("Cache-Control = %q, want no-store", got)
	}
}

func TestUnknownRouteIs404(t *testing.T) {
	srv := httptest.NewServer(NewHandler(nil))
	defer srv.Close()

	res, err := http.Get(srv.URL + "/v1")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusNotFound {
		t.Fatalf("got %d, want 404", res.StatusCode)
	}
}

func TestHealthzRejectsPost(t *testing.T) {
	srv := httptest.NewServer(NewHandler(nil))
	defer srv.Close()

	res, err := http.Post(srv.URL+"/healthz", "text/plain", nil)
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusMethodNotAllowed {
		t.Fatalf("got %d, want 405", res.StatusCode)
	}
}

func TestServerHasTimeouts(t *testing.T) {
	s := New(":0", nil)
	if s.ReadHeaderTimeout == 0 || s.ReadTimeout == 0 || s.WriteTimeout == 0 || s.IdleTimeout == 0 {
		t.Fatal("todos os timeouts precisam estar definidos")
	}
	if s.MaxHeaderBytes != MaxHeaderBytes {
		t.Fatalf("MaxHeaderBytes = %d, want %d", s.MaxHeaderBytes, MaxHeaderBytes)
	}
}
