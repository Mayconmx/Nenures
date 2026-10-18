# Protocolo de comunicação — v1

Versão 1 · 18/10/2026 · Fase 4
Base: decisões D1–D14 aprovadas e o protocolo criptográfico de [revisao-seguranca.md](revisao-seguranca.md), seção 4, validado no [spike](decisoes/spike-openmls.md).

O servidor é o *Delivery Service* do MLS: ordena commits e retransmite bytes. **Ele não interpreta nem decifra o conteúdo MLS.** Tudo que é MLS viaja como bytes opacos.

---

## 1. Transporte

- WebSocket seguro: `wss://<host>/v1`. TLS fica no proxy (Caddy); o processo Go escuta só em endereço local.
- Mensagens de texto com **JSON**, um objeto por frame. Campos binários em Base64 padrão (RFC 4648, com `=`).
- Campo `t` indica o tipo. Campos desconhecidos são **rejeitados** (`bad_request`).
- Keepalive: o servidor envia ping do WebSocket a cada 20 s. Sem pong em 15 s, a conexão é tratada como queda (seção 6).
- A primeira mensagem do cliente precisa chegar em até 10 s e ser `create`, `join` ou `resume`.

## 2. Identificadores

| Nome | Origem | O servidor sabe o quê |
| --- | --- | --- |
| `room` | `room_id` de 32 bytes, HKDF do convite (D4) | Só que é um identificador; não consegue voltar ao convite |
| `member` | Número que o servidor atribui à conexão na sala (1, 2, 3…) | Liga a conexão à sala; não é a folha MLS |
| `leaf` | Índice da folha MLS, informado pelo cliente | Usado só para avisar os outros quando alguém some |
| `token` | 32 bytes aleatórios do servidor, para retomar a sessão | Segredo da conexão; vale só enquanto a sessão existe |

## 3. Mensagens

### Cliente → servidor

| `t` | Campos | Quando | Efeito |
| --- | --- | --- | --- |
| `create` | `room` | Gerar chave | Cria a sala vazia. Erro `exists` se já houver uma com esse `room` |
| `join` | `room`, `req` | Entrar com chave | `req` = pedido selado com `adm_key` (nonce ‖ AEAD(KeyPackage)). O servidor repassa aos membros e espera um commit com `welcome` |
| `resume` | `room`, `member`, `token`, `last` | Reconectar até 60 s depois de cair | Reenvia o que chegou depois de `last` (seção 6) |
| `leaf` | `leaf` | Logo depois de entrar ou de criar | Associa a conexão à folha MLS |
| `commit` | `epoch`, `data`, opcional `welcome` + `to` | Mudança no grupo | Aceito só se `epoch` for a época atual da sala (seção 4) |
| `proposal` | `data` | Ex.: Encerrar (`leave_group`) | Repassado aos outros membros |
| `msg` | `data` | Mensagem de texto cifrada | Repassado aos outros membros |
| `lock` | — | Trancar entrada (D7) | A sala recusa novos `join` dali em diante |
| `leave` | — | Encerrar | O servidor fecha a participação na hora, sem janela de reconexão |

### Servidor → cliente

| `t` | Campos | Significado |
| --- | --- | --- |
| `created` | `member`, `token`, `expires_in` | Sala criada; `expires_in` em segundos (P3) |
| `join_request` | `from`, `req` | Alguém pede para entrar (`from` é o `member` provisório de quem pede) |
| `welcome` | `data`, `member`, `token`, `epoch` | Para quem pediu: entrada aceita |
| `commit` | `epoch`, `data`, `seq` | Commit aceito na época `epoch` |
| `commit_ok` | `epoch` | Para o autor: o commit foi aceito; agora ele faz o merge |
| `commit_rejected` | `epoch` | Para o autor: outro commit venceu; descartar o próprio e processar o vencedor |
| `proposal` | `data`, `seq` | Proposta de outro membro |
| `msg` | `data`, `seq` | Mensagem de outro membro |
| `away` | `leaf` | A conexão daquela folha caiu (pode voltar em 60 s) |
| `back` | `leaf` | Voltou |
| `gone` | `leaf` | Saiu ou não voltou a tempo; o membro designado deve fazer `Commit(Remove)` |
| `locked` | — | A entrada foi trancada |
| `expired` | — | A chave expirou sem ninguém entrar (P3); a conexão é fechada |
| `resumed` | `epoch` | Sessão retomada; em seguida vêm as mensagens pendentes |
| `error` | `code`, opcional `detail` | Ver seção 7 |

Toda mensagem repassada carrega `seq`, um contador crescente **por destinatário**, usado na retomada.

## 4. Ordem dos commits

