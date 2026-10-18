package relay

import (
	"crypto/rand"
	"crypto/subtle"
	"sync"
	"time"
)

type entry struct {
	seq   uint64
	frame []byte
	at    time.Time
}

type member struct {
	id       uint32
	token    [tokenLen]byte
	leaf     *uint32
	client   *client // nil enquanto estiver fora (janela de retomada)
	outbox   []entry // últimas mensagens, para a retomada (D9)
	outBytes int
	nextSeq  uint64
	grace    *time.Timer
	overflow bool // a fila estourou durante a queda: retomada impossível
}

type joiner struct {
	id     uint32
	client *client
	timer  *time.Timer
}

type room struct {
	id         [roomIDLen]byte
	epoch      uint64
	members    map[uint32]*member
	pending    map[uint32]*joiner
	locked     bool
	joinedOnce bool
	nextID     uint32
	expiry     *time.Timer
	deleted    bool
}

// Hub guarda todas as salas em memória. Um único mutex protege o estado:
// simples de verificar e suficiente para o porte previsto.
type Hub struct {
	cfg   Config
	mu    sync.Mutex
	rooms map[[roomIDLen]byte]*room
	conns int
	ips   *ipLimiter
	now   func() time.Time
}

func NewHub(cfg Config) *Hub {
	h := &Hub{cfg: cfg, rooms: map[[roomIDLen]byte]*room{}, now: time.Now}
	h.ips = newIPLimiter(&h.cfg, h.now())
	return h
}

// RoomCount devolve o número de salas em memória (métrica agregada).
func (h *Hub) RoomCount() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.rooms)
}

// ConnCount devolve o número de conexões abertas (métrica agregada).
func (h *Hub) ConnCount() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.conns
}

// Sweep limpa contadores ociosos de IP. Chamar periodicamente.
func (h *Hub) Sweep() { h.ips.sweep(h.now()) }

// Shutdown encerra todas as salas (reiniciar o servidor apaga as conversas).
func (h *Hub) Shutdown() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, r := range h.rooms {
		h.deleteRoom(r)
	}
}

func newToken() (t [tokenLen]byte) {
	if _, err := rand.Read(t[:]); err != nil {
		panic("relay: sem fonte de aleatoriedade")
	}
	return t
}

// ---------------------------------------------------------------- envio

func (h *Hub) direct(c *client, o outbound) { c.enqueue(mustJSON(o)) }

func (h *Hub) fail(c *client, code, detail string) {
	h.direct(c, outbound{T: "error", Code: code, Detail: detail})
}

// deliver envia a um membro com número de sequência e guarda na fila de
// retomada. Se o membro estiver fora, só guarda.
func (h *Hub) deliver(m *member, o outbound) {
	m.nextSeq++
	o.Seq = m.nextSeq
	frame := mustJSON(o)
	now := h.now()
	m.outbox = append(m.outbox, entry{seq: o.Seq, frame: frame, at: now})
	m.outBytes += len(frame)
	h.trim(m, now)
	if m.client != nil {
		m.client.enqueue(frame)
	}
}

func (h *Hub) trim(m *member, now time.Time) {
	drop := 0
	for drop < len(m.outbox) {
		e := m.outbox[drop]
		tooOld := now.Sub(e.at) > h.cfg.ResumeWindow
		tooBig := m.outBytes > h.cfg.MaxResumeBytes
		if !tooOld && !tooBig {
			break
		}
		if tooBig && m.client == nil {
			m.overflow = true
		}
		m.outBytes -= len(e.frame)
		drop++
	}
	if drop > 0 {
		m.outbox = append([]entry(nil), m.outbox[drop:]...)
	}
}

func (h *Hub) broadcast(r *room, except uint32, o outbound) {
	for id, m := range r.members {
		if id != except {
			h.deliver(m, o)
		}
	}
}

// ---------------------------------------------------------------- ciclo da sala

func (h *Hub) deleteRoom(r *room) {
	if r.deleted {
		return
	}
	r.deleted = true
	if r.expiry != nil {
		r.expiry.Stop()
	}
	for _, j := range r.pending {
		j.timer.Stop()
		h.fail(j.client, errNotFound, "")
		j.client.detachFromRoom()
		j.client.kick()
	}
	for _, m := range r.members {
		if m.grace != nil {
			m.grace.Stop()
		}
		if m.client != nil {
			m.client.detachFromRoom()
			m.client.kick()
		}
	}
	delete(h.rooms, r.id)
}

