import 'package:flutter/material.dart';

void main() {
  runApp(const NenuresApp());
}

/// Ponto de entrada provisório da Fase 2.1. O tema e as telas chegam nas etapas 2.2 e 2.3.
class NenuresApp extends StatelessWidget {
  const NenuresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'nenures',
      home: Scaffold(body: Center(child: Text('nenures'))),
    );
  }
}
