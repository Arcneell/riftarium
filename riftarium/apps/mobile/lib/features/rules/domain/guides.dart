import 'dart:convert';

import 'rules.dart';

/// Modèles des guides (`assets/rules/guides-fr.json`), export de
/// `apps/web/src/rules/topics.js` et `guide.js`.
///
/// Deux contenus dans un seul fichier :
/// - `topics` : les mécaniques de l'aide avancée (essentiel, cas concrets,
///   démonstration animée, cartes d'exemple, renvois vers le texte officiel) ;
/// - `guide` : le pas à pas du débutant (17 étapes sur un plateau).

String _string(Object? value) => value is String ? value : '';

/// Les valeurs numériques des scènes arrivent en nombre ou en texte
/// (« 3 » côté unités, « −4 » côté jetons) : tout se lit comme du texte.
String _text(Object? value) => switch (value) {
  String value => value,
  num value =>
    value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString(),
  _ => '',
};

double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

double? _optionalNumber(Object? value) => (value as num?)?.toDouble();

bool _flag(Object? value) => value == true;

List<String> _strings(Object? value) => [
  for (final item in (value as List? ?? const []))
    if (item is String) item,
];

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .toList(growable: false);

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// Famille de mécaniques : « Tour & timing », « Combat »…
class GuideCategory {
  const GuideCategory({required this.key, required this.label});

  factory GuideCategory.fromJson(Map<String, dynamic> json) =>
      GuideCategory(key: _string(json['key']), label: _string(json['label']));

  final String key;
  final String label;
}

/// Cas concret : une question de table et sa réponse.
class TopicCase {
  const TopicCase({required this.question, required this.answer});

  factory TopicCase.fromJson(Map<String, dynamic> json) =>
      TopicCase(question: _string(json['q']), answer: _string(json['a']));

  final String question;
  final String answer;
}

/// Visuel de carte officiel (guide et cartes d'exemple).
class GuideCard {
  const GuideCard({
    required this.id,
    required this.name,
    required this.image,
    this.might,
  });

  factory GuideCard.fromJson(Map<String, dynamic> json) => GuideCard(
    id: _string(json['id']),
    name: _string(json['name']),
    image: _string(json['img']),
    might: (json['might'] as num?)?.toInt(),
  );

  final String id;
  final String name;

  /// URL du CDN Riot, déjà dimensionnée (`w=360` ou `w=560`).
  final String image;
  final int? might;
}

/// Type d'élément d'une image de démonstration.
enum DemoItemType { zone, card, unit, chip, label, unknown }

DemoItemType _demoItemType(String value) => switch (value) {
  'zone' => DemoItemType.zone,
  'card' => DemoItemType.card,
  'unit' => DemoItemType.unit,
  'chip' => DemoItemType.chip,
  'label' => DemoItemType.label,
  _ => DemoItemType.unknown,
};

/// Élément posé sur la mini-scène d'une démonstration, en pourcentage.
class DemoItem {
  const DemoItem({
    required this.key,
    required this.type,
    required this.x,
    required this.y,
    this.label = '',
    this.value = '',
    this.side = '',
    this.glow = false,
    this.dead = false,
    this.hot = false,
    this.ok = false,
    this.tapped = false,
  });

  factory DemoItem.fromJson(Map<String, dynamic> json) => DemoItem(
    key: _string(json['k']),
    type: _demoItemType(_string(json['type'])),
    x: _number(json['x']),
    y: _number(json['y']),
    label: _string(json['label']),
    value: _text(json['n']),
    side: _string(json['side']),
    glow: _flag(json['glow']),
    dead: _flag(json['dead']),
    hot: _flag(json['hot']),
    ok: _flag(json['ok']),
    tapped: _flag(json['tapped']),
  );

  final String key;
  final DemoItemType type;
  final double x;
  final double y;
  final String label;

  /// Puissance d'une unité, texte d'un jeton (« −4 », « 3 restants »).
  final String value;

  /// « foe » pour l'adversaire, vide pour le joueur.
  final String side;
  final bool glow;
  final bool dead;
  final bool hot;
  final bool ok;
  final bool tapped;

  bool get isFoe => side == 'foe';
}

/// Une image de la démonstration : sa légende et ses éléments.
class DemoFrame {
  const DemoFrame({required this.caption, required this.items});

