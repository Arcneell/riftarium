import 'dart:convert';

/// Guides réduits : même forme que `assets/rules/guides-fr.json`, avec deux
/// familles, trois sujets (dont un avec démo et cartes d'exemple) et trois
/// étapes de guide. Les visuels sont vides : aucun test ne touche au réseau.
const Map<String, dynamic> kGuidesFixture = {
  'categories': [
    {'key': 'tour', 'label': 'Tour & timing'},
    {'key': 'combat', 'label': 'Combat'},
  ],
  'topics': [
    {
      'slug': 'deroulement-du-tour',
      'title': 'Le déroulement du tour',
      'category': 'tour',
      'summary': 'Éveil, scores, canalisation, pioche : l’ordre exact.',
      'details': [
        'Chaque tour commence par la **phase d’éveil** : vous redressez '
            'toutes vos unités.',
        'Une unité épuisée ne se redresse qu’à l’éveil suivant.',
      ],
      'cases': [
        {
          'q': 'Quand marque-t-on les points d’occupation ?',
          'a': 'À l’étape des scores, avant la pioche.',
        },
        {
          'q': 'Puis-je jouer une carte pendant l’éveil ?',
          'a': 'Non, la phase est automatique.',
        },
      ],
      'sections': ['197'],
    },
    {
      'slug': 'la-chaine',
      'title': 'La chaîne',
      'category': 'tour',
      'summary': 'Dernier entré, premier résolu.',
      'details': [
        'Un sort joué entre dans la **chaîne** : il ne se résout pas tout '
            'de suite.',
      ],
      'cases': [
        {'q': 'Qui répond en premier ?', 'a': 'L’adversaire, puis vous.'},
      ],
      'sections': ['001'],
      'demo': {
        'title': 'Empiler puis dépiler',
        'frames': [
          {
            'caption': 'Vous jouez un sort.',
            'items': [
              {'k': 'z', 'type': 'zone', 'x': 50, 'y': 50, 'label': 'Chaîne'},
              {
                'k': 'a',
                'type': 'card',
                'x': 50,
                'y': 62,
                'label': 'Votre sort',
              },
            ],
          },
          {
            'caption': 'L’adversaire répond.',
            'items': [
              {'k': 'z', 'type': 'zone', 'x': 50, 'y': 50, 'label': 'Chaîne'},
              {
                'k': 'b',
                'type': 'unit',
                'side': 'foe',
                'x': 50,
                'y': 34,
                'n': 3,
              },
            ],
          },
        ],
      },
      'examples': [
        {'id': 'ogn-008-298', 'name': 'Get Excited!', 'img': ''},
      ],
    },
    {
      'slug': 'etapes-du-combat',
      'title': 'Les étapes du combat',
      'category': 'combat',
      'summary': 'Focalisation, dégâts, conquête.',
      'details': [
        'Une **unité** qui attaque focalise une cible.',
        'Le mot-clé [Réaction] permet de répondre pendant le combat.',
      ],
      'cases': [
        {'q': 'Qui choisit la cible ?', 'a': 'L’attaquant, puis le défenseur.'},
      ],
      'sections': ['001'],
    },
  ],
  'guide': {
    'steps': [
      {
        'key': 'materiel',
        'title': 'Ce qu’il faut pour jouer',
        'ref': '197',
        'terms': ['deck principal', 'deck de runes'],
        'text': [
          'Quatre éléments : un **deck principal**, un deck de runes, une '
              'légende et trois champs de bataille.',
        ],
        'scene': {
          'bare': true,
          'score': {'you': 0, 'foe': 0},
          'cards': [
            {
              'key': 'legend',
              'card': {'id': 'ogn-251-298', 'name': 'Jinx', 'img': ''},
              'spot': {'x': 30, 'y': 42, 'r': -8},
              'glow': true,
            },
          ],
        },
      },
      {
        'key': 'mise-en-place',
        'title': 'La mise en place',
        'ref': '001',
        'terms': ['champ de bataille'],
        'text': ['Chacun présente sa **légende** et son champion élu.'],
        'scene': {
          'foeHand': 2,
          'score': {'you': 0, 'foe': 0},
          'control': {'bfFoe': 'you'},
          'arrow': {
            'from': {'x': 92, 'y': 54},
            'to': {'x': 85, 'y': 87},
          },
          'cards': [
            {
              'key': 'legend',
              'card': {'id': 'ogn-251-298', 'name': 'Jinx', 'img': ''},
              'spot': {'x': 8, 'y': 61},
              'label': 'Légende',
            },
            {
              'key': 'mainDeck',
              'card': {'id': 'ogn-008-298', 'name': 'Deck', 'img': ''},
              'spot': {'x': 92, 'y': 61},
              'facedown': true,
              'label': 'Deck principal',
            },
          ],
        },
      },
      {
        'key': 'victoire',
        'title': 'Gagner la partie',
        'ref': '801',
        'terms': ['points'],
        'text': ['Le premier joueur à **8 points** gagne.'],
        'scene': {
          'score': {'you': 8, 'foe': 4},
          'scorePulse': true,
          'contested': ['bfFoe'],
          'clash': true,
          'chips': {'energy': 2, 'essence': 1},
          'focus': {
            'card': {'id': 'ogn-030-298', 'name': 'Jinx - Demo', 'img': ''},
            'notes': [
              {'n': 1, 'x': 12, 'y': 8.5},
              {'n': 2, 'x': 88, 'y': 20},
            ],
          },
          'cards': [
            {
              'key': 'chosen',
              'card': {
                'id': 'ogn-202-298',
                'name': 'Jinx - Rebel',
                'might': 5,
                'img': '',
              },
              'spot': {'x': 61, 'y': 47},
              'might': true,
              'dmg': 2,
            },
          ],
        },
      },
    ],
    'cards': {
      'bfYou': {'id': 'ogn-277-298', 'name': 'Votre champ', 'img': ''},
      'bfFoe': {'id': 'ogn-278-298', 'name': 'Champ adverse', 'img': ''},
    },
    'spots': {
      'bfFoe': {'x': 39, 'y': 44},
      'bfYou': {'x': 61, 'y': 44},
      'discard': {'x': 92, 'y': 79},
      'foeDiscard': {'x': 8, 'y': 8},
    },
  },
};

String get kGuidesFixtureSource => jsonEncode(kGuidesFixture);