func (h *Hub) removeMember(r *room, m *member) {
	if m.grace != nil {
		m.grace.Stop()
	}
	delete(r.members, m.id)
	if m.leaf != nil {
		h.broadcast(r, 0, outbound{T: "gone", Leaf: u32(*m.leaf)})
	}
	if len(r.members) == 0 {
		h.deleteRoom(r) // P8: sem ninguém, a sala some
	}
}

// ---------------------------------------------------------------- operações

func (h *Hub) create(c *client, req *request) {
	if c.room != nil {
		h.fail(c, errBadRequest, "conexão já está numa sala")
		c.kick()
		return
	}
	if !h.ips.allowEvent(c.ip, "create", h.now()) {
		h.fail(c, errRateLimit, "")
		return
	}
	if _, ok := h.rooms[req.room]; ok {
		h.fail(c, errExists, "")
		return
	}
	if len(h.rooms) >= h.cfg.MaxRooms {
		h.fail(c, errBusy, "")
		return
	}
	r := &room{
		id:      req.room,
		members: map[uint32]*member{},
		pending: map[uint32]*joiner{},
		nextID:  2,
	}
	m := &member{id: 1, token: newToken(), client: c}
	r.members[1] = m
	h.rooms[r.id] = r
	c.attach(r, m.id, false)
	r.expiry = time.AfterFunc(h.cfg.KeyLifetime, func() { h.expire(r) })
	h.direct(c, outbound{
		T: "created", Member: m.id, Token: b64(m.token[:]),
		ExpiresIn: int(h.cfg.KeyLifetime / time.Second),
	})
}

// expire encerra a sala se ninguém além do criador entrou (P3).
func (h *Hub) expire(r *room) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if r.deleted || r.joinedOnce {
		return
	}
	for _, m := range r.members {
		if m.client != nil {
			h.direct(m.client, outbound{T: "expired"})
		}
	}
	h.deleteRoom(r)
}

func (h *Hub) join(c *client, req *request) {
	if c.room != nil {
		h.fail(c, errBadRequest, "conexão já está numa sala")
		c.kick()
		return
	}
	if !h.ips.allowEvent(c.ip, "join", h.now()) {
		h.fail(c, errRateLimit, "")
		return
	}
	r, ok := h.rooms[req.room]
	if !ok {
		h.fail(c, errNotFound, "")
		return
	}
	switch {
	case r.locked:
		h.fail(c, errLocked, "")
		return
	case len(r.members)+len(r.pending) >= h.cfg.MaxMembers:
		h.fail(c, errFull, "")
		return
	case len(r.pending) >= h.cfg.MaxPendingJoins:
		h.fail(c, errBusy, "")
		return
	}
	j := &joiner{id: r.nextID, client: c}
	r.nextID++
	r.pending[j.id] = j
	c.attach(r, j.id, true)
	j.timer = time.AfterFunc(h.cfg.JoinTimeout, func() { h.joinTimeout(r, j) })
	h.broadcast(r, 0, outbound{T: "join_request", From: j.id, Req: b64(req.req)})
}

func (h *Hub) joinTimeout(r *room, j *joiner) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if r.deleted || r.pending[j.id] != j {
		return
	}
	delete(r.pending, j.id)
	h.fail(j.client, errTimeout, "")
	j.client.detachFromRoom()
	j.client.kick()
}

func (h *Hub) commit(c *client, m *member, r *room, req *request) {
	var j *joiner
	if req.welcome != nil {
		j = r.pending[req.to]
		if j == nil {
			// Quem pediu já desistiu: o commit não é aceito.
			h.fail(c, errNotFound, "pedido de entrada não está mais pendente")
			return
		}
	}
	if req.epoch != r.epoch {
		h.direct(c, outbound{T: "commit_rejected", Epoch: u64(r.epoch)})
		return
	}
	accepted := r.epoch
	r.epoch++
	h.direct(c, outbound{T: "commit_ok", Epoch: u64(accepted)})
	h.broadcast(r, m.id, outbound{T: "commit", Epoch: u64(accepted), Data: b64(req.data)})
	if j != nil {
		j.timer.Stop()
		delete(r.pending, j.id)
		nm := &member{id: j.id, token: newToken(), client: j.client}
		r.members[nm.id] = nm
		j.client.attach(r, nm.id, false)
		r.joinedOnce = true
		if r.expiry != nil {
			r.expiry.Stop() // P4: depois da primeira entrada, a sala não expira por tempo
		}
		h.direct(j.client, outbound{
			T: "welcome", Data: b64(req.welcome), Member: nm.id,
			Token: b64(nm.token[:]), Epoch: u64(r.epoch),
		})
	}
}

