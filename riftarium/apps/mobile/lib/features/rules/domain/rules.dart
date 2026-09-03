import 'dart:convert';
import 'dart:math' as math;

/// Modèles des règles officielles (`assets/rules/rules-fr.json`, copie de
/// `riftarium/data/rules-fr.json`, servie aussi sur `/data/rules-fr.json`).
///
/// Structure du fichier : `{core: {...}, tournament: {...}}`, chaque livre
/// contenant des chapitres → sections → entrées numérotées.

/// Numéro « nu », sans le point final : « 103.2. » → « 103.2 ».
String bareRuleNumber(String number) =>
    number.endsWith('.') ? number.substring(0, number.length - 1) : number;

const String _accented = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
const String _plain = 'aaaaaaceeeeiiiinooooouuuuyy';

/// Table de repliage : lettre accentuée (minuscule) → équivalent sans accent.
final Map<int, String> _foldTable = {
  for (var i = 0; i < _accented.length; i++) _accented.codeUnitAt(i): _plain[i],
  'œ'.codeUnitAt(0): 'oe',
  'æ'.codeUnitAt(0): 'ae',
  // Apostrophe typographique : « l’unité » doit répondre à « l'unite ».
  '’'.codeUnitAt(0): "'",
};

/// Minuscules sans accents : la recherche ignore la casse et les diacritiques.
String foldForSearch(String value) => foldForSearchWithOffsets(value).folded;

/// Texte replié et, pour chaque caractère replié, l'index du caractère
/// d'origine qui l'a produit.
///
/// Le repliage n'est pas une bijection (« œ » donne deux lettres) : sans cette
/// table, un index trouvé dans le texte replié ne désigne pas le même endroit
/// dans le texte affiché. Utilisé pour découper un extrait de résultat.
({String folded, List<int> offsets}) foldForSearchWithOffsets(String value) {
  // `toLowerCase` conserve la longueur pour les caractères du document : les
  // index de `lower` sont ceux de `value`.
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  final offsets = <int>[];
  for (var i = 0; i < lower.length; i++) {
    final unit = lower.codeUnitAt(i);
    final replacement = _foldTable[unit];
    if (replacement == null) {
      buffer.writeCharCode(unit);
      offsets.add(i);
    } else {
      buffer.write(replacement);
      for (var j = 0; j < replacement.length; j++) {
        offsets.add(i);
      }
    }
  }
  return (folded: buffer.toString(), offsets: offsets);
}

String _string(Object? value) => value is String ? value : '';

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .toList(growable: false);

/// Exemple d'application d'une règle (encart « Exemple » dans le PDF).
class RuleExample {
  const RuleExample({required this.text});

  factory RuleExample.fromJson(Map<String, dynamic> json) =>
      RuleExample(text: _string(json['text']));

  final String text;
}

/// Renvoi vers une autre règle : `{"number": "197", "label": "Emplacements"}`.
class RuleReference {
  const RuleReference({required this.number, required this.label});

  factory RuleReference.fromJson(Map<String, dynamic> json) => RuleReference(
    number: _string(json['number']),
    label: _string(json['label']),
  );

  final String number;
  final String label;
}

/// Une règle : numéro, profondeur d'indentation, texte, exemples et renvois.
class RuleEntry {
  RuleEntry({
    required this.number,
    required this.id,
    required this.depth,
    required this.text,
    this.examples = const [],
    this.refs = const [],
  });

  factory RuleEntry.fromJson(Map<String, dynamic> json) => RuleEntry(
    number: _string(json['number']),
    id: _string(json['id']),
    depth: (json['depth'] as num?)?.toInt() ?? 0,
    text: _string(json['text']),
    examples: _maps(json['examples']).map(RuleExample.fromJson).toList(),
    refs: _maps(json['refs']).map(RuleReference.fromJson).toList(),
  );

  final String number;
  final String id;
  final int depth;
  final String text;
  final List<RuleExample> examples;
  final List<RuleReference> refs;

  /// Numéro sans point final, utilisé par les renvois.
  String get bareNumber => bareRuleNumber(number);

