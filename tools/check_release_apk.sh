#!/usr/bin/env sh
# Falha se o transporte FALSO (test/support/fake_transport.dart) estiver dentro
# de um APK. Procura a marca no código compilado (libapp.so) de cada ABI.
#
# Uso:
#   tools/check_release_apk.sh <apk>             # release: a marca NÃO pode estar lá
#   tools/check_release_apk.sh --expect <apk>    # controle positivo: a marca PRECISA estar lá
set -eu

marker='NENURES_FAKE_TRANSPORT_NAO_VAI_PARA_RELEASE'
expect=0
if [ "${1:-}" = "--expect" ]; then expect=1; shift; fi
apk="${1:?informe o caminho do APK}"
[ -f "$apk" ] || { echo "APK não encontrado: $apk" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unzip -q -o "$apk" 'lib/*/libapp.so' -d "$tmp"

count=$(find "$tmp" -name libapp.so | wc -l)
[ "$count" -gt 0 ] || { echo "nenhum libapp.so em $apk" >&2; exit 2; }

found=0
for so in $(find "$tmp" -name libapp.so); do
  if grep -aq "$marker" "$so"; then found=1; echo "marca encontrada em ${so#"$tmp"/}"; fi
done

if [ "$expect" = 1 ]; then
  [ "$found" = 1 ] || { echo "controle positivo falhou: a marca não aparece no APK" >&2; exit 1; }
  echo "controle positivo ok: a verificação detecta o transporte falso"
else
  [ "$found" = 0 ] || { echo "ERRO: transporte falso dentro do APK de release" >&2; exit 1; }
  echo "ok: transporte falso ausente em $count biblioteca(s)"
fi
