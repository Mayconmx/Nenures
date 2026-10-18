import 'package:flutter/material.dart';

import 'design/theme.dart';

void main() {
  runApp(const NenuresApp());
}

/// Ponto de entrada. As telas chegam na etapa 2.3.
class NenuresApp extends StatelessWidget {
  const NenuresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nenures',
      debugShowCheckedModeBanner: false,
      theme: buildNenuresTheme(Brightness.light),
      darkTheme: buildNenuresTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Scaffold(body: Center(child: Text('nenures'))),
    );
  }
}
