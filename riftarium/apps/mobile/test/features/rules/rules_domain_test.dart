import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/rules/domain/rules.dart';

import 'rules_fixture.dart';

void main() {
  final document = RulesDocument.fromJson(kRulesFixture);

  group('modèles', () {
    test('les deux livres sont lus dans l’ordre core puis tournament', () {
      expect(document.books.map((book) => book.key), ['core', 'tournament']);
      expect(document.core?.title, 'Règles du jeu');
      expect(document.tournament?.title, 'Règles de tournoi');
      expect(document.core?.updated, '16 juillet 2026');
      expect(document.core?.ruleCount, 5);
      expect(document.core?.source, 'https://exemple.test/core.pdf');
    });

    test('chapitres, sections et règles sont imbriqués', () {
      final core = document.core!;
      expect(core.chapters, hasLength(2));
      expect(core.chapters.first.sections, hasLength(2));
      expect(core.chapters.first.ruleCount, 3);
      final entry = core.chapters.first.sections.first.entries.single;
      expect(entry.number, '002.');
      expect(entry.bareNumber, '002');
      expect(entry.depth, 0);
    });

    test('exemples et renvois sont des objets typés', () {
      final entry = document.core!.chapters.first.sections.first.entries.single;
      expect(entry.examples, isEmpty);
      expect(entry.refs.single.number, '197');
      expect(entry.refs.single.label, 'Emplacements');

      final nested = document.core!.chapters.first.sections.last.entries.last;
      expect(nested.depth, 1);
      expect(nested.examples.single.text, contains('Gâchette folle'));
    });

    test('un JSON incomplet ne fait pas planter le décodage', () {
      final partial = RulesDocument.fromJson(const {
        'core': {
          'chapters': [
            {
              'title': 'Sans numéro',
              'sections': [
                {
                  'title': 'Section',
                  'entries': [
                    {'text': 'Règle sans numéro'},
                  ],
                },
              ],
            },
          ],
        },
      });
      final entry =
          partial.core!.chapters.single.sections.single.entries.single;
      expect(entry.number, '');
      expect(entry.depth, 0);
      expect(entry.refs, isEmpty);
    });

    test('la signature change avec updated ou ruleCount', () {
      final other = RulesDocument.fromJson(rulesFixtureUpdated());
      expect(document.signature, isNot(other.signature));
      expect(
        RulesDocument.fromJson(kRulesFixture).signature,
        document.signature,
      );
    });
  });

  group('localisation d’une règle', () {
    test('par numéro de section, de règle ou de chapitre', () {
      expect(document.locate('197')?.section.title, 'Emplacements');
      expect(document.locate('198.1.')?.entry?.id, '198-1');
      expect(document.locate('000')?.section.id, '001');
      expect(document.locate('999'), isNull);
    });

    test('le livre d’origine est consulté en premier', () {
      final fromTournament = document.locate('801', fromBookKey: 'tournament');
      expect(fromTournament?.book.key, 'tournament');
    });
  });

  group('searchRules', () {
    test('ignore la casse et les accents', () {
      final hits = searchRules(document, 'UNITE');
      expect(hits, hasLength(2));
      expect(
        hits.map((hit) => hit.entry.id),
        containsAll(<String>['051-1', '198-1']),
      );
    });

    test('cherche aussi dans les exemples', () {
      final hits = searchRules(document, 'gachette');
      expect(hits.single.entry.id, '051-1');
    });

    test('un numéro de règle remonte la règle en tête', () {
      final hits = searchRules(document, '051');
      expect(hits.first.entry.number, '051.');
      expect(hits.map((hit) => hit.entry.id), contains('051-1'));
    });

    test('tous les mots doivent être présents', () {
      expect(searchRules(document, 'unite legende'), hasLength(1));
      expect(searchRules(document, 'unite dragon'), isEmpty);
    });

    test('les deux livres sont cherchés, le fil est renseigné', () {
      final hit = searchRules(document, 'arbitre').single;
      expect(hit.book.key, 'tournament');
      expect(hit.breadcrumb, contains('Règles de tournoi'));
      expect(hit.breadcrumb, contains('Arbitrage'));
      expect(hit.snippet, contains('arbitre'));
    });

    test('requête trop courte : aucun résultat', () {
      expect(searchRules(document, ''), isEmpty);
      expect(searchRules(document, 'a'), isEmpty);
      expect(searchRules(document, '   '), isEmpty);
    });

    test('la limite est respectée', () {
      expect(searchRules(document, 'de', limit: 2), hasLength(2));
      expect(searchRules(document, 'de').length, greaterThan(2));
    });

    test('classement par nombre d’occurrences', () {
      // 198.1 cite deux fois « emplacement » : il passe devant 198, bien
      // qu'écrit après lui dans le document.
      final hits = searchRules(document, 'emplacement');
      expect(hits, hasLength(2));
      expect(hits.first.entry.id, '198-1');
      expect(hits.first.score, greaterThan(hits.last.score));
    });
  });

  test('foldForSearch replie accents, ligatures et apostrophes', () {
    expect(foldForSearch('ÉLÉMENTS'), 'elements');
    expect(foldForSearch('Cœur'), 'coeur');
    expect(foldForSearch('l’unité'), "l'unite");
  });

  test('le repliage garde la trace des index d’origine', () {
    final folded = foldForSearchWithOffsets('Cœur');
    expect(folded.folded, 'coeur');
    // « œ » (index 1) produit deux lettres qui renvoient toutes deux vers lui.
    expect(folded.offsets, [0, 1, 1, 2, 3]);
  });

  test('l’extrait reste aligné sur le texte malgré une ligature', () {
    // « cœur » se replie en cinq lettres pour quatre : sans correspondance
    // d'index, l'extrait démarrerait un caractère trop loin.
    final text = 'cœur B${'a' * 59}MOTCLE${'z' * 200}';
    final hit = searchRules(
      RulesDocument.fromJson({
        'core': {
          'chapters': [
            {
              'title': 'Chapitre',
              'sections': [
                {
                  'title': 'Section',
                  'entries': [
                    {'number': '900.', 'id': '900', 'text': text},
                  ],
                },
              ],
            },
          ],
        },
      }),
      'motcle',
    ).single;

    expect(hit.snippet, startsWith('… B${'a' * 10}'));
  });

  test('parseRuleDate lit les dates françaises du document', () {
    expect(parseRuleDate('16 juillet 2026'), DateTime.utc(2026, 7, 16));
    expect(parseRuleDate('5 août 2026'), DateTime.utc(2026, 8, 5));
    expect(parseRuleDate('bientôt'), isNull);
  });

  test('peekRulesUpdatedAt lit la date sans décoder le document', () {
    expect(peekRulesUpdatedAt(kRulesFixtureSource), DateTime.utc(2026, 7, 16));
    // La plus récente des deux dates l'emporte.
    expect(
      peekRulesUpdatedAt(
        '{"a":{"updated":"1 mai 2026"},'
        '"b":{"updated":"3 juin 2026"}}',
      ),
      DateTime.utc(2026, 6, 3),
    );
    expect(peekRulesUpdatedAt('{}'), isNull);
  });
}