func (h *Hub) resume(c *client, req *request) {
	if c.room != nil {
		h.fail(c, errBadRequest, "conexão já está numa sala")
		c.kick()
		return
	}
	r, ok := h.rooms[req.room]
	if !ok {
		h.fail(c, errBadToken, "")
		return
	}
	m := r.members[req.member]
	if m == nil || subtle.ConstantTimeCompare(m.token[:], req.token[:]) != 1 || m.overflow {
		h.fail(c, errBadToken, "")
		return
	}
	if m.grace != nil {
		m.grace.Stop()
		m.grace = nil
	}
	if old := m.client; old != nil {
		// A conexão antiga ainda parecia viva; a nova a substitui.
		old.detachFromRoom()
		old.kick()
	}
	m.client = c
	c.attach(r, m.id, false)
	h.direct(c, outbound{T: "resumed", Epoch: u64(r.epoch)})
	h.trim(m, h.now())
	for _, e := range m.outbox {
		if e.seq > req.last {
			c.enqueue(e.frame)
		}
	}
	if m.leaf != nil {
		h.broadcast(r, m.id, outbound{T: "back", Leaf: u32(*m.leaf)})
	}
}

// handle executa uma mensagem já validada.
func (h *Hub) handle(c *client, req *request) {
	h.mu.Lock()
	defer h.mu.Unlock()
	switch req.t {
	case "create":
		h.create(c, req)
		return
	case "join":
		h.join(c, req)
		return
	case "resume":
		h.resume(c, req)
		return
	}

	r, m := c.room, (*member)(nil)
	if r != nil && !c.pending {
		m = r.members[c.memberID]
	}
	if r == nil || r.deleted || m == nil || m.client != c {
		h.fail(c, errBadRequest, "operação exige ser membro de uma sala")
		c.kick()
		return
	}
	switch req.t {
	case "leaf":
		m.leaf = u32(req.leaf)
	case "commit":
		h.commit(c, m, r, req)
	case "proposal":
		h.broadcast(r, m.id, outbound{T: "proposal", Data: b64(req.data)})
	case "msg":
		h.broadcast(r, m.id, outbound{T: "msg", Data: b64(req.data)})
	case "lock":
		if !r.locked {
			r.locked = true
			h.broadcast(r, m.id, outbound{T: "locked"})
		}
	case "leave":
		c.detachFromRoom()
		h.removeMember(r, m)
		c.kick()
	}
}

// detach é chamado quando a leitura da conexão termina, por qualquer motivo.
func (h *Hub) detach(c *client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.conns--
	r := c.room
	if r == nil || r.deleted {
		return
	}
	if c.pending {
		if j := r.pending[c.memberID]; j != nil && j.client == c {
			j.timer.Stop()
			delete(r.pending, j.id)
		}
		return
	}
	m := r.members[c.memberID]
	if m == nil || m.client != c {
		return
	}
	// Queda sem `leave`: abre a janela de retomada (D9).
	m.client = nil
	if m.leaf != nil {
		h.broadcast(r, m.id, outbound{T: "away", Leaf: u32(*m.leaf)})
	}
	m.grace = time.AfterFunc(h.cfg.ResumeWindow, func() { h.graceExpired(r, m) })
}

func (h *Hub) graceExpired(r *room, m *member) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if r.deleted || r.members[m.id] != m || m.client != nil {
		return
	}
	h.removeMember(r, m)
}

// admit registra uma conexão nova; false se o servidor ou o IP estão no limite.
func (h *Hub) admit(c *client) (ok bool, code string) {
	if !h.ips.acquireConn(c.ip) {
		return false, errRateLimit
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.conns >= h.cfg.MaxConns {
		h.ips.releaseConn(c.ip)
		return false, errBusy
	}
	h.conns++
	return true, ""
}