- A sala guarda `epoch` (começa em 0, a época do grupo recém-criado).
- `commit` com `epoch` igual ao da sala: **aceito**. A sala avança uma época, envia `commit_ok` ao autor e `commit` aos demais.
- `epoch` diferente: `commit_rejected` com a época atual. Isso cobre commits concorrentes; o spike mostrou que descartar e processar o vencedor mantém o grupo consistente.
- Um commit com `welcome` precisa trazer `to` = `member` de um pedido de entrada pendente. O `welcome` só é entregue se o commit for aceito.
- O servidor não verifica o conteúdo do commit; os clientes verificam (MLS).

## 5. Entrada (fluxo completo)

```text
quem entra            servidor                    membro designado (menor folha online)
  join(room, req) ──▶  sala existe? trancada? cheia?
                       ├─ não existe ──▶ error(not_found)
                       └─ ok: member provisório
                          join_request(from, req) ──▶ abre req com adm_key, valida o KeyPackage
                                                      commit(epoch, data, welcome, to=from)
                    ◀── welcome(data, member, token) ◀─ aceito
  leaf(n) ──────────▶  demais membros ◀── commit(epoch, data)
```

- Pedido de entrada sem resposta em 30 s: `error(timeout)` para quem pediu.
- Até 5 pedidos pendentes por sala.
- Os membros só adicionam quem tem pedido válido (selado com `adm_key`). O servidor não consegue forjar um.

## 6. Queda e retomada (D9)

- Se a conexão de um membro cai **sem** `leave`, o servidor avisa `away(leaf)` aos outros e guarda por até **60 s** (e até 1 MiB) as mensagens destinadas a ele.
- `resume` com o `token` certo dentro do prazo: o servidor responde `resumed`, reenvia as mensagens com `seq > last` e avisa `back(leaf)`.
- Passados 60 s: o servidor descarta a fila, envia `gone(leaf)` e o membro designado faz `Commit(Remove)`.
- Se o processo do app morreu, o estado MLS se perdeu. Não há retomada: a pessoa entra de novo como participante novo (se ainda tiver a chave).
- A fila também vale para o que foi enviado pouco antes da queda: o servidor mantém as últimas mensagens de cada membro por 60 s, porque o TCP pode ter perdido o que estava a caminho.

## 7. Erros

| `code` | Quando |
| --- | --- |
| `bad_request` | JSON inválido, tipo desconhecido, campo faltando ou sobrando, Base64 inválido, mensagem fora de ordem no fluxo |
| `too_large` | Acima dos limites da seção 8 |
| `rate_limited` | Acima dos limites de taxa |
| `not_found` | Sala inexistente ou expirada (o servidor não distingue); ou `commit` com `welcome` para quem já não espera mais (o commit não é aceito) |
| `exists` | `create` com `room` em uso |
| `locked` | Sala trancada (D7) |
| `full` | Sala no teto de participantes (D6) |
| `timeout` | Pedido de entrada sem resposta |
| `bad_token` | Retomada com sessão desconhecida ou expirada |
| `busy` | Servidor no limite global de salas ou conexões |

Depois de `bad_request` ou `too_large`, o servidor fecha a conexão. Um frame acima de 96 KiB fecha a conexão direto, com o código WebSocket 1009 (sem mensagem `error`). Acima do limite de taxa, a mensagem é descartada e o servidor responde `rate_limited` sem fechar a conexão.

## 8. Limites (D6, D10, D11)

| Limite | Valor inicial |
| --- | --- |
| `data` de `msg` | 8 KiB (depois de decodificar o Base64) |
| `data` de `commit`, `proposal`, `welcome`, `req` | 64 KiB |
| Frame WebSocket | 96 KiB |
| Participantes por sala | 50 |
| Pedidos de entrada pendentes por sala | 5 |
| Mensagens por conexão | 20 por segundo, rajada de 40 |
| Conexões simultâneas por IP | 16 |
| `create` por IP | 10 por minuto |
| `join` por IP | 30 por minuto |
| Salas no servidor / conexões no servidor | configuráveis; padrão 10 000 / 50 000 |
| Fila de retomada por membro | 60 s ou 1 MiB |

Limites por IP usam HMAC-SHA256 do IP com chave aleatória gerada na inicialização e trocada a cada hora; nada vai para disco nem para log (D11).

## 9. Ciclo de vida da sala

- Criada por `create`. Se ninguém além do criador entrar em 10 min: `expired` e a sala some (P3).
- Depois da primeira entrada, a sala não expira por tempo (P4).
- A sala existe enquanto houver pelo menos um membro conectado **ou** dentro da janela de retomada. Quando não sobra ninguém, ela é apagada da memória (P8).
- Reiniciar o servidor apaga todas as salas.

## 10. O que o servidor não faz

- Não decifra nem valida conteúdo MLS.
- Não envia número de participantes: o contador vem da árvore MLS (revisao-seguranca.md 4.6).
- Não registra em log `room`, `token`, IP, `data` ou `req`.

## 11. Compatibilidade

O caminho `/v1` fixa esta versão. Mudanças incompatíveis vão para `/v2`, e o servidor atende as duas durante a transição.
