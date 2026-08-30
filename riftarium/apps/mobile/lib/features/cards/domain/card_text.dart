/// Lecture du texte de règles d'une carte : miroir de `apps/web/src/cardText.js`.
///
/// Le texte renvoyé par l'API mêle du texte brut, des mots-clés entre crochets
/// (`[Action]`, `[Bouclier 2]`) et des glyphes officiels Riot notés `:rb_…:`
/// (`:rb_energy_3:`, `:rb_rune_fury:`, `:rb_might:`). On le découpe en morceaux
/// que l'écran sait peindre : texte courant, pastille de mot-clé, image SVG.
library;

/// Glyphes officiels Riot : les noms de fichiers reprennent exactement les
/// raccourcis `:rb_…:` du texte des cartes.
const String kGlyphBase =
    'https://assetcdn.rgpub.io/public/live/riot-shared/player-experiences/riot-glyphs/rb/latest';

String glyphUrl(String token) => '$kGlyphBase/$token.svg';

/// `:rb_xxx:` ou `[Mot-clé]`.
final RegExp _tokenPattern = RegExp(r':rb_([a-z0-9_]+):|\[([^\][]+)\]');

/// Chevron de séparation entre deux mots-clés (`[Action] [>] …`).
final RegExp _arrowPattern = RegExp(r'^>+$');

/// Le mot-clé peut porter une valeur (« Bouclier 2 ») : la famille se lit sur
/// le mot seul.
final RegExp _keywordValuePattern = RegExp(r'\s+\d+$');

const Map<String, String> _entities = {
  '&gt;': '>',
  '&lt;': '<',
  '&amp;': '&',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
  '&nbsp;': ' ',
};

final RegExp _entityPattern = RegExp(r'&(?:gt|lt|amp|quot|apos|nbsp|#39);');

/// Runes connues (les six domaines plus la rune libre).
const List<String> _runes = [
  'fury',
  'calm',
  'mind',
  'body',
  'chaos',
  'order',
  'rainbow',
];

const Map<String, String> kRuneLabels = {
  'fury': 'Rune de Fureur',
  'calm': 'Rune de Calme',
  'mind': 'Rune d’Esprit',
  'body': 'Rune de Corps',
  'chaos': 'Rune de Chaos',
  'order': 'Rune d’Ordre',
  'rainbow': 'Rune libre',
};

/// Rune correspondant à un domaine (`Fury` → `rune_fury`).
const Map<String, String> kDomainRune = {
  'Fury': 'fury',
  'Calm': 'calm',
  'Mind': 'mind',
  'Body': 'body',
  'Chaos': 'chaos',
  'Order': 'order',
  'Colorless': 'rainbow',
};

/// Famille d'un mot-clé : elle décide de la couleur de sa pastille, comme les
/// quatre teintes de `.rb-kw` sur le site.
enum KeywordFamily { timing, combat, state, utility }

const Map<KeywordFamily, List<String>> _keywordFamilies = {
  KeywordFamily.timing: [
    'action',
    'reaction',
    'accelerate',
    'hidden',
    'ambush',
    'flow',
    'quick-draw',
    'repeat',
  ],
  KeywordFamily.combat: ['assault', 'shield', 'tank', 'deflect', 'backline'],
  KeywordFamily.state: [
    'deathknell',
    'hunt',
    'level',
    'empowered',
    'ganking',
    'temporary',
    'legion',
  ],
  KeywordFamily.utility: [
    'vision',
    'empower',
    'weaponmaster',
    'equip',
    'buff',
    'stun',
    'mighty',
    'predict',
    'burn',
    'unique',
    'add',
  ],
};

final Map<String, KeywordFamily> _familyByKeyword = {
  for (final entry in _keywordFamilies.entries)
    for (final keyword in entry.value) keyword: entry.key,
};

/// Traductions rencontrées dans le texte français des cartes et des règles.
const Map<String, String> _frenchKeywords = {
  'accélération': 'accelerate',
  'réaction': 'reaction',
  'assaut': 'assault',
  'bouclier': 'shield',
  'arrière-ligne': 'backline',
  'protection': 'deflect',
  'caché': 'hidden',
  'embuscade': 'ambush',
  'agonie': 'deathknell',
  'temporaire': 'temporary',
  'légion': 'legion',
  'niveau': 'level',
  'chasse': 'hunt',
  'amplification': 'empower',
  'amplifié': 'empowered',
  'gank': 'ganking',
  'flux': 'flow',
  'répétition': 'repeat',
  'expert en armes': 'weaponmaster',
  'équiper': 'equip',
  'dégainer': 'quick-draw',
  'étourdissement': 'stun',
  'prédiction': 'predict',
  'brûler': 'burn',
  'ajout': 'add',
  'ajoutez': 'add',
  'unité puissante': 'mighty',
};

/// Nature d'un glyphe : elle décide de sa teinte à l'affichage.
enum GlyphKind {
  /// Puissance, épuisement : silhouette blanche à recolorer en encre.
  ink,

