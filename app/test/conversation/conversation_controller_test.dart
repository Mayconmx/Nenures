import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/conversation/conversation_controller.dart';
import 'package:nenures/conversation/conversation_state.dart';
import 'package:nenures/conversation/transport.dart';

import '../support/fake_transport.dart';

const eightWords = 'abacate abelha abismo absinto acervo achado aceno acesso';

void main() {
  late FakeConversationTransport fake;
  late ProviderContainer c;

  ConversationController ctrl() => c.read(conversationProvider.notifier);
  ConversationState state() => c.read(conversationProvider);
  InConversation conv() => state() as InConversation;

  void setUpWith(ConversationTransport t) {
    c = ProviderContainer(overrides: [transportProvider.overrideWithValue(t)]);
    addTearDown(c.dispose);
  }

  setUp(() {
    fake = FakeConversationTransport();
    setUpWith(fake);
  });

  /// Testes com relógio simulado precisam criar transporte e container dentro
  /// da zona do fakeAsync, senão as microtarefas caem na fila real.
  void inZone() {
    fake = FakeConversationTransport();
    setUpWith(fake);
  }

  group('criar sala', () {
    test('vai para "aguardando", mostra a chave e marca a validade', () {
      fakeAsync((async) {
        inZone();
        final start = clock.now();
        ctrl().createRoom();
        async.flushMicrotasks();
        final s = conv();
        expect(s.phase, ConversationPhase.waiting);
        expect(s.participants, 1);
        expect(s.isCreator, isTrue);
        expect(s.showingKey, isTrue);
        expect(s.expiresAt, start.add(const Duration(minutes: 10)));
        expect(s.items.single.text, SystemText.created);
      });
    });

    test('expira em 10 minutos se ninguém entrar (P3)', () {
      fakeAsync((async) {
        inZone();
        ctrl().createRoom();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 9, seconds: 59));
        expect(state(), isA<InConversation>());
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(state(), isA<Ended>());
        expect((state() as Ended).reason, EndReason.expired);
        expect(fake.leaveCalls, 1);
      });
    });

    test('depois que alguém entra, a chave continua valendo (P4)', () {
      fakeAsync((async) {
        inZone();
        ctrl().createRoom();
        async.flushMicrotasks();
        fake.someoneJoins(2);
        async.flushMicrotasks();
        expect(conv().phase, ConversationPhase.connected);
        expect(conv().expiresAt, isNull);
        expect(conv().participants, 2);
        expect(conv().items.last.text, SystemText.joined(2));
        async.elapse(const Duration(minutes: 30));
        expect(state(), isA<InConversation>());
      });
    });

    test('o servidor também pode avisar a expiração', () {
      fakeAsync((async) {
        inZone();
        ctrl().createRoom();
        async.flushMicrotasks();
        fake.emit(const RoomExpired());
        async.flushMicrotasks();
        expect((state() as Ended).reason, EndReason.expired);
      });
    });

    test('cancelar na tela da chave volta ao início', () {
      fakeAsync((async) {
        inZone();
        ctrl().createRoom();
        async.flushMicrotasks();
        ctrl().cancelKey();
        async.flushMicrotasks();
        expect(state(), isA<Idle>());
        expect(fake.leaveCalls, 1);
      });
    });

    test('sem protocolo aprovado, falha com "indisponível"', () async {
      setUpWith(UnavailableTransport());
      await ctrl().createRoom();
      expect((state() as Failed).kind, FailureKind.unavailable);
      ctrl().reset();
      expect(state(), isA<Idle>());
    });
  });

  group('entrar com chave', () {
    test('contagem errada é recusada sem chamar o servidor', () async {
      expect(await ctrl().join('lua vento'), JoinError.wrongWordCount);
      expect(await ctrl().join('   '), JoinError.empty);
      expect(fake.joinedWith, isNull);
      expect(state(), isA<Idle>());
    });

    test('normaliza antes de enviar', () async {
      final err = await ctrl().join(
        ' ABACATE abelha  Abismo absinto\nacervo achado acêno acesso ',
      );
      expect(err, isNull);
      expect(fake.joinedWith!.text, eightWords);
      expect(conv().phase, ConversationPhase.connected);
      expect(conv().participants, 2);
      expect(conv().isCreator, isFalse);
    });

    test('chave inexistente ou expirada', () async {
      fake.joinResult = const JoinException(JoinFailure.notFound);
      expect(await ctrl().join(eightWords), JoinError.notFound);
      expect(state(), isA<Idle>());
    });

    test('sala cheia, trancada e sem rede', () async {
      fake.joinResult = const JoinException(JoinFailure.full);
      expect(await ctrl().join(eightWords), JoinError.full);
      fake.joinResult = const JoinException(JoinFailure.locked);
      expect(await ctrl().join(eightWords), JoinError.locked);
      fake.joinResult = const TransportException(TransportFailure.network);
      expect(await ctrl().join(eightWords), JoinError.network);
    });
  });

  group('conversa', () {
    Future<void> joined() async => ctrl().join(eightWords);

    test('envia e recebe', () async {
      await joined();
      expect(await ctrl().send('  oi  '), isTrue);
      expect(fake.sent, ['oi']);
      fake.receive('olá');
      await Future<void>.delayed(Duration.zero);
      final kinds = conv().items.map((i) => i.kind).toList();
      expect(kinds, [
        ChatItemKind.system,
        ChatItemKind.mine,
        ChatItemKind.theirs,
      ]);
    });

    test('recusa vazio e acima de 1000 caracteres', () async {
      await joined();
      expect(await ctrl().send('   '), isFalse);
      expect(await ctrl().send('a' * 1001), isFalse);
      expect(await ctrl().send('a' * 1000), isTrue);
      expect(fake.sent.single.length, 1000);
    });

    test(
      'falha de envio vira aviso e não mostra a mensagem como enviada',
      () async {
        await joined();
        fake.sendError = const TransportException(TransportFailure.network);
        expect(await ctrl().send('oi'), isFalse);
        expect(conv().items.last.text, SystemText.sendFailed);
        expect(conv().items.any((i) => i.kind == ChatItemKind.mine), isFalse);
      },
    );

    test('saídas atualizam o contador', () async {
      await joined();
      fake.someoneJoins(3);
      fake.someoneLeaves(2);
      fake.someoneLeaves(1);
      await Future<void>.delayed(Duration.zero);
      expect(conv().participants, 1);
      expect(conv().items.last.text, SystemText.left(1));
    });

    test('reconexão: bloqueia envio e volta ao normal', () async {
      await joined();
      fake.emit(const ConnectionInterrupted());
      await Future<void>.delayed(Duration.zero);
      expect(conv().phase, ConversationPhase.reconnecting);
      expect(await ctrl().send('oi'), isFalse);
      fake.emit(const ConnectionRestored());
      await Future<void>.delayed(Duration.zero);
      expect(conv().phase, ConversationPhase.connected);
    });

    test('trancar: pelo próprio aparelho e por outra pessoa (D7)', () async {
      await joined();
      expect(await ctrl().lockEntry(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(conv().locked, isTrue);
      expect(conv().items.last.text, SystemText.lockedByMe);
      expect(await ctrl().lockEntry(), isFalse, reason: 'já trancada');
      expect(fake.lockCalls, 1);
    });

    test('aviso de trancamento vindo de outra pessoa', () async {
      await joined();
      fake.emit(const EntryLocked(byMe: false));
      await Future<void>.delayed(Duration.zero);
      expect(conv().locked, isTrue);
      expect(conv().items.last.text, SystemText.lockedByOther);
      // Aviso repetido não duplica a mensagem.
      fake.emit(const EntryLocked(byMe: false));
      await Future<void>.delayed(Duration.zero);
      expect(
        conv().items.where((i) => i.text == SystemText.lockedByOther),
        hasLength(1),
      );
    });

    test('sessão perdida encerra', () async {
      await joined();
      fake.emit(const SessionLost());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect((state() as Ended).reason, EndReason.connectionLost);
    });

    test('Encerrar sai, chama o transporte e descarta as mensagens', () async {
      await joined();
      await ctrl().send('segredo');
      await ctrl().leave();
      expect((state() as Ended).reason, EndReason.left);
      expect(fake.leaveCalls, 1);
      // Mensagens recebidas depois de sair são ignoradas.
      fake.receive('tarde demais');
      await Future<void>.delayed(Duration.zero);
      expect(state(), isA<Ended>());
    });
  });

  group('ciclo de vida (P7)', () {
    void joinIn(FakeAsync async) {
      ctrl().join(eightWords);
      async.flushMicrotasks();
    }

    test('voltar antes de 60 s mantém a conversa', () {
      fakeAsync((async) {
        inZone();
        joinIn(async);
        ctrl().onBackground();
        async.elapse(const Duration(seconds: 59));
        ctrl().onForeground();
        async.elapse(const Duration(minutes: 5));
        expect(state(), isA<InConversation>());
      });
    });

    test('60 s em segundo plano encerram', () {
      fakeAsync((async) {
        inZone();
        joinIn(async);
        ctrl().onBackground();
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        expect((state() as Ended).reason, EndReason.backgrounded);
        expect(fake.leaveCalls, 1);
      });
    });

    test('detached sai na hora', () {
      fakeAsync((async) {
        inZone();
        joinIn(async);
        ctrl().onDetached();
        async.flushMicrotasks();
        expect((state() as Ended).reason, EndReason.left);
      });
    });

    test('segundo plano fora de conversa não faz nada', () {
      fakeAsync((async) {
        inZone();
        ctrl().onBackground();
        async.elapse(const Duration(minutes: 2));
        expect(state(), isA<Idle>());
      });
    });
  });
}
