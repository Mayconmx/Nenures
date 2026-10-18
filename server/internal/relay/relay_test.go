package relay

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"
)

// ---------------------------------------------------------------- apoio

func testConfig() Config {
	c := DefaultConfig()
	c.KeyLifetime = 2 * time.Second
	c.ResumeWindow = 400 * time.Millisecond
	c.JoinTimeout = 400 * time.Millisecond
	c.FirstMessageWait = 400 * time.Millisecond
	c.TrustForwardedFor = false
	return c
}

type env struct {
	t   *testing.T
	hub *Hub
	srv *httptest.Server
	url string
}

func newEnv(t *testing.T, cfg Config) *env {
	t.Helper()
	hub := NewHub(cfg)
	srv := httptest.NewServer(hub)
	t.Cleanup(func() { hub.Shutdown(); srv.Close() })
	return &env{t: t, hub: hub, srv: srv, url: "ws" + strings.TrimPrefix(srv.URL, "http")}
}

// wsc é um cliente de teste. Uma goroutine lê continuamente: no
// coder/websocket, uma leitura cujo contexto expira fecha a conexão, então os
// prazos de espera ficam no canal, não na leitura.
type wsc struct {
	t    *testing.T
	conn *websocket.Conn
	in   chan []byte
	errc chan error
}

func (e *env) dial() *wsc {
	e.t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, e.url, nil)
	if err != nil {
		e.t.Fatalf("dial: %v", err)
	}
	conn.SetReadLimit(1 << 20)
	e.t.Cleanup(func() { conn.CloseNow() })
	c := &wsc{t: e.t, conn: conn, in: make(chan []byte, 256), errc: make(chan error, 1)}
	go func() {
		for {
			_, b, err := conn.Read(context.Background())
			if err != nil {
				c.errc <- err
				return
			}
			c.in <- b
		}
	}()
	return c
}

func (c *wsc) sendRaw(b []byte) {
	c.t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := c.conn.Write(ctx, websocket.MessageText, b); err != nil {
		c.t.Fatalf("write: %v", err)
	}
}

func (c *wsc) send(m map[string]any) {
	c.t.Helper()
	b, _ := json.Marshal(m)
	c.sendRaw(b)
}

var errNoMessage = fmt.Errorf("nenhuma mensagem no prazo")