  /// Texte replié (numéro + règle + exemples) : calculé une seule fois, la
  /// recherche parcourt les 2 949 règles à chaque frappe.
  late final String haystack = foldForSearch(
    examples.isEmpty
        ? '$number $text'
        : '$number $text ${examples.map((e) => e.text).join(' ')}',
  );

  /// Force le calcul de [haystack]. Appelé par [parseRulesDocument], donc dans
  /// l'isolate de décodage : la première recherche ne bloque pas le thread UI.
  void warmHaystack() {
    haystack;
  }
}

/// Groupe de règles à l'intérieur d'un chapitre.
class RuleSection {
  RuleSection({
    required this.number,
    required this.id,
    required this.title,
    required this.entries,
  });

  factory RuleSection.fromJson(Map<String, dynamic> json) => RuleSection(
    number: _string(json['number']),
    id: _string(json['id']),
    title: _string(json['title']),
    entries: _maps(json['entries']).map(RuleEntry.fromJson).toList(),
  );

  final String number;
  final String id;
  final String title;
  final List<RuleEntry> entries;

  String get bareNumber => bareRuleNumber(number);
}

/// Chapitre : un ensemble de sections.
class RuleChapter {
  RuleChapter({
    required this.number,
    required this.id,
    required this.title,
    required this.sections,
  });

  factory RuleChapter.fromJson(Map<String, dynamic> json) => RuleChapter(
    number: _string(json['number']),
    id: _string(json['id']),
    title: _string(json['title']),
    sections: _maps(json['sections']).map(RuleSection.fromJson).toList(),
  );

  final String number;
  final String id;
  final String title;
  final List<RuleSection> sections;

  String get bareNumber => bareRuleNumber(number);

  int get ruleCount =>
      sections.fold(0, (total, section) => total + section.entries.length);
}

/// Un document officiel : « Règles du jeu » (core) ou « Règles de tournoi ».
class RuleBook {
  RuleBook({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.updated,
    required this.source,
    required this.ruleCount,
    required this.chapters,
  });

  factory RuleBook.fromJson(String key, Map<String, dynamic> json) => RuleBook(
    key: _string(json['key']).isEmpty ? key : _string(json['key']),
    title: _string(json['title']),
    subtitle: _string(json['subtitle']),
    updated: _string(json['updated']),
    source: _string(json['source']),
    ruleCount: (json['ruleCount'] as num?)?.toInt() ?? 0,
    chapters: _maps(json['chapters']).map(RuleChapter.fromJson).toList(),
  );

  final String key;
  final String title;
  final String subtitle;

  /// Date de mise à jour telle qu'écrite dans le document (« 16 juillet 2026 »).
  final String updated;

  /// URL du PDF officiel.
  final String source;
  final int ruleCount;
  final List<RuleChapter> chapters;

  /// Signature de version : sert à détecter une mise à jour en ligne.
  String get signature => '$key/$updated/$ruleCount';
}

/// Mois français tels qu'écrits dans le champ `updated` du document.
const List<String> _frenchMonths = [
  'janvier',
  'fevrier',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'aout',
  'septembre',
  'octobre',
  'novembre',
  'decembre',
];

final RegExp _frenchDate = RegExp(r'^(\d{1,2})\s+(\S+)\s+(\d{4})$');

/// Convertit une date de document (« 16 juillet 2026 ») en date comparable.
/// Renvoie null si le format n'est pas celui attendu : rien ne le garantit,
/// le champ est recopié tel quel du PDF officiel.
DateTime? parseRuleDate(String value) {
  final match = _frenchDate.firstMatch(foldForSearch(value.trim()));
  if (match == null) return null;
  final month = _frenchMonths.indexOf(match.group(2)!);
  if (month < 0) return null;
  final day = int.tryParse(match.group(1)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || year == null) return null;
  return DateTime.utc(year, month + 1, day);
}

