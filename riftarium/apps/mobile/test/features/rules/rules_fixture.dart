import 'dart:convert';

/// Petit document de test : même forme que `assets/rules/rules-fr.json`,
/// deux livres, avec accents, exemples et renvois.
const Map<String, dynamic> kRulesFixture = {
  'core': {
    'key': 'core',
    'title': 'Règles du jeu',
    'subtitle': 'Le moteur complet d’une partie de Riftbound',
    'updated': '16 juillet 2026',
    'source': 'https://exemple.test/core.pdf',
    'ruleCount': 5,
    'chapters': [
      {
        'number': '000.',
        'id': '000',
        'title': 'Règles d’or et d’argent',
        'sections': [
          {
            'number': '001.',
            'id': '001',
            'title': 'Règle d’or',
            'entries': [
              {
                'number': '002.',
                'id': '002',
                'depth': 0,
                'text':
                    'Ce qui est inscrit sur une carte a priorité sur les '
                    'règles du jeu.',
                'examples': <Map<String, dynamic>>[],
                'refs': [
                  {'number': '197', 'label': 'Emplacements'},
                ],
              },
            ],
          },
          {
            'number': '050.',
            'id': '050',
            'title': 'Règle d’argent',
            'entries': [
              {
                'number': '051.',
                'id': '051',
                'depth': 0,
                'text': 'La terminologie des cartes diffère des règles.',
                'examples': <Map<String, dynamic>>[],
                'refs': <Map<String, dynamic>>[],
              },
              {
                'number': '051.1.',
                'id': '051-1',
                'depth': 1,
                'text': 'Les unités et légendes disent « je », « moi ».',
                'examples': [
                  {'text': 'Gâchette folle possède le tag Jinx.'},
                ],
                'refs': <Map<String, dynamic>>[],
              },
            ],
          },
        ],
      },
      {
        'number': '100.',
        'id': '100',
        'title': 'Éléments de jeu',
        'sections': [
          {
            'number': '197.',
            'id': '197',
            'title': 'Emplacements',
            'entries': [
              {
                'number': '198.',
                'id': '198',
                'depth': 0,
                'text': 'Chaque base est un emplacement.',
                'examples': <Map<String, dynamic>>[],
                'refs': <Map<String, dynamic>>[],
              },
              {
                'number': '198.1.',
                'id': '198-1',
                'depth': 1,
                'text':
                    'Une unité peut être déplacée d’un emplacement vers '
                    'un autre emplacement.',
                'examples': <Map<String, dynamic>>[],
                'refs': <Map<String, dynamic>>[],
              },
            ],
          },
        ],
      },
    ],
  },
  'tournament': {
    'key': 'tournament',
    'title': 'Règles de tournoi',
    'subtitle': 'Cadre officiel du jeu organisé',
    'updated': '16 juillet 2026',
    'source': 'https://exemple.test/tournament.pdf',
    'ruleCount': 1,
    'chapters': [
      {
        'number': '800.',
        'id': '800',
        'title': 'Cadre général',
        'sections': [
          {
            'number': '801.',
            'id': '801',
            'title': 'Arbitrage',
            'entries': [
              {
                'number': '802.',
                'id': '802',
                'depth': 0,
                'text': 'L’arbitre tranche les litiges de tournoi.',
                'examples': <Map<String, dynamic>>[],
                'refs': <Map<String, dynamic>>[],
              },
            ],
          },
        ],
      },
    ],
  },
};

/// Même document avec une autre date et un autre `ruleCount` : simule la
/// version publiée sur riftarium.re.
Map<String, dynamic> rulesFixtureUpdated({
  String updated = '20 août 2026',
  int ruleCount = 6,
}) {
  final copy = jsonDecode(jsonEncode(kRulesFixture)) as Map<String, dynamic>;
  final core = copy['core'] as Map<String, dynamic>;
  core['updated'] = updated;
  core['ruleCount'] = ruleCount;
  return copy;
}

String get kRulesFixtureSource => jsonEncode(kRulesFixture);
