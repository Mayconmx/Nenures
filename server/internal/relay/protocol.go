package relay

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
)

// Códigos de erro (docs/protocolo.md, seção 7).
const (
	errBadRequest = "bad_request"
	errTooLarge   = "too_large"
	errRateLimit  = "rate_limited"
	errNotFound   = "not_found"
	errExists     = "exists"
	errLocked     = "locked"
	errFull       = "full"
	errTimeout    = "timeout"
	errBadToken   = "bad_token"
	errBusy       = "busy"
)

const roomIDLen = 32
const tokenLen = 32

// inbound é a união de todos os campos que o cliente pode enviar. A
// validação por tipo (validate) garante que só os campos certos vieram.
type inbound struct {
	T       string  `json:"t"`
	Room    *string `json:"room,omitempty"`
	Req     *string `json:"req,omitempty"`
	Member  *uint32 `json:"member,omitempty"`
	Token   *string `json:"token,omitempty"`
	Last    *uint64 `json:"last,omitempty"`
	Leaf    *uint32 `json:"leaf,omitempty"`
	Epoch   *uint64 `json:"epoch,omitempty"`
	Data    *string `json:"data,omitempty"`
	Welcome *string `json:"welcome,omitempty"`
	To      *uint32 `json:"to,omitempty"`
}

// request é a mensagem já validada e decodificada.
type request struct {
	t       string
	room    [roomIDLen]byte
	req     []byte
	member  uint32
	token   [tokenLen]byte
	last    uint64
	leaf    uint32
	epoch   uint64
	data    []byte
	welcome []byte
	to      uint32
}

type protoError struct {
	code   string
	detail string
}

func (e *protoError) Error() string { return e.code + ": " + e.detail }

func bad(detail string) *protoError   { return &protoError{errBadRequest, detail} }
func large(detail string) *protoError { return &protoError{errTooLarge, detail} }

// campos permitidos por tipo; os obrigatórios são todos, exceto os opcionais.
var schema = map[string]struct{ required, optional []string }{
	"create":   {required: []string{"room"}},
	"join":     {required: []string{"room", "req"}},
	"resume":   {required: []string{"room", "member", "token", "last"}},
	"leaf":     {required: []string{"leaf"}},
	"commit":   {required: []string{"epoch", "data"}, optional: []string{"welcome", "to"}},
	"proposal": {required: []string{"data"}},
	"msg":      {required: []string{"data"}},
	"lock":     {},
	"leave":    {},
}

func present(in *inbound) map[string]bool {
	return map[string]bool{
		"room": in.Room != nil, "req": in.Req != nil, "member": in.Member != nil,
		"token": in.Token != nil, "last": in.Last != nil, "leaf": in.Leaf != nil,
		"epoch": in.Epoch != nil, "data": in.Data != nil, "welcome": in.Welcome != nil,
		"to": in.To != nil,
	}
}

func decodeB64(field, s string, max int) ([]byte, *protoError) {
	if base64.StdEncoding.DecodedLen(len(s)) > max+3 {
		return nil, large(field)
	}
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		return nil, bad("base64 inválido em " + field)
	}
	if len(b) > max {
		return nil, large(field)
	}
	return b, nil
}

func decodeFixed(field, s string, out []byte) *protoError {
	b, perr := decodeB64(field, s, len(out))
	if perr != nil {
		return perr
	}
	if len(b) != len(out) {
		return bad(fmt.Sprintf("%s precisa ter %d bytes", field, len(out)))
	}
	copy(out, b)
	return nil
}

// parseRequest decodifica e valida uma mensagem do cliente.
func parseRequest(frame []byte, cfg *Config) (*request, *protoError) {
	dec := json.NewDecoder(bytes.NewReader(frame))
	dec.DisallowUnknownFields()
	var in inbound
	if err := dec.Decode(&in); err != nil {
		return nil, bad("json inválido")
	}
	if dec.More() {
		return nil, bad("mais de um objeto no frame")
	}
	sc, ok := schema[in.T]
	if !ok {
		return nil, bad("tipo desconhecido")
	}
	has := present(&in)
	allowed := map[string]bool{}
	for _, f := range sc.required {
		allowed[f] = true
		if !has[f] {
			return nil, bad("campo obrigatório ausente: " + f)
		}
	}
	for _, f := range sc.optional {
		allowed[f] = true
	}
	for f, ok := range has {
		if ok && !allowed[f] {
			return nil, bad("campo não permitido: " + f)
		}
	}

	r := &request{t: in.T}
	var perr *protoError
	if in.Room != nil {
		if perr = decodeFixed("room", *in.Room, r.room[:]); perr != nil {
			return nil, perr
		}
	}
	if in.Token != nil {
		if perr = decodeFixed("token", *in.Token, r.token[:]); perr != nil {
			return nil, perr
		}
	}
	if in.Req != nil {
		if r.req, perr = decodeB64("req", *in.Req, cfg.MaxControlData); perr != nil {
			return nil, perr
		}
	}
	if in.Data != nil {
		max := cfg.MaxControlData
		if in.T == "msg" {
			max = cfg.MaxMsgData
		}
		if r.data, perr = decodeB64("data", *in.Data, max); perr != nil {
			return nil, perr
		}
		if len(r.data) == 0 {
			return nil, bad("data vazio")
		}
	}
	if in.Welcome != nil {
		if r.welcome, perr = decodeB64("welcome", *in.Welcome, cfg.MaxControlData); perr != nil {
			return nil, perr
		}
		if in.To == nil {
			return nil, bad("welcome exige to")
		}
	}
	if in.To != nil && in.Welcome == nil {
		return nil, bad("to exige welcome")
	}
	if in.Member != nil {
		r.member = *in.Member
	}
	if in.Last != nil {
		r.last = *in.Last
	}
	if in.Leaf != nil {
		r.leaf = *in.Leaf
	}
	if in.Epoch != nil {
		r.epoch = *in.Epoch
	}
	if in.To != nil {
		r.to = *in.To
	}
	return r, nil
}

// outbound é a mensagem do servidor; campos vazios são omitidos.
type outbound struct {
	T         string  `json:"t"`
	Member    uint32  `json:"member,omitempty"`
	Token     string  `json:"token,omitempty"`
	ExpiresIn int     `json:"expires_in,omitempty"`
	From      uint32  `json:"from,omitempty"`
	Req       string  `json:"req,omitempty"`
	Data      string  `json:"data,omitempty"`
	Epoch     *uint64 `json:"epoch,omitempty"`
	Seq       uint64  `json:"seq,omitempty"`
	Leaf      *uint32 `json:"leaf,omitempty"`
	Code      string  `json:"code,omitempty"`
	Detail    string  `json:"detail,omitempty"`
}

func b64(b []byte) string { return base64.StdEncoding.EncodeToString(b) }

func u64(v uint64) *uint64 { return &v }
func u32(v uint32) *uint32 { return &v }

func mustJSON(o outbound) []byte {
	b, err := json.Marshal(o)
	if err != nil {
		panic(errors.New("relay: falha ao serializar mensagem do servidor"))
	}
	return b
}