/// Date `updated` la plus récente d'un document brut, lue sans le décoder :
/// comparer le cache et l'asset embarqué au démarrage ne doit pas coûter deux
/// décodages de 783 Ko.
DateTime? peekRulesUpdatedAt(String source) {
  DateTime? latest;
  for (final match in _updatedField.allMatches(source)) {
    final date = parseRuleDate(match.group(1)!);
    if (date == null) continue;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest;
}

final RegExp _updatedField = RegExp(r'"updated"\s*:\s*"([^"]*)"');

/// Position d'une règle dans le document : livre › chapitre › section › règle.
class RuleLocation {
  const RuleLocation({
    required this.book,
    required this.chapter,
    required this.section,
    this.entry,
  });

  final RuleBook book;
  final RuleChapter chapter;
  final RuleSection section;
  final RuleEntry? entry;
}

/// Les deux documents officiels.
class RulesDocument {
  RulesDocument({required this.books});

  factory RulesDocument.fromJson(Map<String, dynamic> json) {
    // « core » puis « tournament » d'abord : c'est l'ordre d'affichage attendu.
    final keys = <String>[
      for (final key in const ['core', 'tournament'])
        if (json[key] is Map<String, dynamic>) key,
      for (final key in json.keys)
        if (json[key] is Map<String, dynamic> &&
            key != 'core' &&
            key != 'tournament')
          key,
    ];
    return RulesDocument(
      books: [
        for (final key in keys)
          RuleBook.fromJson(key, json[key] as Map<String, dynamic>),
      ],
    );
  }

  final List<RuleBook> books;

  RuleBook? get core =>
      bookByKey('core') ?? (books.isEmpty ? null : books.first);

  RuleBook? get tournament => bookByKey('tournament');

  RuleBook? bookByKey(String key) {
    for (final book in books) {
      if (book.key == key) return book;
    }
    return null;
  }

  /// Signature de l'ensemble : `updated` + `ruleCount` de chaque livre.
  String get signature => books.map((book) => book.signature).join('|');

  late final Map<String, RuleLocation> _index = _buildIndex();

  Map<String, RuleLocation> _buildIndex() {
    final index = <String, RuleLocation>{};
    for (final book in books) {
      for (final chapter in book.chapters) {
        final firstSection = chapter.sections.isEmpty
            ? null
            : chapter.sections.first;
        if (firstSection != null) {
          index.putIfAbsent(
            '${book.key}:${chapter.bareNumber}',
            () => RuleLocation(
              book: book,
              chapter: chapter,
              section: firstSection,
            ),
          );
        }
        for (final section in chapter.sections) {
          index.putIfAbsent(
            '${book.key}:${section.bareNumber}',
            () => RuleLocation(book: book, chapter: chapter, section: section),
          );
          for (final entry in section.entries) {
            index.putIfAbsent(
              '${book.key}:${entry.bareNumber}',
              () => RuleLocation(
                book: book,
                chapter: chapter,
                section: section,
                entry: entry,
              ),
            );
          }
        }
      }
    }
    return index;
  }

  /// Retrouve une règle par son numéro (« 197 », « 355.6. »). Le livre
  /// `fromBookKey` est consulté en premier : les renvois restent dans leur
  /// document quand le numéro existe des deux côtés.
  RuleLocation? locate(String number, {String? fromBookKey}) {
    final bare = bareRuleNumber(number.trim());
    if (bare.isEmpty) return null;
    if (fromBookKey != null) {
      final local = _index['$fromBookKey:$bare'];
      if (local != null) return local;
    }
    for (final book in books) {
      final hit = _index['${book.key}:$bare'];
      if (hit != null) return hit;
    }
    return null;
  }
}

/// Résultat de recherche : la règle et son fil (livre › chapitre › section).
class RuleSearchHit {
  const RuleSearchHit({
    required this.book,
    required this.chapter,
    required this.section,
    required this.entry,
    required this.score,
    required this.snippet,
  });

  final RuleBook book;
  final RuleChapter chapter;
  final RuleSection section;
  final RuleEntry entry;

  /// Pertinence brute (numéro exact > préfixe > nombre d'occurrences).
  final int score;

  /// Extrait du texte autour de la première occurrence.
  final String snippet;

  /// Fil d'Ariane affiché sous le numéro de règle.
  String get breadcrumb =>
      '${book.title} › ${chapter.title} › ${section.bareNumber} ${section.title}';
}

/// Longueur minimale d'une requête : en dessous, tout le livre ressortirait.
const int kRuleSearchMinLength = 2;

/// Une requête « 103 », « 103.2 », « 103.2.a » désigne un numéro de règle.
final RegExp _ruleNumberQuery = RegExp(r'^\d{2,4}(\.\d+|\.[a-z])*\.?$');

const int _snippetRadius = 60;
const int _snippetLength = 190;

String _snippetOf(String text, List<String> tokens) {
  final folded = foldForSearchWithOffsets(text);
  var first = -1;
  for (final token in tokens) {
    final position = folded.folded.indexOf(token);
    if (position >= 0 && (first < 0 || position < first)) first = position;
  }
  // Index replié → index d'origine : « œ » se replie en deux lettres, les
  // deux textes ne se superposent pas.
  final origin = first <= 0
      ? 0
      : (first < folded.offsets.length ? folded.offsets[first] : text.length);
  final start = math.min(math.max(origin - _snippetRadius, 0), text.length);
  final end = math.min(start + _snippetLength, text.length);
  final slice = text.substring(start, end);
  return '${start > 0 ? '… ' : ''}$slice${end < text.length ? ' …' : ''}';
}

int _occurrences(String haystack, String token) {
  var count = 0;
  var from = 0;
  while (true) {
    final position = haystack.indexOf(token, from);
    if (position < 0) return count;
    count++;
    from = position + token.length;
  }
}

/// Recherche dans tout le document : insensible à la casse et aux accents,
/// sur le texte des règles et de leurs exemples.
///
/// Tous les mots de la requête doivent être présents (ET). Le tri privilégie
/// le numéro de règle quand la requête en est un, sinon le nombre
/// d'occurrences ; à égalité, l'ordre du document est conservé.
List<RuleSearchHit> searchRules(
  RulesDocument document,
  String query, {
  int limit = 200,
}) {
  final trimmed = query.trim();
  if (trimmed.length < kRuleSearchMinLength) return const [];
  final tokens = foldForSearch(trimmed)
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return const [];

  final isNumberQuery = _ruleNumberQuery.hasMatch(trimmed);
  final wantedNumber = isNumberQuery ? bareRuleNumber(trimmed) : null;

  final scored = <({RuleSearchHit hit, int score, int order})>[];
  var order = 0;
  for (final book in document.books) {
    for (final chapter in book.chapters) {
      for (final section in chapter.sections) {
        for (final entry in section.entries) {
          final haystack = entry.haystack;
          var score = 0;
          var matchesAll = true;
          for (final token in tokens) {
            final count = _occurrences(haystack, token);
            if (count == 0) {
              matchesAll = false;
              break;
            }
            score += count;
          }
          if (!matchesAll) continue;
          if (wantedNumber != null) {
            if (entry.bareNumber == wantedNumber) {
              score += 10000;
            } else if (entry.bareNumber.startsWith('$wantedNumber.')) {
              score += 5000;
            } else if (section.bareNumber == wantedNumber) {
              score += 2000;
            }
          }
          scored.add((
            hit: RuleSearchHit(
              book: book,
              chapter: chapter,
              section: section,
              entry: entry,
              score: score,
              snippet: _snippetOf(entry.text, tokens),
            ),
            score: score,
            order: order++,
          ));
        }
      }
    }
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return [for (final scoredHit in scored.take(limit)) scoredHit.hit];
}

/// Décode le JSON complet. Fonction de premier niveau : appelée dans une
/// isolate via `compute` (783 Ko, le thread UI ne doit pas s'arrêter).
RulesDocument parseRulesDocument(String source) {
  final document = RulesDocument.fromJson(
    jsonDecode(source) as Map<String, dynamic>,
  );
  // Repliage de toutes les règles fait ici : sinon la première frappe dans le
  // champ de recherche le paierait sur le thread UI.
  for (final book in document.books) {
    for (final chapter in book.chapters) {
      for (final section in chapter.sections) {
        for (final entry in section.entries) {
          entry.warmHaystack();
        }
      }
    }
  }
  return document;
}
