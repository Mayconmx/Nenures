import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation/conversation_controller.dart';
import 'conversation/conversation_state.dart';
import 'design/theme.dart';
import 'platform/sensitive_clipboard.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/end_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/key_screen.dart';

class NenuresApp extends StatelessWidget {
  const NenuresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nenures',
      debugShowCheckedModeBanner: false,
      theme: buildNenuresTheme(Brightness.light),
      darkTheme: buildNenuresTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const LifecycleGuard(child: RootScreen()),
    );
  }
}

/// Escolhe a tela a partir do estado da conversa.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(conversationProvider);
    return switch (s) {
      Idle() || CreatingRoom() || Joining() => const HomeScreen(),
      InConversation(showingKey: true) => KeyScreen(state: s),
      InConversation() => ChatScreen(state: s),
      Ending() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      Ended() || Failed() => EndScreen(state: s),
    };
  }
}

/// Liga o ciclo de vida do app ao controlador (P7, seção 9).
/// paused/hidden: começa a contar 60 s; resumed: cancela; detached: sai.
/// O Android não garante entregar `detached`; o servidor também encerra a
/// participação quando a conexão cai.
class LifecycleGuard extends ConsumerStatefulWidget {
  const LifecycleGuard({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LifecycleGuard> createState() => _LifecycleGuardState();
}

class _LifecycleGuardState extends ConsumerState<LifecycleGuard> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    final ctrl = ref.read(conversationProvider.notifier);
    _listener = AppLifecycleListener(
      onStateChange: (state) {
        SensitiveClipboard.onLifecycle(state);
        switch (state) {
          case AppLifecycleState.paused:
          case AppLifecycleState.hidden:
            ctrl.onBackground();
          case AppLifecycleState.resumed:
            ctrl.onForeground();
          case AppLifecycleState.detached:
            ctrl.onDetached();
          case AppLifecycleState.inactive:
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
