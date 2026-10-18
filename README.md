# nenures

Aplicativo de conversas temporárias, sem cadastro, com criptografia de ponta a ponta.

**Estado: Fase 2 (estrutura e telas).** Ainda não há criptografia nem servidor de salas. Nenhuma garantia de segurança deve ser presumida.

## Documentos

- [docs/revisao-seguranca.md](docs/revisao-seguranca.md): revisão do protótipo e arquitetura criptográfica proposta
- [docs/decisoes/decisoes-pendentes.md](docs/decisoes/decisoes-pendentes.md): decisões D1–D16 aguardando aprovação
- [docs/modelo-de-ameacas.md](docs/modelo-de-ameacas.md): ameaças, mitigações e riscos residuais

## Estrutura

```text
app/      aplicativo Flutter (Android primeiro)
server/   retransmissor em Go (AGPL-3.0)
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
```

## Licença

Ver [LICENSE](LICENSE). Servidor: AGPL-3.0. App: pendente (decisão D15).
