# nenures

Aplicativo de conversas temporárias, sem cadastro, com criptografia de ponta a ponta.

**Estado: Fase 2 (estrutura e telas).** Ainda não há criptografia nem servidor de salas. Nenhuma garantia de segurança deve ser presumida.

## Documentos

- [docs/revisao-seguranca.md](docs/revisao-seguranca.md): revisão do protótipo e arquitetura criptográfica proposta
- [docs/decisoes/decisoes-pendentes.md](docs/decisoes/decisoes-pendentes.md): decisões D1–D16 aguardando aprovação
- [docs/modelo-de-ameacas.md](docs/modelo-de-ameacas.md): ameaças, mitigações e riscos residuais
- [docs/juridico.md](docs/juridico.md): pendências jurídicas e perguntas para advogado(a) (nenhuma resolvida)
- [docs/licencas-terceiros.md](docs/licencas-terceiros.md): licenças das dependências e obrigações de atribuição
- [docs/privacidade.md](docs/privacidade.md) e [docs/termos-de-uso.md](docs/termos-de-uso.md): rascunhos, não publicados
- [docs/operacao.md](docs/operacao.md): denúncias, conteúdo ilegal e pedidos de autoridades (rascunho)

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

# o transporte falso não pode estar no APK de release
sh tools/check_release_apk.sh app/build/app/outputs/flutter-apk/app-release.apk
```

## Demonstração local

O app de release ainda não conversa: a criptografia e o servidor dependem das decisões D1–D14.
Para navegar pelas telas com um transporte **falso** (sem rede, sem criptografia, só para desenvolvimento):

```sh
cd app
flutter run -t test/demo/main_demo.dart
```

O transporte falso vive em `test/` e o CI falha se ele aparecer no APK de release.

## Licença

Ver [LICENSE](LICENSE). Servidor: AGPL-3.0. App: pendente (decisão D15).
