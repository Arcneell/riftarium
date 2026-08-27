import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/design/reveal.dart';

void main() {
  testWidgets('Reveal finit opaque quand les animations sont actives', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Reveal(index: 0, child: Text('x'))),
    );
    final before = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    await tester.pump(const Duration(milliseconds: 700));
    final after = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(before, lessThan(1));
    expect(after, 1);
  });

  testWidgets('Reveal décalé (index 3) finit opaque', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Reveal(index: 3, child: Text('x'))),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });
}
