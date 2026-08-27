import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/theme.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_rich_text.dart';

void main() {
  group('découpage du texte enrichi', () {
    test('le texte simple donne un seul morceau', () {
      final parts = parseRuleText('Une unité se déplace.');
      expect(parts.single.kind, RulePartKind.text);
      expect(parts.single.bold, isFalse);
      expect(parts.single.value, 'Une unité se déplace.');
    });

    test('les doubles astérisques marquent le gras', () {
      final parts = parseRuleText('Phase **d’éveil** : redressez.');
      expect(parts.map((p) => p.value), ['Phase ', 'd’éveil', ' : redressez.']);
      expect(parts.map((p) => p.bold), [false, true, false]);
    });

    test('les crochets deviennent des mots-clés, avec leur famille', () {
      final parts = parseRuleText('Jouez une [Réaction] puis un [Assaut 2].');
      final keywords = parts
          .where((part) => part.kind == RulePartKind.keyword)
          .toList();
      expect(keywords.map((k) => k.value), ['Réaction', 'Assaut 2']);
      // Familles relevées sur les cartes : timing pour Réaction, combat pour
      // Assaut (le chiffre ne change pas la famille).
      expect(keywords.map((k) => k.family), ['timing', 'combat']);
    });

    test('un mot-clé suivi de [>] se termine en pointe', () {
      final parts = parseRuleText('[Agonie][>] Piochez.');
      expect(parts.first.kind, RulePartKind.keyword);
      expect(parts.first.family, 'state');
      expect(parts.first.arrow, isTrue);
      expect(parts.length, 2);
    });

    test('« NO TEXT » disparaît', () {
      expect(parseRuleText('[NO TEXT]'), isEmpty);
    });

    test('les shortcodes deviennent des glyphes', () {
      final parts = parseRuleText('Payez :rb_energy_2: et :rb_rune_fury:.');
      final glyphs = parts
          .where((part) => part.kind == RulePartKind.glyph)
          .toList();
      expect(glyphs.map((g) => g.token), ['energy_2', 'rune_fury']);
      expect(glyphs.map((g) => g.label), ['Énergie 2', 'Rune de Fureur']);
      // Repli affiché quand le SVG ne se charge pas.
      expect(glyphs.map((g) => g.value), ['[2]', '[R]']);
    });

    test('les abréviations du texte officiel donnent les mêmes glyphes', () {
      final parts = parseRuleText('Coût [1][R], puis [E] et [M].');
      final glyphs = parts
          .where((part) => part.kind == RulePartKind.glyph)
          .toList();
      expect(glyphs.map((g) => g.token), [
        'energy_1',
        'rune_fury',
        'exhaust',
        'might',
      ]);
      expect(glyphs.where((g) => g.ink).map((g) => g.token), [
        'exhaust',
        'might',
      ]);
    });

    test('un shortcode inconnu reste du texte', () {
      final parts = parseRuleText('Voir :rb_inconnu: ici.');
      expect(parts.single.kind, RulePartKind.text);
      expect(parts.single.value, 'Voir :rb_inconnu: ici.');
    });

    test('gras et mot-clé se combinent', () {
      final parts = parseRuleText('**Une [Vision] forte**');
      expect(parts.every((part) => part.bold), isTrue);
      expect(parts[1].kind, RulePartKind.keyword);
    });
  });

  testWidgets('le rendu affiche le texte et la pastille du mot-clé', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: RuleRichText('Jouez une [Réaction] **maintenant**.'),
        ),
      ),
    );
    await tester.pump();

    // Le mot-clé est une pastille : capitales, hors du flux de texte.
    expect(find.text('RÉACTION'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
  });
}
