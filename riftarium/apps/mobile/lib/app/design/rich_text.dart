import 'package:flutter/material.dart';

import '../theme.dart';
import 'glyphs.dart';

/// Texte enrichi Riftarium : le rendu du texte des cartes (`CardText.vue`) et
/// celui des règles (`RuleText.vue`) sont le même — un seul parseur, un seul
/// widget, pour que la même phrase se lise partout de la même façon.
///
/// Le texte mêle du texte brut, du **gras** markdown (guides et règles), des
/// mots-clés entre crochets (`[Action]`, `[Bouclier 2]`) rendus en pastille
/// colorée par famille, et des glyphes officiels notés `:rb_…:` ou par leurs
/// abréviations du texte officiel (`[R]`, `[1]`, `[E]`).

/// Famille d'un mot-clé : elle décide de la couleur de sa pastille, comme les
/// quatre teintes de `.rb-kw` sur le site.
enum KeywordFamily { timing, combat, state, utility }

/// Familles relevées sur les cartes officielles.
const Map<KeywordFamily, List<String>> kKeywordFamilies = {
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
  for (final entry in kKeywordFamilies.entries)
    for (final keyword in entry.value) keyword: entry.key,
};

/// Alias français des mots-clés (texte des cartes, règles, pages d'aide).
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

/// Le mot-clé peut porter une valeur (« Bouclier 2 ») : la famille se lit sur
/// le mot seul.
final RegExp _keywordValuePattern = RegExp(r'\s+\d+$');

/// Famille d'un mot-clé, français ou anglais, avec ou sans valeur.
KeywordFamily keywordFamily(String label) {
  final base = label.replaceAll(_keywordValuePattern, '').toLowerCase();
  return _familyByKeyword[kKeywordsFr[base] ?? base] ?? KeywordFamily.utility;
}

/// Couleur de fond d'une pastille de mot-clé : les valeurs de
/// `.rb-kw.timing/.combat/.state/.utility` du site.
Color keywordColor(KeywordFamily family) => switch (family) {
  KeywordFamily.timing => const Color(0xFF24705F),
  KeywordFamily.combat => const Color(0xFFCC356E),
  KeywordFamily.state => const Color(0xFF94B42A),
  KeywordFamily.utility => const Color(0xFF6C6D6C),
};

/// Un morceau de texte enrichi.
sealed class RiftTextPart {
  const RiftTextPart({this.bold = false});

  /// Morceau pris dans un `**gras**` (règles et guides).
  final bool bold;
}

/// Texte courant.
final class RiftTextRun extends RiftTextPart {
  const RiftTextRun(this.value, {super.bold});

  final String value;
}

/// Mot-clé de règles, rendu en pastille colorée.
final class RiftTextKeyword extends RiftTextPart {
  RiftTextKeyword({
    required this.label,
    required this.family,
    super.bold,
    this.arrow = false,
  });

  final String label;
  final KeywordFamily family;

  /// Suivi d'un chevron (`[Action] [>]`) : la pastille pointe vers la suite.
  bool arrow;
}

/// Glyphe officiel, servi en SVG par le CDN Riot.
final class RiftTextGlyph extends RiftTextPart {
  const RiftTextGlyph(this.glyph, {super.bold});

  final RiftGlyphSpec glyph;
}

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

/// Remplace les entités HTML laissées par l'import des cartes.
String decodeEntities(String text) => text.replaceAllMapped(
  _entityPattern,
  (match) => _entities[match.group(0)] ?? match.group(0)!,
);

/// `:rb_xxx:` ou `[Mot-clé]`.
final RegExp _tokenPattern = RegExp(r':rb_([a-z0-9_]+):|\[([^\][]+)\]');

/// Chevron de séparation entre deux mots-clés (`[Action] [>] …`).
final RegExp _arrowPattern = RegExp(r'^>+$');

/// Abréviations du texte officiel : `[R]` (rune), `[1]` (énergie), `[E]`.
final RegExp _shortTokenPattern = RegExp(r'\[([RGBOPYCEM]|\d{1,2})\]');
final RegExp _digit = RegExp(r'^\d');

