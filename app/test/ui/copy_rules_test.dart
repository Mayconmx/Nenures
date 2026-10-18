import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seção 15 do prompt e "Voz" do design system: nenhuma promessa absoluta em
/// texto do app. Varre todo o código em lib/.
void main() {
  const forbidden = [
    '100% seguro',
    'inviolável',
    'impossível de copiar',
    'sem nenhum rastro',
    'nada é guardado',
    'nada ficou guardado',
    'apagada de vez',
    'totalmente anônimo',
    'anonimato total',
    'à prova de',
  ];

  test('nenhuma promessa absoluta em lib/', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync().toLowerCase();
      for (final phrase in forbidden) {
        if (text.contains(phrase)) hits.add('${f.path}: "$phrase"');
      }
    }
    expect(hits, isEmpty);
  });

  test('o app não importa nada de test/', () {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      expect(text.contains('fake_transport'), isFalse, reason: f.path);
      expect(text.contains("'../test/"), isFalse, reason: f.path);
    }
  });
}
