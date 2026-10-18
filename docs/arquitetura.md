# Arquitetura — Nenures

Versão 1 · 18/10/2026 · Fase 5
Protocolo criptográfico: [revisao-seguranca.md](revisao-seguranca.md). Mensagens com o servidor: [protocolo.md](protocolo.md).

## Componentes

```text
┌──────────────────────────── App (Flutter) ────────────────────────────┐
│ Telas (lib/ui) ──▶ ConversationController (lib/conversation)          │
│                         │  máquina de estados, prazos (10 min, 60 s)  │
│                         ▼                                              │
│                ConversationTransport (interface)                       │
│        ┌────────────────┼──────────────────────────┐                  │
│  UnavailableTransport   RealTransport        FakeConversationTransport │
│  (sem servidor          (lib/conversation/   (só em test/)             │
│   configurado)           real_transport.dart)                          │
│                          │ WebSocket (dart:io)    │ flutter_rust_bridge │
│                          │                        ▼                    │
│                          │            nenures_core (Rust, app/rust)    │
│                          │            OpenMLS 0.9.1 + convite          │
│                          │            (Argon2id, HKDF, ChaCha20-Poly1305)│
└──────────────────────────┼─────────────────────────────────────────────┘
                           │ wss://…/v1 (TLS no Caddy)
┌──────────────────────────▼──────── Servidor (Go) ─────────────────────┐
│ internal/relay: salas em RAM, ordem dos commits, retomada em 60 s,    │
│ limites por conexão e por IP (HMAC). Não decifra nada; não grava nada. │
└────────────────────────────────────────────────────────────────────────┘
```

## Onde fica cada coisa

| Dado | Onde vive | Quem vê |
| --- | --- | --- |
| Palavras da chave | Memória do app (Dart) e da biblioteca Rust | Quem está na conversa |
| `adm_key`, segredos MLS, chaves de assinatura | Só dentro do Rust (`Session`, opaca para o Dart) | Ninguém fora do aparelho |
| `room_id` | Rust → Dart → servidor | Servidor (não revela a chave) |
| Texto das mensagens | Dart (tela) e Rust (cifra/decifra) | Pessoas da conversa |
| Mensagens cifradas | Servidor (repasse e fila de 60 s) | Servidor, sem conseguir ler |

## Fluxos

**Gerar chave:** Rust gera 88 bits → 8 palavras; deriva `room_id` e `adm_key` (Argon2id); cria o grupo MLS (época 0). O app envia `create(room_id)`.

**Entrar com chave:** Rust confere as palavras na lista, deriva as chaves e sela um KeyPackage novo com `adm_key`. O servidor repassa o pedido; o membro designado (menor folha online) abre, valida e faz `Commit(Add)`; o servidor aceita um commit por época e entrega o `Welcome`.

**Conversar:** texto → Rust cifra (MLS, 0x0003) → servidor repassa → Rust dos outros decifra e confere autenticidade, repetição e época.

**Sair:** proposta MLS de saída + `leave`; o designado faz o commit; os outros veem o contador cair. Quem cai sem sair tem 60 s para voltar; depois o designado remove a folha.

## Configuração

- O app só conversa se compilado com `--dart-define=NENURES_SERVER=wss://…/v1`. Sem isso, usa `UnavailableTransport` e diz que não está disponível.
- `ws://` só é aceito para endereços locais (testes). No Android, tráfego sem TLS é proibido no release e liberado só para 10.0.2.2/127.0.0.1 nos builds de depuração e profile.

## Testes por camada

| Camada | Onde | O que cobre |
| --- | --- | --- |
| Rust | `app/rust/tests/core.rs` | lista de palavras, convite, MLS: entrada, recusa sem convite, adulteração, repetição, concorrência, saída, remoção, trancar |
| Ponte | `app/test/rust/bridge_test.dart` | chamadas Dart → Rust com a biblioteca real |
| Servidor | `server/internal/relay/relay_test.go` | protocolo, limites, retomada, concorrência, logs, disco |
| Ponta a ponta | `app/test/integration/e2e_test.dart` | servidor Go real + transporte real + Rust real: 3 pessoas, saída, sala some, chave errada, reinício do servidor |
| Interface | `app/test/ui`, `app/test/conversation` | telas, acessibilidade, estados (com transporte falso) |
| Aparelho | manual, `device_join_test.dart` | app Android no emulador conversando com um cliente no PC |