String _expandShortTokens(String text) =>
    text.replaceAllMapped(_shortTokenPattern, (match) {
      final token = match[1]!;
      if (_digit.hasMatch(token)) return ':rb_energy_$token:';
      return ':rb_${kShortTokens[token]}:';
    });

/// Les données source collent parfois deux capacités sans espace
/// (`…Empowered.)[Empowered] …`, `showdowns.)This spell…`) : on rétablit le
/// saut de ligne que la carte imprimée montre. Une phrase suivie d'un espace
/// n'est pas touchée.
final RegExp _gluedAbility = RegExp(r'([.)])(?=\[[A-Z]|[A-Z])');

/// Découpe un texte enrichi en morceaux affichables.
///
/// - [markdownBold] : `**gras**` (règles, guides ; le texte des cartes n'en a
///   pas et pourrait contenir des astérisques littéraux).
/// - [shortTokens] : abréviations `[R] [1] [E]` du texte officiel, à ne pas
///   confondre avec un mot-clé entre crochets sur une carte.
/// - [breakGluedAbilities] : capacités collées du texte des cartes.
List<RiftTextPart> parseRiftText(
  String? text, {
  bool markdownBold = false,
  bool shortTokens = false,
  bool breakGluedAbilities = false,
}) {
  if (text == null || text.isEmpty) return const [];
  var source = decodeEntities(text);
  if (breakGluedAbilities) {
    source = source.replaceAllMapped(_gluedAbility, (m) => '${m[1]}\n');
  }
  if (shortTokens) source = _expandShortTokens(source);

  final parts = <RiftTextPart>[];
  if (!markdownBold) {
    _parseChunk(parts, source, bold: false);
    return parts;
  }
  final chunks = source.split('**');
  for (var index = 0; index < chunks.length; index++) {
    _parseChunk(parts, chunks[index], bold: index.isOdd);
  }
  return parts;
}

void _parseChunk(List<RiftTextPart> parts, String chunk, {required bool bold}) {
  if (chunk.isEmpty) return;
  final pending = StringBuffer();

  void flush() {
    if (pending.isEmpty) return;
    _pushRun(parts, pending.toString(), bold: bold);
    pending.clear();
  }

  var last = 0;
  for (final match in _tokenPattern.allMatches(chunk)) {
    if (match.start > last) pending.write(chunk.substring(last, match.start));
    last = match.end;

    final token = match.group(1);
    if (token != null) {
      final glyph = RiftGlyphSpec.parse(token);
      if (glyph == null) {
        // Raccourci inconnu : on le laisse lisible plutôt que de l'effacer.
        pending.write(match.group(0)!);
      } else {
        flush();
        parts.add(RiftTextGlyph(glyph, bold: bold));
      }
      continue;
    }

    final label = match.group(2)!.trim();
    if (_arrowPattern.hasMatch(label)) {
      final previous = parts.isEmpty ? null : parts.last;
      if (pending.isEmpty && previous is RiftTextKeyword) previous.arrow = true;
      continue;
    }
    // Marqueur d'import : la carte n'a pas de texte de règles.
    if (label.toUpperCase() == 'NO TEXT') continue;

    flush();
    parts.add(
      RiftTextKeyword(label: label, family: keywordFamily(label), bold: bold),
    );
  }
  if (last < chunk.length) pending.write(chunk.substring(last));
  flush();
}

/// Ajoute du texte, en le collant au morceau précédent s'il a le même gras
/// (deux marqueurs `**` collés ne doivent pas couper une phrase).
void _pushRun(List<RiftTextPart> parts, String value, {required bool bold}) {
  final previous = parts.isEmpty ? null : parts.last;
  if (previous is RiftTextRun && previous.bold == bold) {
    parts[parts.length - 1] = RiftTextRun(previous.value + value, bold: bold);
    return;
  }
  parts.add(RiftTextRun(value, bold: bold));
}

