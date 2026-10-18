#!/usr/bin/env sh
# Falha se o app depender de pacotes que contrariam P10 ou a seção 10.1 do prompt:
# push, analytics, anúncios, crash reporting de terceiros ou fontes baixadas em tempo de execução.
# Uso: tools/check_forbidden_deps.sh [caminho/para/pubspec.lock]
set -eu

lock="${1:-app/pubspec.lock}"
[ -f "$lock" ] || { echo "arquivo não encontrado: $lock" >&2; exit 2; }

pattern='^  (firebase_[a-z_]*|google_fonts|google_mobile_ads|sentry[a-z_]*|amplitude[a-z_]*|mixpanel[a-z_]*|appsflyer[a-z_]*|onesignal[a-z_]*|flutter_local_notifications|facebook[a-z_]*|datadog[a-z_]*|bugsnag[a-z_]*|posthog[a-z_]*):'

if grep -E "$pattern" "$lock"; then
  echo "dependência proibida encontrada em $lock (ver docs/revisao-seguranca.md)" >&2
  exit 1
fi
echo "nenhuma dependência proibida em $lock"
