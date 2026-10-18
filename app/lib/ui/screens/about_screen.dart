import 'package:flutter/material.dart';

import '../../design/nenures_icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../widgets/frame.dart';

const sourceCodeUrl = 'https://github.com/Mayconmx/Nenures';

/// Sobre: o que o app faz, o que não faz e por quê. Sem promessas absolutas.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium!.copyWith(color: context.nColors.inkMuted);

    Widget section(String title, String body) => Padding(
      padding: const EdgeInsets.only(top: NenuresSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: t.labelLarge)),
          const SizedBox(height: NenuresSpace.s1),
          Text(body, style: muted),
        ],
      ),
    );

    return ScreenFrame(
      top: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(NenuresIcons.arrowBack),
          ),
          const SizedBox(width: NenuresSpace.s1),
          Semantics(header: true, child: Text('Sobre', style: t.titleLarge)),
        ],
      ),
      children: [
        section(
          'O que é',
          'Um app de conversas temporárias, sem cadastro. Uma chave abre a '
              'conversa; quando a última pessoa sai, ela deixa de existir no '
              'servidor. É um projeto sem fins lucrativos, sem anúncios.',
        ),
        section(
          'Sem notificações',
          'O app não envia notificações. Como não existe conta, não há para '
              'onde mandá-las. Você só recebe mensagens com o app aberto, e '
              'sair dele por mais de 1 minuto encerra a sua participação.',
        ),
        section(
          'O que o servidor vê',
          'O servidor repassa mensagens cifradas e não tem as chaves para lê-las. '
              'Ele ainda vê o endereço IP, os horários, o tamanho e o volume do '
              'tráfego, e quantas conexões cada conversa tem.',
        ),
        section(
          'O que o app não consegue impedir',
          'Fotos da tela feitas com outro aparelho, cópias do texto, um celular '
              'com programa malicioso, e o que o teclado ou outros apps guardam. '
              'No Android, prints e gravações da tela são bloqueados.',
        ),
        section(
          'Estado desta versão',
          'Versão de teste. A criptografia e a conexão com o servidor ainda '
              'passam por revisão de segurança e não estão ativas.',
        ),
        section('Código-fonte', sourceCodeUrl),
        const SizedBox(height: NenuresSpace.s4),
      ],
    );
  }
}