  /// Pastille d'énergie : Riot la sert claire, on l'inverse sur parchemin.
  energy,

  /// Rune de domaine : déjà colorée, laissée telle quelle.
  rune,
}

/// Un morceau de texte de carte.
sealed class CardTextPart {
  const CardTextPart();
}

/// Texte courant.
class CardTextRun extends CardTextPart {
  const CardTextRun(this.value);

  final String value;
}

/// Mot-clé de règles, rendu en pastille colorée.
class CardTextKeyword extends CardTextPart {
  CardTextKeyword({
    required this.label,
    required this.family,
    this.arrow = false,
  });

  final String label;
  final KeywordFamily family;

  /// Suivi d'un chevron (`[Action] [>]`) : la pastille pointe vers la suite.
  bool arrow;
}

/// Glyphe officiel, servi en SVG par le CDN Riot.
class CardTextGlyph extends CardTextPart {
  const CardTextGlyph({
    required this.token,
    required this.label,
    required this.kind,
  });

  final String token;
  final String label;
  final GlyphKind kind;

  String get url => glyphUrl(token);
}

/// Remplace les entités HTML laissées par l'import des cartes.
String decodeEntities(String text) => text.replaceAllMapped(
  _entityPattern,
  (match) => _entities[match.group(0)] ?? match.group(0)!,
);

/// Famille d'un mot-clé, français ou anglais, avec ou sans valeur.
KeywordFamily keywordFamily(String label) {
  final base = label.replaceAll(_keywordValuePattern, '').toLowerCase();
  return _familyByKeyword[_frenchKeywords[base] ?? base] ??
      KeywordFamily.utility;
}

/// Découpe le texte d'une carte en morceaux affichables.
/// Les données source collent parfois deux capacités sans espace
/// (`…Empowered.)[Empowered] …`, `showdowns.)This spell…`) : on rétablit le
/// saut de ligne que la carte imprimée montre. Une phrase suivie d'un espace
/// n'est pas touchée.
final RegExp _gluedAbility = RegExp(r'([.)])(?=\[[A-Z]|[A-Z])');

String _breakGluedAbilities(String source) =>
    source.replaceAllMapped(_gluedAbility, (match) => '${match[1]}\n');

List<CardTextPart> parseCardText(String? text) {
  if (text == null || text.isEmpty) return const [];
  final source = _breakGluedAbilities(decodeEntities(text));
  final parts = <CardTextPart>[];
  final pending = StringBuffer();

  void flush() {
    if (pending.isEmpty) return;
    parts.add(CardTextRun(pending.toString()));
    pending.clear();
  }

  var last = 0;
  for (final match in _tokenPattern.allMatches(source)) {
    if (match.start > last) pending.write(source.substring(last, match.start));
    last = match.end;

    final token = match.group(1);
    if (token != null) {
      final glyph = _glyphOf(token);
      if (glyph == null) {
        // Raccourci inconnu : on le laisse lisible plutôt que de l'effacer.
        pending.write(match.group(0)!);
      } else {
        flush();
        parts.add(glyph);
      }
      continue;
    }

    final label = match.group(2)!.trim();
    if (_arrowPattern.hasMatch(label)) {
      final previous = parts.isEmpty ? null : parts.last;
      if (pending.isEmpty && previous is CardTextKeyword) previous.arrow = true;
      continue;
    }
    // Marqueur d'import : la carte n'a pas de texte de règles.
    if (label.toUpperCase() == 'NO TEXT') continue;

    flush();
    parts.add(CardTextKeyword(label: label, family: keywordFamily(label)));
  }
  if (last < source.length) pending.write(source.substring(last));
  flush();
  return parts;
}

/// Runes du coût en pouvoir : autant de runes du premier domaine que de points.
List<CardTextGlyph> powerRunes(List<String> domains, int? power) {
  final count = power ?? 0;
  if (count < 1) return const [];
  final rune = kDomainRune[domains.isEmpty ? '' : domains.first] ?? 'rainbow';
  return List.generate(
    count,
    (_) => CardTextGlyph(
      token: 'rune_$rune',
      label: kRuneLabels[rune] ?? 'Rune',
      kind: GlyphKind.rune,
    ),
  );
}

CardTextGlyph? _glyphOf(String token) {
  if (token == 'might' || token == 'exhaust') {
    return CardTextGlyph(
      token: token,
      label: token == 'might' ? 'Puissance' : 'Épuisement',
      kind: GlyphKind.ink,
    );
  }
  if (token.startsWith('energy_')) {
    return CardTextGlyph(
      token: token,
      label: 'Énergie ${token.substring('energy_'.length)}',
      kind: GlyphKind.energy,
    );
  }
  if (token.startsWith('rune_')) {
    final domain = token.substring('rune_'.length);
    if (_runes.contains(domain)) {
      return CardTextGlyph(
        token: token,
        label: kRuneLabels[domain] ?? 'Rune',
        kind: GlyphKind.rune,
      );
    }
  }
  return null;
}
