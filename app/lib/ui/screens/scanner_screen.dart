import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../conversation/invite.dart';
import '../../design/nenures_icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../platform/qr_decoder.dart';

/// Leitura do QR da chave (D17): câmera oficial do Flutter + decodificação em
/// Dart (zxing2), sem serviços do Google. A permissão de câmera só é pedida ao
/// abrir esta tela. Nenhum quadro é gravado; cada quadro é analisado em memória
/// e descartado. Devolve o [Invite] lido, ou null.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  /// Prazo para a câmera abrir.
  static const openTimeout = Duration(seconds: 5);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _camera;
  String? _error;
  bool _busy = false;
  bool _done = false;
  DateTime _lastTry = DateTime.fromMillisecondsSinceEpoch(0);

  /// Intervalo entre tentativas de leitura (aparelhos baratos, D17).
  static const _every = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    CameraController? cam;
    try {
      // Prazo só para listar as câmeras: um serviço travado não prende a tela.
      final cams = await availableCameras().timeout(ScannerScreen.openTimeout);
      if (cams.isEmpty) {
        _fail('Este aparelho não tem câmera disponível.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      cam = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      // Sem prazo: inclui a janela de permissão, que espera a pessoa responder.
      await cam.initialize();
      if (!mounted) {
        await cam.dispose();
        return;
      }
      setState(() => _camera = cam);
      await cam.startImageStream(_onFrame);
    } on CameraException catch (e) {
      await _release(cam);
      _fail(
        e.code.contains('Access') || e.code.contains('ermission')
            ? 'Sem permissão para usar a câmera. Você pode digitar as palavras.'
            : _cannotOpen,
      );
    } on Object {
      // Plugin indisponível ou falha inesperada: nunca trava a tela.
      await _release(cam);
      _fail(_cannotOpen);
    }
  }

  static const _cannotOpen =
      'Não foi possível abrir a câmera. Você pode digitar as palavras.';

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Libera a câmera se ela foi criada mas não chegou a ser exibida. Nunca
  /// deixa a câmera ligada sem a tela (achado no teste do emulador).
  Future<void> _release(CameraController? cam) async {
    if (cam == null) return;
    if (identical(cam, _camera)) {
      _camera = null;
      if (mounted) setState(() {});
    }
    try {
      await cam.dispose();
    } on Object {
      // já liberada
    }
  }

  void _onFrame(CameraImage img) {
    final now = DateTime.now();
    if (_busy || _done || now.difference(_lastTry) < _every) return;
    _lastTry = now;
    _busy = true;
    final y = img.planes.first;
    final frame = LumaFrame(
      Uint8List.fromList(y.bytes),
      img.width,
      img.height,
      y.bytesPerRow,
    );
    unawaited(
      compute(decodeQr, frame).then((text) {
        _busy = false;
        if (_done || text == null || !mounted) return;
        final invite = Invite.tryParseQr(text);
        if (invite == null) {
          setState(() => _error = 'Este QR code não é uma chave do nenures.');
          return;
        }
        _done = true;
        Navigator.of(context).pop(invite);
      }),
    );
  }

  @override
  void dispose() {
    final cam = _camera;
    _camera = null;
    if (cam != null) {
      unawaited(() async {
        if (cam.value.isStreamingImages) await cam.stopImageStream();
        await cam.dispose();
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cam = _camera;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NenuresSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(NenuresIcons.arrowBack),
                  ),
                  const SizedBox(width: NenuresSpace.s1),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Ler QR code', style: t.titleLarge),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NenuresSpace.s3),
              Text(
                'Aponte para o QR code da chave. A imagem da câmera não é '
                'guardada.',
                style: t.bodyMedium!.copyWith(color: context.nColors.inkMuted),
              ),
              const SizedBox(height: NenuresSpace.s4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NenuresRadius.lg),
                  child: ColoredBox(
                    color: context.nColors.surfaceSunk,
                    child: cam != null && cam.value.isInitialized
                        ? Center(
                            child: Semantics(
                              label: 'Imagem da câmera',
                              child: CameraPreview(cam),
                            ),
                          )
                        : Center(
                            child: _error == null
                                ? const CircularProgressIndicator()
                                : Padding(
                                    padding: const EdgeInsets.all(
                                      NenuresSpace.s4,
                                    ),
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: t.bodyMedium,
                                    ),
                                  ),
                          ),
                  ),
                ),
              ),
              if (_error != null && cam != null) ...[
                const SizedBox(height: NenuresSpace.s3),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: t.bodyMedium!.copyWith(
                      color: context.nColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: NenuresSpace.s3),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Digitar as palavras'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