  factory DemoFrame.fromJson(Map<String, dynamic> json) => DemoFrame(
    caption: _string(json['caption']),
    items: _maps(json['items']).map(DemoItem.fromJson).toList(growable: false),
  );

  final String caption;
  final List<DemoItem> items;
}

/// Suite d'images qui montre une mécanique en mouvement.
class TopicDemo {
  const TopicDemo({required this.title, required this.frames});

  factory TopicDemo.fromJson(Map<String, dynamic> json) => TopicDemo(
    title: _string(json['title']),
    frames: _maps(
      json['frames'],
    ).map(DemoFrame.fromJson).toList(growable: false),
  );

  final String title;
  final List<DemoFrame> frames;
}

/// Une mécanique de l'aide avancée.
class GuideTopic {
  GuideTopic({
    required this.slug,
    required this.title,
    required this.category,
    required this.summary,
    required this.details,
    required this.cases,
    required this.sections,
    this.demo,
    this.examples = const [],
    this.chips = const [],
  });

  factory GuideTopic.fromJson(Map<String, dynamic> json) => GuideTopic(
    slug: _string(json['slug']),
    title: _string(json['title']),
    category: _string(json['category']),
    summary: _string(json['summary']),
    details: _strings(json['details']),
    cases: _maps(json['cases']).map(TopicCase.fromJson).toList(growable: false),
    sections: _strings(json['sections']),
    demo: json['demo'] is Map<String, dynamic>
        ? TopicDemo.fromJson(json['demo'] as Map<String, dynamic>)
        : null,
    examples: _maps(
      json['examples'],
    ).map(GuideCard.fromJson).toList(growable: false),
    chips: _strings(json['chips']),
  );

  final String slug;
  final String title;
  final String category;
  final String summary;

  /// « L'essentiel » : quelques paragraphes en texte enrichi.
  final List<String> details;
  final List<TopicCase> cases;

  /// Identifiants des sections officielles à reproduire (`301`, `315`…).
  final List<String> sections;
  final TopicDemo? demo;
  final List<GuideCard> examples;

  /// Mots-clés affichés en pastille dans l'en-tête (catégorie « mots-clés »).
  final List<String> chips;

  /// Texte replié pour la recherche : titre, résumé, essentiel et cas.
  late final String haystack = foldForSearch(
    [
      title,
      summary,
      ...details,
      for (final item in cases) '${item.question} ${item.answer}',
    ].join(' '),
  );
}

/// Point d'une scène, en pourcentage du plateau, avec sa rotation.
class GuideSpot {
  const GuideSpot({required this.x, required this.y, this.rotation});

  factory GuideSpot.fromJson(Map<String, dynamic> json) => GuideSpot(
    x: _number(json['x']),
    y: _number(json['y']),
    rotation: _optionalNumber(json['r']),
  );

  final double x;
  final double y;

  /// Inclinaison en degrés (cartes posées de travers).
  final double? rotation;
}

/// Carte posée sur le plateau du guide.
class PlacedCard {
  const PlacedCard({
    required this.key,
    required this.card,
    required this.spot,
    this.label = '',
    this.facedown = false,
    this.glow = false,
    this.wide = false,
    this.tapped = false,
    this.showMight = false,
    this.damage = '',
    this.dead = false,
    this.ghost = false,
    this.inHand = false,
  });

  factory PlacedCard.fromJson(Map<String, dynamic> json) => PlacedCard(
    key: _string(json['key']),
    card: GuideCard.fromJson(_map(json['card'])),
    spot: GuideSpot.fromJson(_map(json['spot'])),
    label: _string(json['label']),
    facedown: _flag(json['facedown']),
    glow: _flag(json['glow']),
    wide: _flag(json['wide']),
    tapped: _flag(json['tapped']),
    showMight: _flag(json['might']),
    damage: _text(json['dmg']),
    dead: _flag(json['dead']),
    ghost: _flag(json['ghost']),
    inHand: _flag(json['hand']),
  );

  final String key;
  final GuideCard card;
  final GuideSpot spot;
  final String label;
  final bool facedown;
  final bool glow;

  /// Champ de bataille : format paysage.
  final bool wide;
  final bool tapped;
  final bool showMight;

