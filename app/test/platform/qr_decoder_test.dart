import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/conversation/invite.dart';
import 'package:nenures/platform/qr_decoder.dart';
import 'package:qr/qr.dart';

/// Desenha o QR como a câmera veria: tons de cinza, módulos de [scale] pixels,
/// zona de silêncio, linhas com [stride] maior que a largura e ruído leve.
LumaFrame render(String data, {int scale = 6, int pad = 40, int seed = 1}) {
  final qr = QrImage(QrCode(payload: QrPayload.fromString(data)));
  final n = qr.moduleCount;
  final size = n * scale + 2 * pad;
  final stride = size + 32;
  final bytes = Uint8List(stride * size)..fillRange(0, stride * size, 235);
  final rnd = Random(seed);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final mx = (x - pad) ~/ scale, my = (y - pad) ~/ scale;
      final inside = x >= pad && y >= pad && mx < n && my < n;
      final dark = inside && qr.isDark(my, mx);
      final base = dark ? 25 : 225;
      bytes[y * stride + x] = (base + rnd.nextInt(21) - 10).clamp(0, 255);
    }
  }
  return LumaFrame(bytes, size, size, stride);
}

void main() {
  final invite = Invite(const [
    'ruivo',
    'recente',
    'mirante',
    'perfeito',
    'filme',
    'poupar',
    'leitura',
    'cardeal',
  ]);

  test('lê o QR da chave e reconstrói o convite (D17)', () {
    final text = decodeQr(render(invite.qrPayload));
    expect(text, invite.qrPayload);
    expect(Invite.tryParseQr(text!)!.words, invite.words);
  });

  test('funciona com módulos pequenos e outro ruído', () {
    expect(
      decodeQr(render(invite.qrPayload, scale: 3, seed: 7)),
      invite.qrPayload,
    );
  });

  test('imagem sem QR devolve null', () {
    const w = 200, h = 150;
    final rnd = Random(3);
    final bytes = Uint8List.fromList(
      List.generate(w * h, (_) => 100 + rnd.nextInt(40)),
    );
    expect(decodeQr(LumaFrame(Uint8List(16), 4, 4, 4)), isNull);
    expect(decodeQr(LumaFrame(bytes, w, h, w)), isNull);
  });

  test('QR que não é do nenures não vira convite', () {
    final text = decodeQr(render('https://exemplo.com'));
    expect(text, 'https://exemplo.com');
    expect(Invite.tryParseQr(text!), isNull);
  });
}
