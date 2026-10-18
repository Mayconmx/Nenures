import 'package:flutter/services.dart';

/// Copia texto marcando-o como sensível quando o sistema permite (Android 13+).
///
/// Limites (D13): outros apps, teclados e a sincronização da área de
/// transferência ainda podem ler o conteúdo. A limpeza automática depende da
/// aprovação de D13 e não está implementada.
abstract final class SensitiveClipboard {
  static const _channel = MethodChannel('nenures/clipboard');

  static Future<void> copy(String text) async {
    try {
      await _channel.invokeMethod<void>('copySensitive', {'text': text});
    } on MissingPluginException {
      // Fora do Android (testes, outras plataformas): cópia comum.
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}