  /// Dégâts marqués sur l'unité (« 3 »).
  final String damage;
  final bool dead;
  final bool ghost;
  final bool inHand;
}

/// Flèche courbe entre deux points de la scène (pioche, déplacement).
class SceneArrow {
  const SceneArrow({required this.from, required this.to});

  factory SceneArrow.fromJson(Map<String, dynamic> json) => SceneArrow(
    from: GuideSpot.fromJson(_map(json['from'])),
    to: GuideSpot.fromJson(_map(json['to'])),
  );

  final GuideSpot from;
  final GuideSpot to;
}

/// Pastille numérotée posée sur le gros plan d'une carte.
class FocusNote {
  const FocusNote({required this.number, required this.x, required this.y});

  factory FocusNote.fromJson(Map<String, dynamic> json) => FocusNote(
    number: _text(json['n']),
    x: _number(json['x']),
    y: _number(json['y']),
  );

  final String number;
  final double x;
  final double y;
}

/// Gros plan annoté : « voici comment se lit une carte ».
class SceneFocus {
  const SceneFocus({required this.card, required this.notes});

  factory SceneFocus.fromJson(Map<String, dynamic> json) => SceneFocus(
    card: GuideCard.fromJson(_map(json['card'])),
    notes: _maps(json['notes']).map(FocusNote.fromJson).toList(growable: false),
  );

  final GuideCard card;
  final List<FocusNote> notes;
}

/// Réserve runique : jetons d'énergie et d'essence.
class SceneChips {
  const SceneChips({required this.energy, required this.essence});

  factory SceneChips.fromJson(Map<String, dynamic> json) => SceneChips(
    energy: (json['energy'] as num?)?.toInt() ?? 0,
    essence: (json['essence'] as num?)?.toInt() ?? 0,
  );

  final int energy;
  final int essence;

  bool get isEmpty => energy == 0 && essence == 0;
}

/// État du plateau à une étape : cartes posées, contrôle, score, flèche…
class GuideScene {
  const GuideScene({
    required this.cards,
    this.bare = false,
    this.scoreYou = 0,
    this.scoreFoe = 0,
    this.scorePulse = false,
    this.foeHand = 0,
    this.control = const {},
    this.contested = const [],
    this.clash = false,
    this.arrow,
    this.focus,
    this.chips,
  });

  factory GuideScene.fromJson(Map<String, dynamic> json) {
    final score = _map(json['score']);
    return GuideScene(
      cards: _maps(
        json['cards'],
      ).map(PlacedCard.fromJson).toList(growable: false),
      bare: _flag(json['bare']),
      scoreYou: (score['you'] as num?)?.toInt() ?? 0,
      scoreFoe: (score['foe'] as num?)?.toInt() ?? 0,
      scorePulse: _flag(json['scorePulse']),
      foeHand: (json['foeHand'] as num?)?.toInt() ?? 0,
      control: {
        for (final entry in _map(json['control']).entries)
          entry.key: _string(entry.value),
      },
      contested: _strings(json['contested']),
      clash: _flag(json['clash']),
      arrow: json['arrow'] is Map<String, dynamic>
          ? SceneArrow.fromJson(json['arrow'] as Map<String, dynamic>)
          : null,
      focus: json['focus'] is Map<String, dynamic>
          ? SceneFocus.fromJson(json['focus'] as Map<String, dynamic>)
          : null,
      chips: json['chips'] is Map<String, dynamic>
          ? SceneChips.fromJson(json['chips'] as Map<String, dynamic>)
          : null,
    );
  }

  final List<PlacedCard> cards;

  /// Étape de présentation : les zones du plateau ne sont pas dessinées.
  final bool bare;
  final int scoreYou;
  final int scoreFoe;
  final bool scorePulse;

  /// Nombre de dos de cartes dans la main adverse.
  final int foeHand;

  /// Champ de bataille → « you » ou « foe ».
  final Map<String, String> control;
  final List<String> contested;
  final bool clash;
  final SceneArrow? arrow;
  final SceneFocus? focus;
  final SceneChips? chips;

  String? controllerOf(String battlefield) => control[battlefield];

  bool isContested(String battlefield) => contested.contains(battlefield);
}

/// Une étape du guide du débutant.
class GuideStep {
  const GuideStep({
    required this.key,
    required this.title,
    required this.reference,
    required this.terms,
    required this.text,
    required this.scene,
  });

