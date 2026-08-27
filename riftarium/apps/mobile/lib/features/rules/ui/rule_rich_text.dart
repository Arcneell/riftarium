import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';

/// Texte de règle enrichi, comme `RuleText.vue` sur le site : **gras**,
/// mots-clés entre crochets rendus en pastilles colorées par famille, et
/// glyphes officiels (`:rb_…:`, ou leurs abréviations `[R]`, `[1]`, `[E]`).
///
/// Le même composant sert aux guides et au texte officiel : une règle se lit
/// partout de la même façon.

/// Glyphes officiels Riot (SVG). Mêmes noms de fichiers que les shortcodes.
const String kGlyphBase =
    'https://assetcdn.rgpub.io/public/live/riot-shared/'
    'player-experiences/riot-glyphs/rb/latest';

String glyphUrl(String token) => '$kGlyphBase/$token.svg';

/// Abréviations du texte officiel → shortcode complet.
const Map<String, String> kShortTokens = {
  'R': 'rune_fury',
  'G': 'rune_calm',
  'B': 'rune_mind',
  'O': 'rune_body',
  'P': 'rune_chaos',
  'Y': 'rune_order',
  'C': 'rune_rainbow',
  'E': 'exhaust',
  'M': 'might',
};

/// Shortcode → abréviation, pour le repli quand le SVG ne se charge pas.
final Map<String, String> _shortByToken = {
  for (final entry in kShortTokens.entries) entry.value: entry.key,
};

const Map<String, String> _runeLabels = {
  'fury': 'Rune de Fureur',
  'calm': 'Rune de Calme',
  'mind': 'Rune d’Esprit',
  'body': 'Rune de Corps',
  'chaos': 'Rune de Chaos',
  'order': 'Rune d’Ordre',
  'rainbow': 'Rune libre',
};