func (c *wsc) next(wait time.Duration) (map[string]any, error) {
	var b []byte
	select {
	case b = <-c.in:
	case err := <-c.errc:
		c.errc <- err // mantém o erro para chamadas seguintes
		return nil, err
	case <-time.After(wait):
		return nil, errNoMessage
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	return m, nil
}

// expect lê a próxima mensagem e exige o tipo t.
func (c *wsc) expect(t string) map[string]any {
	c.t.Helper()
	m, err := c.next(2 * time.Second)
	if err != nil {
		c.t.Fatalf("esperava %q: %v", t, err)
	}
	if m["t"] != t {
		c.t.Fatalf("esperava %q, veio %v", t, m)
	}
	return m
}

func (c *wsc) expectError(code string) {
	c.t.Helper()
	m := c.expect("error")
	if m["code"] != code {
		c.t.Fatalf("esperava erro %q, veio %v", code, m)
	}
}

// expectClosed exige que o servidor feche a conexão.
func (c *wsc) expectClosed() {
	c.t.Helper()
	for i := 0; i < 10; i++ {
		_, err := c.next(2 * time.Second)
		if err == errNoMessage {
			break
		}
		if err != nil {
			return
		}
	}
	c.t.Fatal("a conexão deveria ter sido fechada")
}

func (c *wsc) expectNothing(wait time.Duration) {
	c.t.Helper()
	m, err := c.next(wait)
	if err == nil {
		c.t.Fatalf("não esperava mensagem, veio %v", m)
	}
	if err != errNoMessage {
		c.t.Fatalf("a conexão caiu: %v", err)
	}
}

func rnd(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return base64.StdEncoding.EncodeToString(b)
}

func enc(s string) string { return base64.StdEncoding.EncodeToString([]byte(s)) }
func dec(t *testing.T, v any) string {
	b, err := base64.StdEncoding.DecodeString(v.(string))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func num(v any) float64 { return v.(float64) }

// sala com criador (a) e uma pessoa que entrou (b).
func (e *env) pair() (room string, a, b *wsc) {
	room = rnd(32)
	a = e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	a.expect("created")
	a.send(map[string]any{"t": "leaf", "leaf": 0})
	b = e.dial()
	b.send(map[string]any{"t": "join", "room": room, "req": enc("pedido-selado")})
	jr := a.expect("join_request")
	a.send(map[string]any{"t": "commit", "epoch": 0, "data": enc("commit-add"), "welcome": enc("welcome"), "to": jr["from"]})
	a.expect("commit_ok")
	w := b.expect("welcome")
	if dec(e.t, w["data"]) != "welcome" || num(w["epoch"]) != 1 {
		e.t.Fatalf("welcome inesperado: %v", w)
	}
	b.send(map[string]any{"t": "leaf", "leaf": 1})
	return room, a, b
}

// ---------------------------------------------------------------- salas

func TestCreateAndDuplicate(t *testing.T) {
	e := newEnv(t, testConfig())
	room := rnd(32)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	m := a.expect("created")
	if num(m["member"]) != 1 || m["token"] == "" || num(m["expires_in"]) != 2 {
		t.Fatalf("created inesperado: %v", m)
	}
	b := e.dial()
	b.send(map[string]any{"t": "create", "room": room})
	b.expectError(errExists)
	if e.hub.RoomCount() != 1 {
		t.Fatal("deveria haver uma sala")
	}
}

func TestJoinUnknownRoom(t *testing.T) {
	e := newEnv(t, testConfig())
	c := e.dial()
	c.send(map[string]any{"t": "join", "room": rnd(32), "req": enc("x")})
	c.expectError(errNotFound)
}

func TestFullFlowMessagesBothWays(t *testing.T) {
	e := newEnv(t, testConfig())
	_, a, b := e.pair()
	b.send(map[string]any{"t": "msg", "data": enc("oi")})
	m := a.expect("msg")
	if dec(t, m["data"]) != "oi" || num(m["seq"]) < 1 {
		t.Fatalf("msg inesperada: %v", m)
	}
	a.send(map[string]any{"t": "msg", "data": enc("olá")})
	if dec(t, b.expect("msg")["data"]) != "olá" {
		t.Fatal("conteúdo alterado")
	}
	b.expectNothing(100 * time.Millisecond) // quem envia não recebe de volta
}

func TestKeyExpiresWithoutSecondParticipant(t *testing.T) {
	cfg := testConfig()
	cfg.KeyLifetime = 300 * time.Millisecond
	e := newEnv(t, cfg)
	room := rnd(32)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	a.expect("created")
	a.expect("expired")
	a.expectClosed()
	c := e.dial()
	c.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	c.expectError(errNotFound)
}

func TestNoExpiryAfterSomeoneJoined(t *testing.T) {
	cfg := testConfig()
	cfg.KeyLifetime = 300 * time.Millisecond
	e := newEnv(t, cfg)
	_, a, b := e.pair()
	time.Sleep(500 * time.Millisecond)
	a.send(map[string]any{"t": "msg", "data": enc("ainda aqui")})
	if dec(t, b.expect("msg")["data"]) != "ainda aqui" {
		t.Fatal("sala deveria continuar (P4)")
	}
}

// ---------------------------------------------------------------- commits

func TestConcurrentCommitsOneWins(t *testing.T) {
	e := newEnv(t, testConfig())
	_, a, b := e.pair()
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); a.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("de-a")}) }()
	go func() { defer wg.Done(); b.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("de-b")}) }()
	wg.Wait()

	// Cada lado recebe: o vencedor só `commit_ok`; o perdedor `commit` (do
	// vencedor) e `commit_rejected`, em qualquer ordem.
	collect := func(c *wsc) map[string]map[string]any {
		got := map[string]map[string]any{}
		for {
			m, err := c.next(300 * time.Millisecond)
			if err != nil {
				return got
			}
			got[m["t"].(string)] = m
		}
	}
	ga, gb := collect(a), collect(b)
	winner, loser := ga, gb
	if _, ok := gb["commit_ok"]; ok {
		winner, loser = gb, ga
	}
	if len(winner) != 1 || winner["commit_ok"] == nil {
		t.Fatalf("vencedor deveria receber só commit_ok: %v", winner)
	}
	if loser["commit_rejected"] == nil || loser["commit"] == nil || len(loser) != 2 {
		t.Fatalf("perdedor deveria receber commit e commit_rejected: %v", loser)
	}
	if num(loser["commit_rejected"]["epoch"]) != 2 || num(loser["commit"]["epoch"]) != 1 {
		t.Fatalf("épocas inesperadas: %v", loser)
	}
}