  factory GuideStep.fromJson(Map<String, dynamic> json) => GuideStep(
    key: _string(json['key']),
    title: _string(json['title']),
    reference: _string(json['ref']),
    terms: _strings(json['terms']),
    text: _strings(json['text']),
    scene: GuideScene.fromJson(_map(json['scene'])),
  );

  final String key;
  final String title;

  /// Numéro de la section officielle correspondante (« 315 »).
  final String reference;

  /// Termes de jeu introduits par l'étape, affichés en pastilles mono.
  final List<String> terms;
  final List<String> text;
  final GuideScene scene;
}

/// Le fichier des guides, une fois décodé.
class GuidesDocument {
  GuidesDocument({
    required this.categories,
    required this.topics,
    required this.steps,
    required this.boardCards,
    required this.spots,
  });

  factory GuidesDocument.fromJson(Map<String, dynamic> json) {
    final guide = _map(json['guide']);
    return GuidesDocument(
      categories: _maps(
        json['categories'],
      ).map(GuideCategory.fromJson).toList(growable: false),
      topics: _maps(
        json['topics'],
      ).map(GuideTopic.fromJson).toList(growable: false),
      steps: _maps(
        guide['steps'],
      ).map(GuideStep.fromJson).toList(growable: false),
      boardCards: {
        for (final entry in _map(guide['cards']).entries)
          entry.key: GuideCard.fromJson(_map(entry.value)),
      },
      spots: {
        for (final entry in _map(guide['spots']).entries)
          entry.key: GuideSpot.fromJson(_map(entry.value)),
      },
    );
  }

  final List<GuideCategory> categories;
  final List<GuideTopic> topics;
  final List<GuideStep> steps;

  /// Visuels réutilisés d'une étape à l'autre (champs de bataille, légendes).
  final Map<String, GuideCard> boardCards;

  /// Emplacements fixes du plateau (défausse, zone de runes, champs).
  final Map<String, GuideSpot> spots;

  late final Map<String, GuideTopic> _bySlug = {
    for (final topic in topics) topic.slug: topic,
  };

  GuideTopic? topicBySlug(String slug) => _bySlug[slug];

  String categoryLabel(String key) {
    for (final category in categories) {
      if (category.key == key) return category.label;
    }
    return '';
  }

  List<GuideTopic> topicsOf(String categoryKey) => [
    for (final topic in topics)
      if (topic.category == categoryKey) topic,
  ];

  /// Sujet suivant : le voisin de la même catégorie, sinon le suivant de la
  /// liste. Renvoie null pour le dernier sujet du fichier.
  GuideTopic? topicAfter(String slug) {
    final index = topics.indexWhere((topic) => topic.slug == slug);
    if (index < 0 || index + 1 >= topics.length) return null;
    return topics[index + 1];
  }
}

/// Longueur minimale d'une recherche dans les guides.
const int kGuideSearchMinLength = 2;

/// Recherche dans les sujets : tous les mots doivent être présents (ET),
/// sans tenir compte de la casse ni des accents. Un mot du titre pèse plus
/// qu'un mot perdu dans un cas concret.
List<GuideTopic> searchGuideTopics(
  GuidesDocument document,
  String query, {
  int limit = 40,
}) {
  final trimmed = query.trim();
  if (trimmed.length < kGuideSearchMinLength) return const [];
  final tokens = foldForSearch(trimmed)
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return const [];

  final scored = <({GuideTopic topic, int score, int order})>[];
  var order = 0;
  for (final topic in document.topics) {
    final title = foldForSearch(topic.title);
    var score = 0;
    var matchesAll = true;
    for (final token in tokens) {
      if (!topic.haystack.contains(token)) {
        matchesAll = false;
        break;
      }
      if (title.contains(token)) score += 10;
      score += 1;
    }
    if (!matchesAll) continue;
    scored.add((topic: topic, score: score, order: order));
    order++;
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return [for (final item in scored.take(limit)) item.topic];
}

/// Décode le fichier des guides. Fonction de premier niveau : appelée dans
/// une isolate via `compute` (175 Ko).
GuidesDocument parseGuidesDocument(String source) =>
    GuidesDocument.fromJson(jsonDecode(source) as Map<String, dynamic>);
