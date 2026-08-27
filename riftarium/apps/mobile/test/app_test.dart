import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/main.dart';

void main() {
  testWidgets('le squelette démarre et affiche le nom du projet', (
    tester,
  ) async {
    await tester.pumpWidget(const RiftariumApp());
    expect(find.text('Riftarium'), findsOneWidget);
  });
}
