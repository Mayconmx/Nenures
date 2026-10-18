import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../conversation/invite.dart';
import '../../design/nenures_icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../platform/sensitive_clipboard.dart';
import 'frame.dart';

/// QR preto sobre branco nos dois temas, com zona de silêncio de 4 módulos.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = NenuresSize.qr});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );
    return Semantics(
      label: 'QR code da chave',
      image: true,
      child: Container(
        decoration: BoxDecoration(
          color: NenuresPalette.qrLight,
          borderRadius: BorderRadius.circular(NenuresRadius.md),
        ),
        padding: const EdgeInsets.all(NenuresSpace.s2),
        child: CustomPaint(size: Size.square(size), painter: _QrPainter(image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;

  static const _quiet = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount + _quiet * 2;
    final cell = size.width / n;
    final paint = Paint()
      ..color = NenuresPalette.qrDark
      ..isAntiAlias = false;
    for (var r = 0; r < image.moduleCount; r++) {
      for (var c = 0; c < image.moduleCount; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (c + _quiet) * cell,
              (r + _quiet) * cell,
              cell + 0.5,
              cell + 0.5,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}

/// "expira em m:ss"; muda para warn no último minuto.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.until});
  final DateTime until;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var left = widget.until.difference(clock.now());
    if (left.isNegative) left = Duration.zero;
    final m = left.inMinutes;
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    final low = left <= NenuresLimits.keyWarnAt;
    final style = context.nText.timer.copyWith(
      color: low ? context.nColors.warn : null,
    );
    return Semantics(
      label: 'A chave expira em $m minutos e $s segundos se ninguém entrar',
      excludeSemantics: true,
      child: Text('expira em $m:$s', style: style, textAlign: TextAlign.center),
    );
  }
}

/// Caixa da chave: QR, palavras, validade e botão de copiar.
class KeyCard extends StatelessWidget {
  const KeyCard({super.key, required this.invite, this.expiresAt});

  final Invite invite;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final c = context.nColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(NenuresSpace.s4),
          decoration: BoxDecoration(
            color: c.surfaceSunk,
            borderRadius: BorderRadius.circular(NenuresRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              QrView(data: invite.qrPayload),
              const SizedBox(height: NenuresSpace.s3),
              Semantics(
                label: 'Palavras da chave: ${invite.words.join(', ')}',
                excludeSemantics: true,
                child: Text(
                  invite.text,
                  style: context.nText.key,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NenuresSpace.s2),
        if (expiresAt != null) Countdown(until: expiresAt!),
        const SizedBox(height: NenuresSpace.s2),
        Center(
          child: OutlinedButton.icon(
            style: NenuresButtons.small(context),
            onPressed: () => copyInviteWithWarning(context, invite),
            icon: const Icon(NenuresIcons.contentCopy, size: 18),
            label: const Text('Copiar chave'),
          ),
        ),
      ],
    );
  }
}

/// Aviso antes de copiar (3.1, D13). Só copia se a pessoa confirmar.
Future<void> copyInviteWithWarning(BuildContext context, Invite invite) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Copiar a chave?'),
      content: const Text(
        'Quem tiver estas palavras pode entrar na conversa. '
        'Outros apps, o teclado e a sincronização da área de transferência '
        'podem ler o que você copia. Prefira mostrar o QR code.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Copiar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await SensitiveClipboard.copy(invite.text);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Chave copiada.')));
}
