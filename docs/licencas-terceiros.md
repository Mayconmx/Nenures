# Licenças de terceiros

Versão 1 · 18/10/2026 · Fase 3
Gerado a partir de `flutter pub deps --no-dev` e das etiquetas de licença do pub.dev, consultadas em 18/10/2026. Atualizar a cada mudança no `pubspec.lock` ou no `go.mod`.

## 1. App (Dart/Flutter) — dependências de produção

Inclui as transitivas. O `flutter_riverpod` 3.4.3 declara `flutter_test` como dependência de produção, o que traz pacotes de teste para a árvore. Só o código usado entra no binário, mas eles são listados por precaução.

| Pacote | Versão | Licença | Publicador |
| --- | --- | --- | --- |
| flutter_riverpod | 3.4.3 | MIT | dash-overflow.net |
| riverpod | 3.4.3 | MIT | dash-overflow.net |
| state_notifier | 1.0.0 | MIT | dash-overflow.net |
| qr | 4.0.0 | BSD-3-Clause | kevmoo.com |
| clock | 1.1.2 | Apache-2.0 | tools.dart.dev |
| uuid | 4.6.0 | MIT | yuli.dev |
| material_color_utilities | 0.13.0 | Apache-2.0 | material.io |
| fake_async | 1.3.3 | Apache-2.0 | dart.dev |
| async, characters, collection, crypto, fixnum, matcher, meta, path, typed_data | várias | BSD-3-Clause | dart.dev |
| boolean_selector, leak_tracker, leak_tracker_testing, source_span, stack_trace, stream_channel, string_scanner, term_glyph, test_api, vm_service | várias | BSD-3-Clause | tools.dart.dev |
| leak_tracker_flutter_testing, listen, vector_math | várias | BSD-3-Clause | flutter.dev |
| Flutter SDK e engine (inclui Skia, ICU, HarfBuzz e outros) | 3.47.0 | BSD-3-Clause e licenças dos componentes | flutter.dev |

## 2. App — fontes e ícones empacotados

| Recurso | Licença | Arquivo de licença |
| --- | --- | --- |
| Bricolage Grotesque | SIL OFL 1.1 | `app/assets/fonts/OFL-BricolageGrotesque.txt` |
| IBM Plex Sans | SIL OFL 1.1 | `app/assets/fonts/OFL-IBMPlexSans.txt` |
| IBM Plex Mono | SIL OFL 1.1 | `app/assets/fonts/OFL-IBMPlexMono.txt` |
| Material Symbols Rounded (recorte) | Apache-2.0 | `app/assets/fonts/LICENSE-MaterialSymbols.txt` |

## 3. Servidor (Go)

Hoje só a biblioteca padrão do Go (BSD-3-Clause). Previsto para a Fase 4: `github.com/coder/websocket` (ISC, a confirmar na adoção).

## 4. Previstas para a Fase 5 (se D1 for aprovada)

| Componente | Licença (verificada em 18/10/2026) |
| --- | --- |
| OpenMLS 0.9.x | MIT |
| flutter_rust_bridge 2.13.0 | MIT |
| Crates RustCrypto (argon2, hkdf, chacha20poly1305 etc.) | MIT OR Apache-2.0 (a confirmar por crate) |
| Lista de palavras BIP39 em português | **A confirmar** (repositório bitcoin/bips) |

## 5. Compatibilidade com a licença do app (D15)

Todas as licenças acima são permissivas. MIT, BSD-3-Clause, ISC e Apache-2.0 são compatíveis com GPL-3.0, MPL-2.0 e Apache-2.0. As fontes OFL podem ser empacotadas em software de qualquer licença, desde que não sejam vendidas sozinhas e mantenham o aviso. Nenhuma dependência atual restringe a escolha da D15.

## 6. Obrigações de atribuição (pendentes de implementação)

- BSD-3, MIT e Apache-2.0 exigem reproduzir os avisos de copyright na distribuição binária. O Flutter coleta os arquivos `LICENSE` dos pacotes no `LicenseRegistry`, mas o app ainda **não tem tela de licenças**.
- As fontes OFL e o Material Symbols não são registrados automaticamente; é preciso adicioná-los ao `LicenseRegistry`.
- **Ação proposta (Fase 7):** link "Licenças de terceiros" na tela Sobre (`showLicensePage`) e registro das licenças das fontes. Verificar no CI que o build de release contém os avisos.

## 7. Verificação contínua (proposta)

- Script no CI que gera esta tabela a partir do `pubspec.lock` e falha se aparecer licença fora da lista permitida (MIT, BSD-2/3, Apache-2.0, ISC, Zlib, OFL, MPL-2.0).
- Para Rust: `cargo deny check licenses`. Para Go: `go-licenses check`.