/// Morceaux d'un texte enrichi, transformés en `InlineSpan` (pour composer
/// avec d'autres fragments : numéro de règle, préfixe…).
List<InlineSpan> riftRichSpans(
  BuildContext context,
  String text, {
  TextStyle? style,
  bool markdownBold = false,
  bool shortTokens = false,
  bool breakGluedAbilities = false,
}) => _spansFor(
  parseRiftText(
    text,
    markdownBold: markdownBold,
    shortTokens: shortTokens,
    breakGluedAbilities: breakGluedAbilities,
  ),
  style ?? riftText(context).body,
);

List<InlineSpan> _spansFor(List<RiftTextPart> parts, TextStyle base) {
  final strong = base.copyWith(fontVariations: RiftFonts.weight(700));
  final fontSize = base.fontSize ?? 15.5;
  return [
    for (final part in parts)
      switch (part) {
        RiftTextRun(:final value, :final bold) => TextSpan(
          text: value,
          style: bold ? strong : base,
        ),
        final RiftTextKeyword keyword => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _KeywordPill(keyword: keyword, fontSize: fontSize),
        ),
        final RiftTextGlyph glyph => WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: RiftGlyph(
              glyph: glyph.glyph,
              size: fontSize * 1.15,
              color: (glyph.bold ? strong : base).color,
              fallbackStyle: glyph.bold ? strong : base,
            ),
          ),
        ),
      },
  ];
}

/// Texte enrichi Riftarium.
class RiftRichText extends StatefulWidget {
  const RiftRichText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.markdownBold = false,
    this.shortTokens = false,
    this.breakGluedAbilities = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Voir [parseRiftText].
  final bool markdownBold;
  final bool shortTokens;
  final bool breakGluedAbilities;

  @override
  State<RiftRichText> createState() => _RiftRichTextState();
}

class _RiftRichTextState extends State<RiftRichText> {
  /// Le découpage serait refait à chaque reconstruction sinon (chaque image de
  /// reflet foil, chaque défilement) : il ne dépend que du texte.
  late List<RiftTextPart> _parts;

  @override
  void initState() {
    super.initState();
    _parts = _parse();
  }

  @override
  void didUpdateWidget(RiftRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.markdownBold != widget.markdownBold ||
        oldWidget.shortTokens != widget.shortTokens ||
        oldWidget.breakGluedAbilities != widget.breakGluedAbilities) {
      _parts = _parse();
    }
  }

  List<RiftTextPart> _parse() => parseRiftText(
    widget.text,
    markdownBold: widget.markdownBold,
    shortTokens: widget.shortTokens,
    breakGluedAbilities: widget.breakGluedAbilities,
  );

  @override
  Widget build(BuildContext context) {
    if (_parts.isEmpty) return const SizedBox.shrink();
    final base = widget.style ?? riftText(context).body;
    return Text.rich(
      TextSpan(children: _spansFor(_parts, base)),
      style: base,
      textAlign: widget.textAlign,
    );
  }
}

/// Pastille d'un mot-clé : capitales italiques claires sur la couleur de sa
/// famille. Le chevron (`[Action] [>]`) taille la pastille en pointe.
class _KeywordPill extends StatelessWidget {
  const _KeywordPill({required this.keyword, required this.fontSize});

  final RiftTextKeyword keyword;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: EdgeInsets.fromLTRB(6, 1, keyword.arrow ? 12 : 6, 1.5),
      color: keywordColor(keyword.family),
      child: Text(
        keyword.label.toUpperCase(),
        style: riftText(context).small.copyWith(
          // `.rb-kw { font-size: 0.78em }` sur le site.
          fontSize: fontSize * 0.78,
          fontStyle: FontStyle.italic,
          fontVariations: RiftFonts.weight(700),
          letterSpacing: 0.4,
          height: 1.2,
          color: RiftColors.onAccent,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: keyword.arrow
          ? ClipPath(clipper: const _ArrowClipper(), child: pill)
          : ClipRRect(borderRadius: BorderRadius.circular(3), child: pill),
    );
  }
}

/// Bord droit en pointe, comme `clip-path` sur `.rb-kw.arrow`.
class _ArrowClipper extends CustomClipper<Path> {
  const _ArrowClipper();

  @override
  Path getClip(Size size) {
    const tip = 6.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - tip, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - tip, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
