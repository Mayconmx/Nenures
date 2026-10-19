import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Área de transferência para a chave (D13).
///
/// - Android 13+: o conteúdo é marcado como sensível (o sistema oculta a prévia).
/// - Depois de [clearAfter], o app tenta apagar a chave, mas SÓ se ela ainda for
///   o que está na área de transferência (comparação feita no código nativo pelo
///   carimbo de tempo da cópia). Se o app estiver em segundo plano nesse momento,
///   tenta quando voltar. No Android 7.x não há como comparar: nada é apagado.
///
/// Limites: outros apps, teclados e a sincronização da área de transferência
/// podem ler o conteúdo antes da limpeza.
abstract final class SensitiveClipboard {
  static const _channel = MethodChannel('nenures/clipboard');
  static const clearAfter = Duration(seconds: 60);

  static Timer? _timer;
  static bool _due = false;
  static bool _foreground = true;

  static Future<void> copy(String text) async {
    try {
      await _channel.invokeMethod<void>('copySensitive', {'text': text});
    } on MissingPluginException {
      // Fora do Android (testes, outras plataformas): cópia comum, sem limpeza.
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }
    _due = false;
    _timer?.cancel();
    _timer = Timer(clearAfter, () {
      _due = true;
      unawaited(_tryClear());
    });
  }

  /// Chamado pelo ciclo de vida do app.
  static void onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _due) unawaited(_tryClear());
  }

  static Future<void> _tryClear() async {
    if (!_foreground) return; // Android 10+ não deixa ver a área em 2º plano.
    _due = false;
    try {
      await _channel.invokeMethod<bool>('clearIfUnchanged');
    } on MissingPluginException {
      // sem plataforma nativa
    } on PlatformException {
      // limpeza é melhor esforço
    }
  }

  /// Só para testes.
  static void resetForTest() {
    _timer?.cancel();
    _timer = null;
    _due = false;
    _foreground = true;
  }
}