func TestCommitOrdering(t *testing.T) {
	e := newEnv(t, testConfig())
	_, a, b := e.pair()
	a.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("de-a")})
	a.expect("commit_ok")
	got := b.expect("commit")
	if num(got["epoch"]) != 1 || dec(t, got["data"]) != "de-a" {
		t.Fatalf("commit inesperado: %v", got)
	}
	// b ainda acha que a época é 1: recusado e informado da atual.
	b.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("de-b")})
	rej := b.expect("commit_rejected")
	if num(rej["epoch"]) != 2 {
		t.Fatalf("época atual deveria ser 2: %v", rej)
	}
	a.expectNothing(100 * time.Millisecond)
}

func TestWelcomeOnlyForPendingJoiner(t *testing.T) {
	e := newEnv(t, testConfig())
	_, a, _ := e.pair()
	a.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("x"), "welcome": enc("w"), "to": 99})
	a.expectError(errNotFound)
	// O commit não foi aceito: a época continua 1.
	a.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("y")})
	a.expect("commit_ok")
}

// ---------------------------------------------------------------- entrada

func TestJoinTimeout(t *testing.T) {
	e := newEnv(t, testConfig())
	room := rnd(32)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	a.expect("created")
	b := e.dial()
	b.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	a.expect("join_request")
	b.expectError(errTimeout)
	b.expectClosed()
}

func TestLockRefusesNewJoins(t *testing.T) {
	e := newEnv(t, testConfig())
	room, a, b := e.pair()
	a.send(map[string]any{"t": "lock"})
	b.expect("locked")
	c := e.dial()
	c.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	c.expectError(errLocked)
}

func TestRoomFull(t *testing.T) {
	cfg := testConfig()
	cfg.MaxMembers = 2
	e := newEnv(t, cfg)
	room, _, _ := e.pair()
	c := e.dial()
	c.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	c.expectError(errFull)
}

// ---------------------------------------------------------------- saída

func TestLeaveAndLastOneOut(t *testing.T) {
	e := newEnv(t, testConfig())
	room, a, b := e.pair()
	b.send(map[string]any{"t": "leave"})
	g := a.expect("gone")
	if num(g["leaf"]) != 1 {
		t.Fatalf("gone inesperado: %v", g)
	}
	b.expectClosed()
	a.send(map[string]any{"t": "leave"})
	a.expectClosed()
	waitFor(t, func() bool { return e.hub.RoomCount() == 0 }, "a sala deveria sumir (P8)")
	c := e.dial()
	c.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	c.expectError(errNotFound)
}

// ---------------------------------------------------------------- queda e retomada

func TestResumeDeliversMissedMessages(t *testing.T) {
	e := newEnv(t, testConfig())
	room := rnd(32)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	a.expect("created")
	a.send(map[string]any{"t": "leaf", "leaf": 0})
	b := e.dial()
	b.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	jr := a.expect("join_request")
	a.send(map[string]any{"t": "commit", "epoch": 0, "data": enc("c"), "welcome": enc("w"), "to": jr["from"]})
	a.expect("commit_ok")
	w := b.expect("welcome")
	b.send(map[string]any{"t": "leaf", "leaf": 1})

	a.send(map[string]any{"t": "msg", "data": enc("antes")})
	seq := num(b.expect("msg")["seq"])

	b.conn.CloseNow()
	a.expect("away")
	a.send(map[string]any{"t": "msg", "data": enc("durante-1")})
	a.send(map[string]any{"t": "commit", "epoch": 1, "data": enc("commit-durante")})
	a.expect("commit_ok")

	b2 := e.dial()
	b2.send(map[string]any{"t": "resume", "room": room, "member": w["member"], "token": w["token"], "last": seq})
	if num(b2.expect("resumed")["epoch"]) != 2 {
		t.Fatal("época na retomada deveria ser 2")
	}
	if dec(t, b2.expect("msg")["data"]) != "durante-1" {
		t.Fatal("perdeu mensagem durante a queda")
	}
	if dec(t, b2.expect("commit")["data"]) != "commit-durante" {
		t.Fatal("perdeu commit durante a queda")
	}
	if num(a.expect("back")["leaf"]) != 1 {
		t.Fatal("back deveria indicar a folha 1")
	}

	// Token errado não retoma.
	c := e.dial()
	c.send(map[string]any{"t": "resume", "room": room, "member": w["member"], "token": rnd(32), "last": 0})
	c.expectError(errBadToken)
}

