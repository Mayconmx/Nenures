import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/platform/sensitive_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nenures/clipboard');
  late List<String> calls;

  setUp(() {
    calls = [];
    SensitiveClipboard.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'clearIfUnchanged' ? true : null;
        });
  });

  tearDown(() {
    SensitiveClipboard.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('copia marcando como sensível e tenta limpar após 60 s (D13)', () {
    fakeAsync((async) {
      SensitiveClipboard.copy('a b c d e f g h');
      async.flushMicrotasks();
      expect(calls, ['copySensitive']);
      async.elapse(const Duration(seconds: 59));
      expect(calls, ['copySensitive']);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(calls, ['copySensitive', 'clearIfUnchanged']);
    });
  });

  test('em segundo plano espera voltar para limpar', () {
    fakeAsync((async) {
      SensitiveClipboard.copy('a b c d e f g h');
      async.flushMicrotasks();
      SensitiveClipboard.onLifecycle(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: 90));
      async.flushMicrotasks();
      expect(calls, ['copySensitive']);
      SensitiveClipboard.onLifecycle(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(calls, ['copySensitive', 'clearIfUnchanged']);
      // Só uma tentativa por cópia.
      SensitiveClipboard.onLifecycle(AppLifecycleState.paused);
      SensitiveClipboard.onLifecycle(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(calls, ['copySensitive', 'clearIfUnchanged']);
    });
  });

  test('nova cópia reinicia o prazo', () {
    fakeAsync((async) {
      SensitiveClipboard.copy('primeira');
      async.elapse(const Duration(seconds: 40));
      SensitiveClipboard.copy('segunda');
      async.elapse(const Duration(seconds: 40));
      async.flushMicrotasks();
      expect(calls.where((c) => c == 'clearIfUnchanged'), isEmpty);
      async.elapse(const Duration(seconds: 20));
      async.flushMicrotasks();
      expect(calls.where((c) => c == 'clearIfUnchanged'), hasLength(1));
    });
  });
}
