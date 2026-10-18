# nenures

Aplicativo de conversas temporárias, sem cadastro, com criptografia de ponta a ponta.

**Estado: Fase 5 (integração criptográfica).** O app conversa com criptografia MLS (OpenMLS) por um servidor de retransmissão, em ambiente local. Ainda não houve revisão de segurança externa (D2): nenhuma garantia de segurança deve ser presumida.

## Documentos

- [docs/revisao-seguranca.md](docs/revisao-seguranca.md): revisão do protótipo e arquitetura criptográfica proposta
- [docs/arquitetura.md](docs/arquitetura.md): componentes, fluxos e testes por camada
- [docs/protocolo.md](docs/protocolo.md): protocolo entre app e servidor (v1)
- [docs/decisoes/decisoes-pendentes.md](docs/decisoes/decisoes-pendentes.md): decisões D1–D17 (D1–D14 e D17 aprovadas; D15 e D16 pendentes)
- [docs/decisoes/spike-openmls.md](docs/decisoes/spike-openmls.md): evidências do OpenMLS no Android
- [docs/modelo-de-ameacas.md](docs/modelo-de-ameacas.md): ameaças, mitigações e riscos residuais
- [docs/juridico.md](docs/juridico.md): pendências jurídicas e perguntas para advogado(a) (nenhuma resolvida)
- [docs/licencas-terceiros.md](docs/licencas-terceiros.md): licenças das dependências e obrigações de atribuição
- [docs/privacidade.md](docs/privacidade.md) e [docs/termos-de-uso.md](docs/termos-de-uso.md): rascunhos, não publicados
- [docs/operacao.md](docs/operacao.md): denúncias, conteúdo ilegal e pedidos de autoridades (rascunho)

## Estrutura

```text
app/      aplicativo Flutter (Android primeiro)
server/   retransmissor em Go (AGPL-3.0)
app/rust/ biblioteca nenures_core (MLS + convite), ligada ao Flutter pelo flutter_rust_bridge
docs/     documentação técnica, decisões e ameaças
tools/    scripts de verificação usados no CI
tests/    integração e vetores (a partir da Fase 4)
```

## Requisitos

| Ferramenta | Versão usada |
| --- | --- |
| Flutter (stable) | 3.47.0 (Dart 3.13.0) |
| Go | 1.27.0 |
| JDK | Temurin 17 |
| Rust | 1.99.0 (fixado em `app/rust/rust-toolchain.toml`) |
| Android NDK | r30 LTS (30.0.16248370) |
| flutter_rust_bridge_codegen | 2.13.0 (só para regerar a ponte) |
| Android SDK | via `flutter doctor` |

## Comandos

```sh
# app
cd app
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --release

# servidor
cd server
gofmt -l .
go vet ./...
go test -race ./...          # -race exige cgo; no Windows sem gcc, rode sem -race
go build -o bin/nenures-server ./cmd/nenures-server

# verificação de dependências proibidas
sh tools/check_forbidden_deps.sh app/pubspec.lock

# o transporte falso não pode estar no APK de release
sh tools/check_release_apk.sh app/build/app/outputs/flutter-apk/app-release.apk
```

## Conversa real em ambiente local

```sh
# 1. servidor
cd server && NENURES_ADDR=127.0.0.1:8080 go run ./cmd/nenures-server

# 2. app no emulador apontando para o PC (10.0.2.2 é o PC visto do emulador)
cd app && flutter run --profile --dart-define=NENURES_SERVER=ws://10.0.2.2:8080/v1
```

Sem `NENURES_SERVER`, o app não conversa e avisa isso na tela. O release só aceita `wss://`.

Testes que usam a biblioteca Rust no PC precisam dela compilada antes: `cd app/rust && cargo build --release`.

## Demonstração com transporte falso

Para navegar pelas telas sem rede nem criptografia (só desenvolvimento):

```sh
cd app
flutter run -t test/demo/main_demo.dart
```

O transporte falso vive em `test/` e o CI falha se ele aparecer no APK de release.

## Licença

Ver [LICENSE](LICENSE). Servidor: AGPL-3.0. App: pendente (decisão D15).
