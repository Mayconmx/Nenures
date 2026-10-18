import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/conversation/invite.dart';

void main() {
  group('normalizeInviteWords', () {
    test('minúsculas, sem acentos, separadores variados', () {
      expect(normalizeInviteWords('  Ábaco,  ABELHA\nçedro-ÍNDIO.  ãnimo; '), [
        'abaco',
        'abelha',
        'cedro',
        'indio',
        'animo',
      ]);
    });

    test('é determinística e idempotente', () {
      const raw = 'Lua  VENTO\tpédra';
      final once = normalizeInviteWords(raw);
      expect(normalizeInviteWords(raw), once);
      expect(normalizeInviteWords(once.join(' ')), once);
    });

    test('entrada vazia vira lista vazia', () {
      expect(normalizeInviteWords('   \n '), isEmpty);
    });
  });

  group('checkInviteFormat', () {
    List<String> words(int n) => List.filled(n, 'abacate');

    test('aceita exatamente $inviteWordCount palavras de letras', () {
      expect(checkInviteFormat(words(inviteWordCount)), isNull);
    });

    test('recusa vazio, contagem errada e caracteres inválidos', () {
      expect(checkInviteFormat([]), InviteFormatError.empty);
      expect(
        checkInviteFormat(words(inviteWordCount - 1)),
        InviteFormatError.wrongWordCount,
      );
      expect(
        checkInviteFormat(words(inviteWordCount + 1)),
        InviteFormatError.wrongWordCount,
      );
      expect(
        checkInviteFormat([...words(inviteWordCount - 1), 'abc1']),
        InviteFormatError.invalidCharacters,
      );
    });
  });

  group('Invite', () {
    final w = List.generate(inviteWordCount, (i) => 'palavra${'x' * i}');

    test('QR e texto usam o mesmo segredo', () {
      final i = Invite(w);
      expect(i.qrPayload, '$inviteQrPrefix${w.join(' ')}');
      expect(Invite.tryParseQr(i.qrPayload)!.words, w);
    });

    test('QR de outra coisa não é aceito', () {
      expect(Invite.tryParseQr('https://exemplo.com'), isNull);
      expect(Invite.tryParseQr('${inviteQrPrefix}poucas palavras'), isNull);
    });

    test('toString não revela as palavras', () {
      final s = Invite(w).toString();
      for (final word in w) {
        expect(s.contains(word), isFalse);
      }
    });

    test('forma inválida é recusada no construtor', () {
      expect(() => Invite(const ['uma']), throwsArgumentError);
    });
  });
}
