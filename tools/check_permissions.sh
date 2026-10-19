#!/usr/bin/env sh
# Falha se o manifesto final (depois da fusão com os plugins) pedir permissão
# fora da lista aprovada. Dependências podem acrescentar permissões em silêncio.
# Uso: tools/check_permissions.sh [manifesto]
set -eu

manifest="${1:-app/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml}"
if [ ! -f "$manifest" ]; then
  manifest=$(find app/build/app/intermediates/merged_manifest/release -name AndroidManifest.xml 2>/dev/null | head -1)
fi
[ -n "$manifest" ] && [ -f "$manifest" ] || { echo "manifesto final não encontrado (rode o build de release)" >&2; exit 2; }

# INTERNET: servidor. CAMERA: leitor de QR (D17). ACCESS_NETWORK_STATE: normal,
# vem do CameraX. DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION: interna do AndroidX.
allowed='android.permission.INTERNET
android.permission.CAMERA
android.permission.ACCESS_NETWORK_STATE
app.nenures.nenures.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'

found=$(tr '\n' ' ' < "$manifest" | grep -o '<uses-permission[^>]*android:name="[^"]*"' | sed 's/.*android:name="//; s/"$//' | sort -u)
bad=0
for p in $found; do
  if ! printf '%s\n' "$allowed" | grep -qx "$p"; then
    echo "permissão não aprovada: $p" >&2
    bad=1
  fi
done
# A câmera precisa ser opcional, senão a Play esconde o app de quem não tem câmera.
if tr '
' ' ' < "$manifest" | grep -o '<uses-feature[^>]*camera[^>]*>' | grep -q 'required="true"'; then
  echo "câmera marcada como obrigatória no manifesto final" >&2
  bad=1
fi
[ "$bad" = 0 ] || exit 1
echo "permissões ok:"; printf '  %s\n' $found
