import 'invite.dart';

/// Fronteira entre a interface e a conversa (rede + criptografia).
///
/// A implementação real (Fase 5/6) faz MLS, conversa com o servidor e só
/// emite [PresenceChanged] a partir do estado criptográfico do grupo. A
/// interface confia nesta fronteira e em nada mais: ela nunca recebe contagem
/// de pessoas direto do servidor.
///
/// Implementações nesta fase:
/// - [UnavailableTransport]: a que vai no app hoje; recusa tudo com clareza.
/// - FakeConversationTransport: só em test/, nunca no build de release.
abstract interface class ConversationTransport {
  /// Eventos da conversa atual. Um único ouvinte (o controlador).
  Stream<TransportEvent> get events;

  /// Cria a sala e devolve o convite. Lança [TransportException].
  Future<Invite> createRoom();

  /// Entra na sala do convite e devolve o número de participantes validado
  /// pelo protocolo após a entrada. Lança [JoinException] ou [TransportException].
  Future<int> joinRoom(Invite invite);

  /// Envia uma mensagem de texto (já validada: não vazia, <= 1000 caracteres).
  Future<void> send(String text);

  /// Sai da conversa e descarta o estado local da sessão.
  Future<void> leave();
}

sealed class TransportEvent {
  const TransportEvent();
}

enum PresenceChange { joined, left }

/// Número de participantes validado pelo protocolo.
final class PresenceChanged extends TransportEvent {
  const PresenceChanged(this.count, this.change);
  final int count;
  final PresenceChange change;
}

final class MessageReceived extends TransportEvent {
  const MessageReceived(this.text);
  final String text;
}

/// A conexão caiu; o transporte está tentando recuperar (até 60 s, D9).
final class ConnectionInterrupted extends TransportEvent {
  const ConnectionInterrupted();
}

final class ConnectionRestored extends TransportEvent {
  const ConnectionRestored();
}

/// A sessão não pode continuar (reconexão falhou, estado inconsistente).
final class SessionLost extends TransportEvent {
  const SessionLost();
}

/// A chave expirou sem que ninguém entrasse (P3).
final class RoomExpired extends TransportEvent {
  const RoomExpired();
}

enum JoinFailure {
  /// Sala inexistente ou expirada. O servidor não distingue os dois casos.
  notFound,

  /// Teto técnico de participantes (D6).
  full,

  /// Entrada trancada por um participante (D7).
  locked,

  /// Alguma palavra não existe na lista (D5).
  invalidWords,

  /// Ninguém na conversa respondeu ao pedido a tempo.
  noAnswer,

  /// Servidor ocupado ou limite de tentativas atingido.
  tryLater,
}

class JoinException implements Exception {
  const JoinException(this.failure);
  final JoinFailure failure;
  @override
  String toString() => 'JoinException($failure)';
}

enum TransportFailure { unavailable, network }

class TransportException implements Exception {
  const TransportException(this.failure);
  final TransportFailure failure;
  @override
  String toString() => 'TransportException($failure)';
}

/// Implementação do app enquanto o protocolo não está aprovado (D1–D14).
/// Não finge funcionar: toda operação falha com [TransportFailure.unavailable].
class UnavailableTransport implements ConversationTransport {
  @override
  Stream<TransportEvent> get events => const Stream.empty();

  @override
  Future<Invite> createRoom() async =>
      throw const TransportException(TransportFailure.unavailable);

  @override
  Future<int> joinRoom(Invite invite) async =>
      throw const TransportException(TransportFailure.unavailable);

  @override
  Future<void> send(String text) async =>
      throw const TransportException(TransportFailure.unavailable);

  @override
  Future<void> leave() async {}
}
