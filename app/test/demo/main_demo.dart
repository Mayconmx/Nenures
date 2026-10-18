// Demonstração local com o transporte FALSO. Não cifra nem usa rede.
//
//   flutter run -t test/demo/main_demo.dart
//
// Fica em test/ para nunca entrar no build de release (que usa lib/main.dart).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nenures/app.dart';
import 'package:nenures/conversation/conversation_controller.dart';
import 'package:nenures/conversation/invite.dart';

import '../support/fake_transport.dart';

void main() {
  final fake = _DemoTransport();
  runApp(
    ProviderScope(
      overrides: [transportProvider.overrideWithValue(fake)],
      child: const NenuresApp(),
    ),
  );
}

/// Simula outra pessoa: entra 3 s depois de criar a sala e responde.
class _DemoTransport extends FakeConversationTransport {
  static const _replies = ['oi! cheguei', 'entendi', 'pode falar', 'combinado'];
  int _n = 0;

  @override
  Future<Invite> createRoom() async {
    final invite = await super.createRoom();
    Timer(const Duration(seconds: 3), () => someoneJoins(2));
    return invite;
  }

  @override
  Future<void> send(String text) async {
    await super.send(text);
    Timer(const Duration(milliseconds: 900), () {
      receive(_replies[_n++ % _replies.length]);
    });
  }
}
