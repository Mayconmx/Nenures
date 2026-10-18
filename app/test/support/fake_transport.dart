import 'dart:async';

import 'package:nenures/conversation/invite.dart';
import 'package:nenures/conversation/transport.dart';

/// Marca procurada pelo CI dentro do binário de release. Se aparecer lá, o
/// transporte falso vazou para o build e o CI falha (tools/check_release_apk.sh).
const fakeTransportMarker = 'NENURES_FAKE_TRANSPORT_NAO_VAI_PARA_RELEASE';

/// Transporte FALSO, só para testes e para a demonstração local.
///
/// - Não cifra nada e não abre conexão de rede.
/// - Vive em test/, fora de lib/: o app de verdade não consegue importá-lo.
/// - Nunca é chamado de "modo inseguro" nem oferecido a quem usa o app.
class FakeConversationTransport implements ConversationTransport {
  FakeConversationTransport({this.nextInvite, this.joinResult});

  /// Convite devolvido por [createRoom].
  Invite? nextInvite;

  /// Resultado de [joinRoom]: contagem (int) ou exceção a lançar.
  Object? joinResult;

  /// Exceção a lançar em [send] (simula falha de envio).
  TransportException? sendError;

  final sent = <String>[];
  int leaveCalls = 0;
  Invite? joinedWith;

  final _events = StreamController<TransportEvent>.broadcast();

  /// Mantido pelo compilador AOT sempre que a classe é instanciada, o que dá ao
  /// CI um controle positivo: o build da demonstração contém a marca.
  @override
  String toString() => 'FakeConversationTransport($fakeTransportMarker)';

  @override
  Stream<TransportEvent> get events => _events.stream;

  @override
  Future<Invite> createRoom() async =>
      nextInvite ??
      Invite(const [
        'abacate',
        'abelha',
        'abismo',
        'absinto',
        'acervo',
        'achado',
        'aceno',
        'acesso',
      ]);

  @override
  Future<int> joinRoom(Invite invite) async {
    joinedWith = invite;
    final r = joinResult ?? 2;
    if (r is Exception) throw r;
    return r as int;
  }

  @override
  Future<void> send(String text) async {
    if (sendError != null) throw sendError!;
    sent.add(text);
  }

  @override
  Future<void> leave() async => leaveCalls++;

  // --- controles do teste ---
  void emit(TransportEvent e) => _events.add(e);
  void someoneJoins(int count) =>
      emit(PresenceChanged(count, PresenceChange.joined));
  void someoneLeaves(int count) =>
      emit(PresenceChanged(count, PresenceChange.left));
  void receive(String text) => emit(MessageReceived(text));

  Future<void> close() => _events.close();
}
