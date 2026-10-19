import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/conversation_controller.dart';
import '../../conversation/conversation_state.dart';
import '../../conversation/invite.dart';
import '../../design/nenures_icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../widgets/frame.dart';
import 'scanner_screen.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _field = TextEditingController();
  String? _error;

  static String message(JoinError e) => switch (e) {
    JoinError.empty => 'Digite as palavras da chave.',
    JoinError.wrongWordCount =>
      'A chave tem $inviteWordCount palavras separadas por espaço.',
    JoinError.invalidCharacters =>
      'A chave só tem letras. Confira se não há números ou símbolos.',
    JoinError.notFound =>
      'Chave não encontrada ou expirada. Peça uma nova para quem te convidou.',
    JoinError.full => 'Esta conversa está cheia.',
    JoinError.locked => 'A entrada nesta conversa foi trancada.',
    JoinError.invalidWords =>
      'Alguma palavra não existe na lista. Confira a chave letra por letra.',
    JoinError.noAnswer =>
      'Ninguém na conversa respondeu a tempo. Tente de novo em instantes.',
    JoinError.tryLater =>
      'O servidor está ocupado. Tente de novo em instantes.',
    JoinError.unavailable =>
      'Esta versão de teste ainda não consegue entrar em conversas.',
    JoinError.network =>
      'Sem conexão com o servidor. Confira a internet e tente de novo.',
  };

  Future<void> _submit() async {
    setState(() => _error = null);
    final err = await ref.read(conversationProvider.notifier).join(_field.text);
    if (!mounted) return;
    if (err == null) {
      // Apaga o texto do campo e volta para a raiz, que agora mostra o chat.
      _field.clear();
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      setState(() => _error = message(err));
    }
  }

  /// D17: câmera só ao tocar; o QR traz as mesmas palavras da chave.
  Future<void> _scan() async {
    final invite = await Navigator.of(context)
        .push<Invite>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (invite == null || !mounted) return;
    _field.text = invite.text;
    await _submit();
  }

  @override
  void dispose() {
    _field.clear();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final joining = ref.watch(conversationProvider) is Joining;
    return ScreenFrame(
      actions: [
        FilledButton(
          onPressed: joining ? null : _submit,
          child: Text(joining ? 'Entrando…' : 'Entrar'),
        ),
        TextButton(
          onPressed: joining ? null : () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
      ],
      children: [
        const SizedBox(height: NenuresSpace.s6),
        Semantics(
          header: true,
          child: Text('Entrar com chave', style: t.titleLarge),
        ),
        const SizedBox(height: NenuresSpace.s2),
        Text(
          'Digite as $inviteWordCount palavras que você recebeu.',
          style: t.bodyMedium!.copyWith(color: context.nColors.inkMuted),
        ),
        const SizedBox(height: NenuresSpace.s4),
        TextField(
          controller: _field,
          enabled: !joining,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          style: context.nText.key.copyWith(fontSize: 16, height: 1.5),
          // Sem sugestões, correção nem aprendizado do teclado (3.1, tela 3).
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Chave',
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: NenuresSpace.s3),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: joining ? null : _scan,
            icon: const Icon(NenuresIcons.qrCodeScanner),
            label: const Text('Ler QR code'),
          ),
        ),
      ],
    );
  }
}
