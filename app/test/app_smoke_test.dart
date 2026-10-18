import 'package:flutter_test/flutter_test.dart';
import 'package:nenures/main.dart';

void main() {
  testWidgets('o app abre e mostra o nome', (tester) async {
    await tester.pumpWidget(const NenuresApp());
    expect(find.text('nenures'), findsOneWidget);
  });
}
