import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// Imagem em tons de cinza (o plano Y de um quadro YUV da câmera).
class LumaFrame {
  const LumaFrame(this.bytes, this.width, this.height, this.rowStride);

  /// Plano de luminância; cada linha ocupa [rowStride] bytes.
  final Uint8List bytes;
  final int width;
  final int height;
  final int rowStride;
}

class _LumaSource extends LuminanceSource {
  _LumaSource(this._f) : super(_f.width, _f.height);
  final LumaFrame _f;

  @override
  Int8List getRow(int y, Int8List? row) {
    final out = (row != null && row.length >= width) ? row : Int8List(width);
    final start = y * _f.rowStride;
    for (var x = 0; x < width; x++) {
      out[x] = _f.bytes[start + x].toSigned(8);
    }
    return out;
  }

  @override
  Int8List getMatrix() {
    final out = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      final src = y * _f.rowStride;
      final dst = y * width;
      for (var x = 0; x < width; x++) {
        out[dst + x] = _f.bytes[src + x].toSigned(8);
      }
    }
    return out;
  }
}

/// Procura um QR no quadro. Retorna o texto ou null. Função pura, para rodar
/// fora da thread da interface (`compute`). Nenhum quadro é guardado.
String? decodeQr(LumaFrame frame) {
  try {
    final bitmap = BinaryBitmap(HybridBinarizer(_LumaSource(frame)));
    return QRCodeReader().decode(bitmap).text;
  } on ReaderException {
    return null;
  } on ArgumentError {
    return null;
  }
}
