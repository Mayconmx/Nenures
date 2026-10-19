import 'package:flutter/foundation.dart';

import 'invite.dart';

/// Máquina de estados da conversa (prompt, seção 9).
///
/// ```text
/// Idle --gerar--> CreatingRoom --ok--> InConversation(waiting)
///                              --falha--> Failed
/// Idle --entrar--> Joining --ok--> InConversation(connected)
///                          --recusado--> Idle (erro mostrado na tela de entrada)
/// InConversation(waiting) --alguém entra--> InConversation(connected)
/// InConversation(waiting) --10 min--> Ended(expired)
/// InConversation(connected) --queda--> InConversation(reconnecting)
/// InConversation(reconnecting) --volta--> InConversation(connected)
/// InConversation(*) --Encerrar / 60 s em 2º plano / sessão perdida--> Ending --> Ended
/// InConversation(waiting) --Cancelar--> Ending --> Idle
/// Ended / Failed --voltar--> Idle
/// ```
@immutable
sealed class ConversationState {
  const ConversationState();
}

final class Idle extends ConversationState {
  const Idle();
}

final class CreatingRoom extends ConversationState {
  const CreatingRoom();
}

final class Joining extends ConversationState {
  const Joining();
}

enum ConversationPhase { waiting, connected, reconnecting }

final class InConversation extends ConversationState {
  const InConversation({
    required this.invite,
    required this.phase,
    required this.participants,
    required this.items,
    required this.isCreator,
    this.expiresAt,
    this.showingKey = false,
    this.locked = false,
  });

  final Invite invite;
  final ConversationPhase phase;

  /// Contagem validada pelo protocolo (inclui você).
  final int participants;
  final List<ChatItem> items;
  final bool isCreator;

  /// Só enquanto ninguém entrou (P3). Depois disso a chave vale enquanto a
  /// conversa existir (P4).
  final DateTime? expiresAt;

  /// Tela "Sua chave" aberta por cima da conversa.
  final bool showingKey;

  /// Entrada trancada (D7): a chave não abre mais esta conversa.
  final bool locked;

  InConversation copyWith({
    ConversationPhase? phase,
    int? participants,
    List<ChatItem>? items,
    DateTime? expiresAt,
    bool clearExpiry = false,
    bool? showingKey,
    bool? locked,
  }) => InConversation(
    invite: invite,
    phase: phase ?? this.phase,
    participants: participants ?? this.participants,
    items: items ?? this.items,
    isCreator: isCreator,
    expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
    showingKey: showingKey ?? this.showingKey,
    locked: locked ?? this.locked,
  );
}

final class Ending extends ConversationState {
  const Ending();
}

enum EndReason { left, expired, connectionLost, backgrounded }

final class Ended extends ConversationState {
  const Ended(this.reason);
  final EndReason reason;
}

enum FailureKind { unavailable, network }

final class Failed extends ConversationState {
  const Failed(this.kind);
  final FailureKind kind;
}

enum ChatItemKind { mine, theirs, system }

@immutable
class ChatItem {
  const ChatItem(this.id, this.kind, this.text);
  final int id;
  final ChatItemKind kind;
  final String text;
}