func TestResumeAfterWindowFails(t *testing.T) {
	e := newEnv(t, testConfig())
	room := rnd(32)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	a.expect("created")
	b := e.dial()
	b.send(map[string]any{"t": "join", "room": room, "req": enc("x")})
	jr := a.expect("join_request")
	a.send(map[string]any{"t": "commit", "epoch": 0, "data": enc("c"), "welcome": enc("w"), "to": jr["from"]})
	a.expect("commit_ok")
	w := b.expect("welcome")
	b.send(map[string]any{"t": "leaf", "leaf": 1})
	time.Sleep(50 * time.Millisecond)
	b.conn.CloseNow()
	a.expect("away")
	g := a.expect("gone") // passou a janela de 400 ms
	if num(g["leaf"]) != 1 {
		t.Fatalf("gone inesperado: %v", g)
	}
	b2 := e.dial()
	b2.send(map[string]any{"t": "resume", "room": room, "member": w["member"], "token": w["token"], "last": 0})
	b2.expectError(errBadToken)
}

func TestRoomSurvivesWhileSomeoneCanResume(t *testing.T) {
	e := newEnv(t, testConfig())
	room := rnd(32)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": room})
	created := a.expect("created")
	a.conn.CloseNow()
	waitFor(t, func() bool { return e.hub.ConnCount() == 0 }, "conexão deveria fechar")
	if e.hub.RoomCount() != 1 {
		t.Fatal("a sala deveria esperar a janela de retomada")
	}
	a2 := e.dial()
	a2.send(map[string]any{"t": "resume", "room": room, "member": created["member"], "token": created["token"], "last": 0})
	a2.expect("resumed")
	a2.conn.CloseNow()
	waitFor(t, func() bool { return e.hub.RoomCount() == 0 }, "sem ninguém e sem retomada, a sala some")
}

// ---------------------------------------------------------------- frames inválidos

func TestInvalidFrames(t *testing.T) {
	e := newEnv(t, testConfig())
	cases := map[string][]byte{
		"json inválido":          []byte(`{`),
		"tipo desconhecido":      []byte(`{"t":"hack"}`),
		"campo extra":            []byte(`{"t":"create","room":"` + rnd(32) + `","x":1}`),
		"campo de outro tipo":    []byte(`{"t":"create","room":"` + rnd(32) + `","data":"eA=="}`),
		"room curto":             []byte(`{"t":"create","room":"` + rnd(8) + `"}`),
		"base64 inválido":        []byte(`{"t":"join","room":"` + rnd(32) + `","req":"***"}`),
		"primeira não é entrada": []byte(`{"t":"msg","data":"eA=="}`),
		"dois objetos":           []byte(`{"t":"lock"}{"t":"lock"}`),
	}
	for name, frame := range cases {
		t.Run(name, func(t *testing.T) {
			c := e.dial()
			c.sendRaw(frame)
			c.expectError(errBadRequest)
			c.expectClosed()
		})
	}
}

func TestMessageTooLarge(t *testing.T) {
	cfg := testConfig()
	e := newEnv(t, cfg)
	_, a, _ := e.pair()
	a.send(map[string]any{"t": "msg", "data": rnd(cfg.MaxMsgData + 1)})
	a.expectError(errTooLarge)
	a.expectClosed()
}

func TestFrameAboveReadLimitClosesConnection(t *testing.T) {
	cfg := testConfig()
	cfg.MaxFrame = 1024
	e := newEnv(t, cfg)
	c := e.dial()
	c.sendRaw([]byte(`{"t":"create","room":"` + strings.Repeat("A", 2000) + `"}`))
	c.expectClosed()
}

func TestFirstMessageDeadline(t *testing.T) {
	e := newEnv(t, testConfig())
	c := e.dial()
	c.expectClosed() // FirstMessageWait = 400 ms
}

// ---------------------------------------------------------------- limites

func TestMessageRateLimit(t *testing.T) {
	cfg := testConfig()
	cfg.MsgRate, cfg.MsgBurst = 5, 5
	e := newEnv(t, cfg)
	_, a, b := e.pair() // usa 2 mensagens de a (create, leaf, commit = 3)
	for i := 0; i < 10; i++ {
		a.send(map[string]any{"t": "msg", "data": enc(fmt.Sprint(i))})
	}
	limited := false
	for i := 0; i < 10; i++ {
		m, err := a.next(300 * time.Millisecond)
		if err != nil {
			break
		}
		if m["t"] == "error" && m["code"] == errRateLimit {
			limited = true
			break
		}
	}
	if !limited {
		t.Fatal("deveria limitar a taxa")
	}
	_ = b
}

func TestPerIPConnectionLimit(t *testing.T) {
	cfg := testConfig()
	cfg.MaxConnsPerIP = 2
	cfg.FirstMessageWait = 5 * time.Second
	e := newEnv(t, cfg)
	e.dial()
	e.dial()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, res, err := websocket.Dial(ctx, e.url, nil)
	if err == nil || res == nil || res.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("terceira conexão do mesmo IP deveria ser recusada com 429 (err=%v)", err)
	}
}