/// Familles de couleurs des mots-clés, relevées sur les cartes officielles.
const Map<String, List<String>> kKeywordFamilies = {
  'timing': [
    'action',
    'reaction',
    'accelerate',
    'hidden',
    'ambush',
    'flow',
    'quick-draw',
    'repeat',
  ],
  'combat': ['assault', 'shield', 'tank', 'deflect', 'backline'],
  'state': [
    'deathknell',
    'hunt',
    'level',
    'empowered',
    'ganking',
    'temporary',
    'legion',
  ],
  'utility': [
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

final Map<String, String> _familyByKeyword = {
  for (final entry in kKeywordFamilies.entries)
    for (final keyword in entry.value) keyword: entry.key,
};

/// Alias français des mots-clés (texte des règles et pages d'aide).
const Map<String, String> kKeywordsFr = {
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

/// Famille d'un mot-clé (« Assaut 2 » → combat), `utility` par défaut.
String keywordFamily(String label) {
  final base = label.replaceAll(RegExp(r'\s+\d+$'), '').toLowerCase();
  return _familyByKeyword[kKeywordsFr[base] ?? base] ?? 'utility';
}

/// Couleur de fond d'une pastille de mot-clé.
Color keywordColor(String family) => switch (family) {
  'timing' => const Color(0xFF24705F),
  'combat' => const Color(0xFFCC356E),
  'state' => const Color(0xFF7A9420),
  _ => const Color(0xFF6C6D6C),
};

/// Nature d'un morceau de texte enrichi.
enum RulePartKind { text, keyword, glyph }

/// Un morceau : du texte, une pastille de mot-clé ou un glyphe.
class RulePart {
  const RulePart({
    required this.kind,
    required this.value,
    this.bold = false,
    this.family = '',
    this.arrow = false,
    this.token = '',
    this.label = '',
    this.ink = false,
  });

  final RulePartKind kind;

  /// Texte littéral, libellé du mot-clé, ou repli du glyphe (« [R] »).
  final String value;
  final bool bold;

  /// Famille du mot-clé (timing, combat, state, utility).
  final String family;

  /// Mot-clé suivi de `[>]` : la pastille se termine en pointe.
  final bool arrow;

  /// Shortcode du glyphe (`rune_fury`, `energy_3`, `might`).
  final String token;

  /// Libellé accessible du glyphe.
  final String label;

  /// Glyphe monochrome (puissance, épuisement) : teinté à la couleur du texte.
  final bool ink;
}

final RegExp _shortTokenPattern = RegExp(r'\[([RGBOPYCEM]|\d{1,2})\]');
final RegExp _tokenPattern = RegExp(r':rb_([a-z0-9_]+):|\[([^\[\]]+)\]');
final RegExp _digit = RegExp(r'^\d');

const List<String> _runes = [
  'fury',
  'calm',
  'mind',
  'body',
  'chaos',
  'order',
  'rainbow',
];

String _expandShortTokens(String text) =>
    text.replaceAllMapped(_shortTokenPattern, (match) {
      final token = match[1]!;
      if (_digit.hasMatch(token)) return ':rb_energy_$token:';
      return ':rb_${kShortTokens[token]}:';
    });

/// Découpe un texte de règle en morceaux affichables.
List<RulePart> parseRuleText(String text) {
  if (text.isEmpty) return const [];
  final parts = <RulePart>[];
  final chunks = _expandShortTokens(text).split('**');
  for (var index = 0; index < chunks.length; index++) {
    _parseChunk(parts, chunks[index], bold: index.isOdd);
  }
  return parts;
}

void _parseChunk(List<RulePart> parts, String chunk, {required bool bold}) {
  if (chunk.isEmpty) return;
  var last = 0;
  for (final match in _tokenPattern.allMatches(chunk)) {
    if (match.start > last) {
      _pushText(parts, chunk.substring(last, match.start), bold: bold);
    }
    last = match.end;
    final glyph = match[1];
    if (glyph != null) {
      _pushGlyph(parts, glyph, match[0]!, bold: bold);
    } else {
      _pushBracket(parts, match[2]!.trim(), match[0]!, bold: bold);
    }
  }
  if (last < chunk.length) {
    _pushText(parts, chunk.substring(last), bold: bold);
  }
}

void _pushText(List<RulePart> parts, String value, {required bool bold}) {
  if (value.isEmpty) return;
  final previous = parts.isEmpty ? null : parts.last;
  if (previous != null &&
      previous.kind == RulePartKind.text &&
      previous.bold == bold) {
    parts[parts.length - 1] = RulePart(
      kind: RulePartKind.text,
      value: previous.value + value,
      bold: bold,
    );
    return;
  }
  parts.add(RulePart(kind: RulePartKind.text, value: value, bold: bold));
}

void _pushGlyph(
  List<RulePart> parts,
  String token,
  String raw, {
  required bool bold,
}) {
  if (token == 'might' || token == 'exhaust') {
    parts.add(
      RulePart(
        kind: RulePartKind.glyph,
        value: '[${_shortByToken[token]}]',
        bold: bold,
        token: token,
        label: token == 'might' ? 'Puissance' : 'Épuisement',
        ink: true,
      ),
    );
    return;
  }
  if (token.startsWith('energy_')) {
    final amount = token.substring('energy_'.length);
    parts.add(
      RulePart(
        kind: RulePartKind.glyph,
        value: '[$amount]',
        bold: bold,
        token: token,
        label: 'Énergie $amount',
      ),
    );
    return;
  }
  if (token.startsWith('rune_')) {
    final domain = token.substring('rune_'.length);
    if (_runes.contains(domain)) {
      parts.add(
        RulePart(
          kind: RulePartKind.glyph,
          value: '[${_shortByToken[token] ?? '·'}]',
          bold: bold,
          token: token,
          label: _runeLabels[domain] ?? 'Rune',
        ),
      );
      return;
    }
  }
  _pushText(parts, raw, bold: bold);
}

void _pushBracket(
  List<RulePart> parts,
  String label,
  String raw, {
  required bool bold,
}) {
  if (RegExp(r'^>+$').hasMatch(label)) {
    final previous = parts.isEmpty ? null : parts.last;
    if (previous != null && previous.kind == RulePartKind.keyword) {
      parts[parts.length - 1] = RulePart(
        kind: RulePartKind.keyword,
        value: previous.value,
        bold: previous.bold,
        family: previous.family,
        arrow: true,
      );
    }
    return;
  }
  if (label.toUpperCase() == 'NO TEXT') return;
  parts.add(
    RulePart(
      kind: RulePartKind.keyword,
      value: label,
      bold: bold,
      family: keywordFamily(label),
    ),
  );
}

/// Morceaux d'un texte de règle, transformés en `InlineSpan`.
List<InlineSpan> ruleTextSpans(
  BuildContext context,
  String text, {
  TextStyle? style,
}) {
  final base = style ?? riftText(context).body;
  final strong = base.copyWith(fontVariations: RiftFonts.weight(700));
  return [
    for (final part in parseRuleText(text))
      switch (part.kind) {
        RulePartKind.text => TextSpan(
          text: part.value,
          style: part.bold ? strong : base,
        ),
        RulePartKind.keyword => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _KeywordChip(part: part, fontSize: base.fontSize ?? 15.5),
        ),
        RulePartKind.glyph => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _Glyph(
            part: part,
            size: (base.fontSize ?? 15.5) + 1.5,
            style: part.bold ? strong : base,
          ),
        ),
      },
  ];
}

/// Texte de règle enrichi.
class RuleRichText extends StatelessWidget {
  const RuleRichText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? riftText(context).body;
    return Text.rich(
      TextSpan(children: ruleTextSpans(context, text, style: base)),
      style: base,
      textAlign: textAlign,
    );
  }
}

/// Pastille d'un mot-clé : capitales italiques blanches sur fond de famille.
class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.part, required this.fontSize});

  final RulePart part;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = keywordColor(part.family);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        padding: EdgeInsets.fromLTRB(6, 1, part.arrow ? 11 : 6, 1.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          part.value.toUpperCase(),
          style: TextStyle(
            fontFamily: RiftFonts.body,
            fontVariations: RiftFonts.weight(700),
            fontStyle: FontStyle.italic,
            fontSize: fontSize * 0.78,
            height: 1.2,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Glyphe officiel : SVG chargé depuis le CDN Riot, repli sur l'abréviation
/// du texte officiel (« [R] ») quand le réseau manque.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.part, required this.size, required this.style});

  final RulePart part;
  final double size;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(part.value, style: style);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        label: part.label,
        child: SvgPicture.network(
          glyphUrl(part.token),
          width: size,
          height: size,
          colorFilter: part.ink
              ? ColorFilter.mode(
                  style.color ?? riftText(context).ink,
                  BlendMode.srcIn,
                )
              : null,
          placeholderBuilder: (context) => SizedBox(
            width: size,
            height: size,
            child: FittedBox(child: fallback),
          ),
          errorBuilder: (context, error, stack) => fallback,
        ),
      ),
    );
  }
}
