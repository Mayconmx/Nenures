# Spike técnico — OpenMLS no Android (D1)

Data: 18/10/2026 · Código: [spikes/openmls](../../spikes/openmls) (isolado; não é ligado ao app nem ao servidor)

## Objetivo

Confirmar, com evidência, que a decisão D1 (MLS com OpenMLS) funciona antes de construir o servidor e a integração em cima dela. Itens S1–S6 de [revisao-seguranca.md](../revisao-seguranca.md), seção 6.

## Ambiente

| Item | Versão |
| --- | --- |
| openmls | 0.9.1 (MIT) |
| openmls_rust_crypto / openmls_basic_credential / openmls_traits | 0.6.0 |
| argon2 / hkdf / sha2 / chacha20poly1305 | 0.6.0 / 0.13.0 / 0.11.1 / 0.10.1 |
| Rust | 1.99.0 (fixado em `rust-toolchain.toml`) |
| Android NDK | r30 LTS, 30.0.16248370 (SHA-1 do pacote conferido com o publicado pelo Google) |
| cargo-ndk | instalado via `cargo install --locked` |
| Emulador | Pixel 7, Android 17, x86_64 |
| PC | Windows 10, x86_64 |

## Cenários testados (10)

Todos passaram **no Windows e dentro do Android** (emulador), em modo release.

| Cenário | Ameaça / requisito |
| --- | --- |
| Convite deriva os mesmos segredos; `room_id` ≠ `adm_key`; 1 bit diferente muda tudo | D4 |
| Entrada mediada (pedido AEAD → Commit(Add) → Welcome) com 3 pessoas; contador igual em todos; `epoch_authenticator` igual | 4.3, 4.6 |
| Pedido de entrada sem o convite (chave de admissão errada) é recusado | T1, T6 |
| Mensagem adulterada é rejeitada | T5 |
| Mensagem repetida é rejeitada | T4 |
| Mensagens fora de ordem dentro da tolerância | T8 |
| Commits concorrentes: o servidor aceita um, o outro descarta e processa o vencedor; o grupo continua consistente | 4.4, T8 |
| Encerrar: proposta de saída, commit pelo membro de menor folha, quem saiu fica inativo e não lê mensagens novas | P6, D8 |
| Quem entra depois não lê mensagens anteriores | 4.2 |
| Medição de tempos e tamanhos | S5, S6, D6, D10 |

## Resultados por item

| Item | Resultado | Evidência |
| --- | --- | --- |
| **S1** compila para Android | **Passou** para arm64-v8a, armeabi-v7a e x86_64. Testes executados só em x86_64 (emulador). | `cargo ndk -P 24 -t arm64-v8a -t armeabi-v7a -t x86_64 build --release` |
| **S2** ciphersuite 0x0003 | **Funciona** em todos os cenários. Os vetores oficiais do RFC 9420 **ainda não foram executados por nós**. | Pendente para a Fase 5 |
| **S3** nada em disco | **Passou**: rodando todos os cenários numa pasta vazia no Android, 0 arquivos criados. `OpenMlsRustCrypto` usa armazenamento em memória. | `find /data/local/tmp/s3 -type f` = 0 |
| **S4** saída voluntária | **Passou** com `leave_group` + `commit_to_pending_proposals` | Cenário "Encerrar" |
| **S5** tamanho do APK e memória | **Não medido.** Sem funções exportadas, o otimizador descarta código de forma diferente por arquitetura (2,7 KB no armv7, 404 KB no arm64), então o número não vale. | Medir na Fase 5, com a API do flutter_rust_bridge |
| **S6** Argon2id ≤ 1,5 s | **Parcial**: 108 ms no PC e 379 ms no emulador x86_64. Celular ARM barato será mais lento. | Medir no aparelho de referência |

## Medições (emulador Android 17, x86_64, release)

| Medida | Valor |
| --- | --- |
| Argon2id m = 64 MiB, t = 3, p = 1 | 379 ms (PC: 108 ms) |
| Entrada com 2 / 10 / 25 participantes: tempo do commit | 1,3 / 4,8 / 5,1 ms |
| Tamanho do commit (2 / 10 / 25) | 707 / 1470 / 2735 bytes |
| Tamanho do Welcome (2 / 10 / 25) | 811 / 2511 / 5384 bytes |
| Processar um commit em todos os outros membros (10 / 25, soma) | 16,9 / 36,0 ms |
| Mensagem de 1000 caracteres cifrada | 1146 bytes, 176 µs |

Consequências para as decisões:
- **D10:** mensagem de aplicação cabe com folga em 8 KiB. O Welcome cresce ~210 bytes por participante; com 50 pessoas, a estimativa é ~11 KB. Proposta: limite de 64 KiB para mensagens de controle (a confirmar com 50 participantes no aparelho de referência).
- **D6:** até 25 participantes o custo é pequeno no emulador; o teto de 50 continua como ponto de partida.

## Achados sobre a API

- `MlsMessageIn::into_welcome` só existe com a feature `test-utils`; o caminho público é `extract()` → `MlsMessageBodyIn::Welcome`.
- `KeyPackageIn::validate` faz a verificação do KeyPackage recebido antes do Add.
- A política `PURE_CIPHERTEXT_WIRE_FORMAT_POLICY` funciona também para a proposta de saída (`leave_group`).
- O OpenMLS teve 5 avisos de segurança entre 09/2025 e 10/2026; a versão 0.9.1 inclui as correções. Acompanhar novos avisos é obrigatório (CI com `cargo audit`, Fase 5).

## Atualização da Fase 5 (18/10/2026)

- **S1 no app:** o app Android (build profile, x86_64) carregou a biblioteca `nenures_core`, gerou a chave, criou a sala no servidor local e conversou nos dois sentidos com um cliente no PC. A captura de tela saiu preta (`FLAG_SECURE`). Ainda falta aparelho ARM físico.
- **S5 medido:** APK de release por arquitetura, antes → depois do Rust: arm64-v8a 15,8 → 19,6 MB (+3,8); armeabi-v7a 12,9 → 16,3 MB (+3,4); x86_64 17,1 → 21,4 MB (+4,3).
- **Achado:** cópia adulterada recebida antes da verdadeira faz a verdadeira falhar também (registrado em modelo-de-ameacas.md, T5).

## Conclusão

A decisão D1 se sustenta: o OpenMLS compila para Android, roda dentro do Android e implementa todos os comportamentos de protocolo que o projeto precisa, sem gravar nada em disco. Ficam pendentes para a Fase 5: vetores oficiais (S2), tamanho real do APK (S5) e medição em aparelho ARM (S1 em ARM, S6).