func TestCreateRateLimitPerIP(t *testing.T) {
	cfg := testConfig()
	cfg.CreatesPerMinute = 2
	e := newEnv(t, cfg)
	for i := 0; i < 2; i++ {
		c := e.dial()
		c.send(map[string]any{"t": "create", "room": rnd(32)})
		c.expect("created")
	}
	c := e.dial()
	c.send(map[string]any{"t": "create", "room": rnd(32)})
	c.expectError(errRateLimit)
}

func TestGlobalRoomLimit(t *testing.T) {
	cfg := testConfig()
	cfg.MaxRooms = 1
	e := newEnv(t, cfg)
	a := e.dial()
	a.send(map[string]any{"t": "create", "room": rnd(32)})
	a.expect("created")
	b := e.dial()
	b.send(map[string]any{"t": "create", "room": rnd(32)})
	b.expectError(errBusy)
}

// ---------------------------------------------------------------- prazos do http.Server

func TestHTTPServerTimeoutsDoNotKillWebSocket(t *testing.T) {
	hub := NewHub(testConfig())
	srv := httptest.NewUnstartedServer(hub)
	srv.Config.ReadTimeout = 200 * time.Millisecond
	srv.Config.WriteTimeout = 200 * time.Millisecond
	srv.Start()
	t.Cleanup(func() { hub.Shutdown(); srv.Close() })
	e := &env{t: t, hub: hub, srv: srv, url: "ws" + strings.TrimPrefix(srv.URL, "http")}
	_, a, b := e.pair()
	time.Sleep(600 * time.Millisecond)
	a.send(map[string]any{"t": "msg", "data": enc("depois do prazo")})
	if dec(t, b.expect("msg")["data"]) != "depois do prazo" {
		t.Fatal("a conexão não pode cair pelos prazos do http.Server")
	}
}

// ---------------------------------------------------------------- concorrência

func TestManyRoomsConcurrently(t *testing.T) {
	cfg := testConfig()
	cfg.MaxConnsPerIP = 1000
	cfg.CreatesPerMinute = 1000
	cfg.JoinsPerMinute = 1000
	e := newEnv(t, cfg)
	var wg sync.WaitGroup
	errs := make(chan string, 40)
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			defer func() {
				if r := recover(); r != nil {
					errs <- fmt.Sprint(r)
				}
			}()
			_, a, b := e.pair()
			for j := 0; j < 20; j++ {
				a.send(map[string]any{"t": "msg", "data": enc(fmt.Sprintf("%d-%d", i, j))})
			}
			for j := 0; j < 20; j++ {
				if got := dec(t, b.expect("msg")["data"]); got != fmt.Sprintf("%d-%d", i, j) {
					errs <- "ordem ou sala trocada: " + got
					return
				}
			}
			b.send(map[string]any{"t": "leave"})
			a.send(map[string]any{"t": "leave"})
		}(i)
	}
	wg.Wait()
	close(errs)
	for e := range errs {
		t.Error(e)
	}
	waitFor(t, func() bool { return e.hub.RoomCount() == 0 }, "todas as salas deveriam sumir")
}

// ---------------------------------------------------------------- privacidade

func TestNothingSensitiveInLogs(t *testing.T) {
	var buf bytes.Buffer
	old := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug})))
	defer slog.SetDefault(old)

	e := newEnv(t, testConfig())
	room, a, b := e.pair()
	a.send(map[string]any{"t": "msg", "data": enc("segredo")})
	b.expect("msg")
	b.conn.CloseNow()
	a.expect("away")

	for _, s := range []string{room, enc("segredo"), "segredo", "127.0.0.1", enc("pedido-selado")} {
		if strings.Contains(buf.String(), s) {
			t.Fatalf("log contém dado sensível: %q", s)
		}
	}
}

func TestNoDiskWritesInRelay(t *testing.T) {
	forbidden := []string{"os.Create", "os.WriteFile", "os.OpenFile", "os.Mkdir", "ioutil.WriteFile", "database/sql", "os.Stdout", "fmt.Print", "log.Print"}
	files, _ := filepath.Glob("*.go")
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		src, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		for _, s := range forbidden {
			if strings.Contains(string(src), s) {
				t.Errorf("%s usa %s: o relay não grava em disco nem escreve logs", f, s)
			}
		}
	}
}

func waitFor(t *testing.T, cond func() bool, msg string) {
	t.Helper()
	for i := 0; i < 100; i++ {
		if cond() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal(msg)
}
