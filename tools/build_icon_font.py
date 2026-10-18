"""Gera a fonte de ícones do app a partir do Material Symbols Rounded oficial.

O arquivo original tem ~15 MB (todos os ícones, todos os eixos). Este script
fixa os eixos no padrão do design system (FILL 0, GRAD 0, opsz 24, wght 400),
mantém só os ícones listados em ICONS e escreve:

  app/assets/fonts/NenuresSymbols.ttf
  app/lib/design/nenures_icons.dart

Uso (fonttools 4.60.1):
  python tools/build_icon_font.py <MaterialSymbolsRounded[...].ttf> <....codepoints>
  dart format app/lib/design/nenures_icons.dart

Fonte: https://github.com/google/material-design-icons/tree/master/variablefont
Licença: Apache-2.0 (app/assets/fonts/LICENSE-MaterialSymbols.txt)
"""

import hashlib
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

# Para adicionar um ícone: inclua o nome aqui e rode o script de novo.
ICONS = [
    "arrow_back",
    "check",
    "close",
    "content_copy",
    "error",
    "info",
    "key",
    "lock",
    "qr_code_scanner",
    "send",
    "wifi_off",
]

AXES = {"FILL": 0, "GRAD": 0, "opsz": 24, "wght": 400}
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_FONT = ROOT / "app" / "assets" / "fonts" / "NenuresSymbols.ttf"
OUT_DART = ROOT / "app" / "lib" / "design" / "nenures_icons.dart"


def camel(name: str) -> str:
    head, *rest = name.split("_")
    return head + "".join(p.capitalize() for p in rest)


def main(src: str, codepoints_file: str) -> None:
    table = {}
    for line in pathlib.Path(codepoints_file).read_text(encoding="utf-8").splitlines():
        name, cp = line.split()
        table[name] = int(cp, 16)
    missing = [n for n in ICONS if n not in table]
    if missing:
        sys.exit(f"ícones inexistentes: {missing}")

    digest = hashlib.sha256(pathlib.Path(src).read_bytes()).hexdigest()
    font = TTFont(src)
    font = instancer.instantiateVariableFont(font, AXES)

    options = subset.Options()
    options.layout_features = []
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[table[n] for n in ICONS])
    subsetter.subset(font)

    OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT_FONT)

    lines = [
        "// GERADO por tools/build_icon_font.py. Não editar à mão.",
        f"// Origem: MaterialSymbolsRounded variável, sha256 {digest}",
        f"// Eixos fixados: {AXES}",
        "",
        "import 'package:flutter/widgets.dart';",
        "",
        "/// Ícones Material Symbols Rounded usados pelo app.",
        "abstract final class NenuresIcons {",
        "  static const String _family = 'NenuresSymbols';",
        "",
    ]
    for name in ICONS:
        lines.append(
            f"  static const IconData {camel(name)} = IconData(0x{table[name]:x}, fontFamily: _family);"
        )
    lines.append("}")
    OUT_DART.parent.mkdir(parents=True, exist_ok=True)
    OUT_DART.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{OUT_FONT} ({OUT_FONT.stat().st_size} bytes), {len(ICONS)} ícones")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
