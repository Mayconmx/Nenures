/// Convite ("chave" na interface).
///
/// Esta etapa só trata a FORMA do convite: normalização e contagem de palavras.
/// A geração do segredo, a lista de palavras e o formato do QR dependem das
/// decisões D4 e D5 (docs/decisoes/decisoes-pendentes.md) e ficam a cargo da
/// implementação de [ConversationTransport] aprovada na Fase 5.
library;

/// Número de palavras proposto em D4 (88 bits com uma lista de 2048 palavras).
/// Pendente de aprovação.
const int inviteWordCount = 8;

/// Prefixo provisório do conteúdo do QR (D4).
const String inviteQrPrefix = 'nenures:1:';

const Map<String, String> _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Normalização determinística das palavras digitadas:
/// minúsculas; acentos do português removidos; qualquer sequência de espaços,
/// quebras de linha, vírgulas, pontos ou hífens vira um separador; bordas
/// removidas. Ex.: "  Ábaco,  ABELHA\n" -> ["abaco", "abelha"].
List<String> normalizeInviteWords(String input) {
  final lower = input.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_accents[ch] ?? ch);
  }
  return buf
      .toString()
      .split(RegExp(r'[\s,.;\-]+'))
      .where((w) => w.isNotEmpty)
      .toList(growable: false);
}

enum InviteFormatError { empty, wrongWordCount, invalidCharacters }

/// Valida só a forma. A presença das palavras na lista aprovada (D5) é
/// verificada pela implementação real do transporte.
InviteFormatError? checkInviteFormat(List<String> words) {
  if (words.isEmpty) return InviteFormatError.empty;
  if (words.length != inviteWordCount) return InviteFormatError.wrongWordCount;
  final letters = RegExp(r'^[a-z]+$');
  if (!words.every(letters.hasMatch)) {
    return InviteFormatError.invalidCharacters;
  }
  return null;
}

/// Convite já normalizado. Nunca é registrado em log nem gravado em disco.
class Invite {
  Invite(List<String> words) : words = List.unmodifiable(words) {
    final err = checkInviteFormat(this.words);
    if (err != null) throw ArgumentError('convite com forma inválida: $err');
  }

  /// Interpreta o conteúdo lido de um QR. Retorna null se não for um convite.
  static Invite? tryParseQr(String raw) {
    if (!raw.startsWith(inviteQrPrefix)) return null;
    final words = normalizeInviteWords(raw.substring(inviteQrPrefix.length));
    return checkInviteFormat(words) == null ? Invite(words) : null;
  }

  final List<String> words;

  String get text => words.join(' ');
  String get qrPayload => '$inviteQrPrefix$text';

  /// Evita que o convite apareça por acidente em mensagens de erro ou logs.
  @override
  String toString() => 'Invite(<oculto>)';
}
