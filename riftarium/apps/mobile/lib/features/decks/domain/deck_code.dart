/// Codes de deck Riftbound : encodage et décodage.
///
/// Portage Dart de `@piltoverarchive/riftbound-deck-codes` 1.4.0 (formats 1.1
/// à 1.5) et des conversions `toCardCode` de `apps/web/src/deckExport.js`. Les
/// codes produits ici sont identiques, octet pour octet, à ceux du site :
/// `test/features/decks/deck_code_test.dart` compare des codes générés par la
/// bibliothèque JavaScript.
///
/// Fichier volontairement sans dépendance à Flutter (pur Dart, testable seul).
library;

/// Code de deck illisible ou incompatible (message affichable tel quel).
class DeckCodeException implements Exception {
  const DeckCodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Une carte du code : `OGN-247` en 3 exemplaires.
class DeckCodeCard {
  const DeckCodeCard(this.cardCode, this.count);

  final String cardCode;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DeckCodeCard &&
      other.cardCode == cardCode &&
      other.count == count;

  @override
  int get hashCode => Object.hash(cardCode, count);

  @override
  String toString() => '$count× $cardCode';
}

/// Contenu décodé d'un code de deck.
class DeckCodeContents {
  const DeckCodeContents({
    required this.mainDeck,
    this.sideboard = const [],
    this.chosenChampion,
  });

  final List<DeckCodeCard> mainDeck;
  final List<DeckCodeCard> sideboard;

  /// Champion élu, si le code en porte un (format 1.3 et suivants).
  final String? chosenChampion;
}

/// Sets connus de la bibliothèque, avec leur identifiant numérique.
const Map<String, int> deckCodeSetMap = {
  'OGN': 0,
  'OGS': 1,
  'ARC': 2,
  'SFD': 3,
  'UNL': 4,
  'VEN': 5,
  'RAD': 6,
};

/// Suffixes de variante, avec leur identifiant numérique (`*` = signature).
const Map<String, int> deckCodeVariantMap = {
  '': 0,
  'a': 1,
  's': 2,
  '*': 2,
  'b': 3,
};

const int _format = 1;
const int _maxVersion = 5;
const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

final RegExp _standardId = RegExp(
  r'^([a-z][a-z0-9]*)-(\d+)([a-z*]?)-(\d+)$',
  caseSensitive: false,
);
final RegExp _runicId = RegExp(
  r'^([a-z][a-z0-9]*)-r(\d+)([a-z]?)$',
  caseSensitive: false,
);
final RegExp _specialId = RegExp(
  r'^([a-z][a-z0-9]*)-sp(\d+)([a-z]?)(?:-(\d+))?$',
  caseSensitive: false,
);
final RegExp _cardNumber = RegExp(r'^((?:R|SP)?\d+)([a-z*]?)$');

/// Convertit un `riftbound_id` Riftarium (`ogn-247-298`) en code de carte
/// (`OGN-247`). Même conversion que `toCardCode` côté site.
String toCardCode(String? riftboundId) {
  final raw = (riftboundId ?? '').trim();
  if (raw.isEmpty) return '';

  final standard = _standardId.firstMatch(raw);
  if (standard != null) {
    final marker = standard.group(3) ?? '';
    final variant = marker == '*' ? 's' : marker.toLowerCase();
    final number = standard.group(2)!.padLeft(3, '0');
    return '${standard.group(1)!.toUpperCase()}-$number$variant';
  }

  final rune = _runicId.firstMatch(raw);
  if (rune != null) {
    final number = rune.group(2)!.padLeft(2, '0');
    final variant = (rune.group(3) ?? '').toLowerCase();
    return '${rune.group(1)!.toUpperCase()}-R$number$variant';
  }

  final special = _specialId.firstMatch(raw);
  if (special != null) {
    final number = int.parse(special.group(2)!);
    return '${special.group(1)!.toUpperCase()}-SP$number${special.group(3) ?? ''}';
  }

  return raw.toUpperCase();
}

/// Requête `q` de `GET /api/cards` qui ramène la carte d'un code.
///
/// Le suffixe de variante est retiré : la signature s'écrit `*` dans les
/// identifiants Riftarium (`ogn-037*-298`) mais `s` dans les codes de deck.
String cardCodeQuery(String cardCode) {
  final parsed = _parseCardCode(cardCode);
  return '${parsed.set}-${parsed.number}'.toLowerCase();
}

/// Encode un deck en code partageable (base32).
String encodeDeckCode(
  List<DeckCodeCard> mainDeck, {
  List<DeckCodeCard> sideboard = const [],
  String? chosenChampion,
}) {
  for (final card in [...mainDeck, ...sideboard]) {
    if (card.count < 1) {
      throw DeckCodeException(
        'Quantité invalide pour ${card.cardCode} : ${card.count}.',
      );
    }
  }

  bool hasRune(String code) => _parseCardCode(code).number.startsWith('R');
  bool hasSpecial(String code) => _parseCardCode(code).number.startsWith('SP');

  final needsV4 =
      mainDeck.any((c) => hasRune(c.cardCode)) ||
      sideboard.any((c) => hasRune(c.cardCode)) ||
      (chosenChampion != null && hasRune(chosenChampion));

  final maxMain = mainDeck.fold<int>(0, (m, c) => c.count > m ? c.count : m);
  final maxSide = sideboard.fold<int>(0, (m, c) => c.count > m ? c.count : m);
  final anySpecial =
      mainDeck.any((c) => hasSpecial(c.cardCode)) ||
      sideboard.any((c) => hasSpecial(c.cardCode)) ||
      (chosenChampion != null && hasSpecial(chosenChampion));

  // Format 1.5 dès qu'un plafond de copies est dépassé ou qu'une carte « SP »
  // apparaît ; 1.4 pour les runes ; 1.3 sinon (codes identiques aux versions
  // précédentes de la bibliothèque).
  final version = (maxMain > 12 || maxSide > 3 || anySpecial)
      ? 5
      : (needsV4 ? 4 : 3);
  final flagged = needsV4 || anySpecial;

  final bytes = <int>[(_format << 4) | version];
  if (version >= 5) {
    bytes.add(flagged ? 1 : 0);
    bytes.addAll(_encodeSparse(mainDeck, flagged));
    bytes.addAll(_encodeSparse(sideboard, flagged));
  } else {
    bytes.addAll(_encodeSection(mainDeck, 12, version));
    bytes.addAll(_encodeSection(sideboard, 3, version));
  }

  if (chosenChampion != null && chosenChampion.isNotEmpty) {
    final parsed = _parseCardCode(chosenChampion);
    bytes.add(0x01);
    bytes.add(_setValue(parsed.set));
    bytes.add(_variantValue(parsed.variant));
    final number = parsed.number;
    if (flagged && number.startsWith('SP')) {
      bytes.add(0x02);
      bytes.addAll(_varint(int.parse(number.substring(2))));
    } else if (flagged && number.startsWith('R')) {
      bytes.add(0x01);
      bytes.addAll(_varint(int.parse(number.substring(1))));
    } else if (flagged) {
      bytes.add(0x00);
      bytes.addAll(_varint(int.parse(number)));
    } else {
      bytes.addAll(_varint(int.parse(number)));
    }
  } else {
    bytes.add(0x00);
  }

  return _base32Encode(bytes);
}

/// Décode un code de deck. `signedSuffix` contrôle l'écriture des signatures.
DeckCodeContents decodeDeckCode(String code, {String signedSuffix = 's'}) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) throw const DeckCodeException('Code de deck vide.');

  final reader = _Reader(_base32Decode(trimmed));
  final formatVersion = reader.get(0);
  reader.skip(1);
  final format = (formatVersion >> 4) & 0x0f;
  final version = formatVersion & 0x0f;
  if (format != _format) {
    throw DeckCodeException('Format de code inconnu ($format).');
  }
  if (version > _maxVersion || version < 1) {
    throw DeckCodeException('Version de code non gérée ($version).');
  }

  bool flagged;
  if (version >= 5) {
    final prefixFlag = reader.get(0);
    reader.skip(1);
    if (prefixFlag > 1) {
      throw DeckCodeException('Marqueur de code inconnu ($prefixFlag).');
    }
    flagged = prefixFlag == 1;
  } else {
    flagged = version >= 4;
  }

  List<DeckCodeCard> mainDeck;
  var sideboard = <DeckCodeCard>[];
  if (version >= 5) {
    mainDeck = _decodeSparse(reader, signedSuffix, flagged);
    sideboard = _decodeSparse(reader, signedSuffix, flagged);
  } else {
    mainDeck = _decodeSection(reader, 12, signedSuffix, version);
    if (version >= 2) {
      sideboard = _decodeSection(reader, 3, signedSuffix, version);
    }
  }

  String? chosenChampion;
  if (version >= 3) {
    final hasChampion = reader.get(0);
    reader.skip(1);
    if (hasChampion == 0x01) {
      final set = reader.get(0);
      final variant = reader.get(1);
      reader.skip(2);
      final number = _readNumber(reader, flagged);
      chosenChampion =
          '${_setCode(set)}-$number${_variantCode(variant, signedSuffix)}';
    }
  }

  return DeckCodeContents(
    mainDeck: mainDeck,
    sideboard: sideboard,
    chosenChampion: chosenChampion,
  );
}

// ---------------------------------------------------------------- sections

List<int> _encodeSection(List<DeckCodeCard> deck, int maxCount, int version) {
  final bytes = <int>[];
  for (var count = maxCount; count >= 1; count--) {
    final groups = _groupBySetAndVariant(
      deck.where((card) => card.count == count).toList(),
    );
    bytes.addAll(_varint(groups.length));
    for (final group in groups) {
      bytes.addAll(_varint(group.numbers.length));
      bytes.add(group.set);
      bytes.add(group.variant);
      for (final number in group.numbers) {
        if (version >= 4) {
          if (number.startsWith('R')) {
            bytes.add(0x01);
            bytes.addAll(_varint(int.parse(number.substring(1))));
          } else {
            bytes.add(0x00);
            bytes.addAll(_varint(int.parse(number)));
          }
        } else {
          bytes.addAll(_varint(int.parse(number)));
        }
      }
    }
  }
  return bytes;
}

List<int> _encodeSparse(List<DeckCodeCard> deck, bool flagged) {
  final bytes = <int>[];
  final counts =
      deck
          .where((card) => card.count >= 1)
          .map((card) => card.count)
          .toSet()
          .toList()
        ..sort((a, b) => b - a);
  bytes.addAll(_varint(counts.length));
  for (final count in counts) {
    bytes.addAll(_varint(count));
    final groups = _groupBySetAndVariant(
      deck.where((card) => card.count == count).toList(),
    );
    bytes.addAll(_varint(groups.length));
    for (final group in groups) {
      bytes.addAll(_varint(group.numbers.length));
      bytes.add(group.set);
      bytes.add(group.variant);
      for (final number in group.numbers) {
        if (!flagged) {
          bytes.addAll(_varint(int.parse(number)));
        } else if (number.startsWith('SP')) {
          bytes.add(0x02);
          bytes.addAll(_varint(int.parse(number.substring(2))));
        } else if (number.startsWith('R')) {
          bytes.add(0x01);
          bytes.addAll(_varint(int.parse(number.substring(1))));
        } else {
          bytes.add(0x00);
          bytes.addAll(_varint(int.parse(number)));
        }
      }
    }
  }
  return bytes;
}

List<DeckCodeCard> _decodeSection(
  _Reader reader,
  int maxCount,
  String signedSuffix,
  int version,
) {
  final deck = <DeckCodeCard>[];
  for (var count = maxCount; count >= 1; count--) {
    final groups = reader.popVarint();
    for (var i = 0; i < groups; i++) {
      final cards = reader.popVarint();
      final set = reader.get(0);
      final variant = reader.get(1);
      reader.skip(2);
      final setCode = _setCode(set);
      final variantCode = _variantCode(variant, signedSuffix);
      for (var j = 0; j < cards; j++) {
        final number = version >= 4
            ? _readNumber(reader, true)
            : reader.popVarint().toString().padLeft(3, '0');
        deck.add(DeckCodeCard('$setCode-$number$variantCode', count));
      }
    }
  }
  return deck;
}

List<DeckCodeCard> _decodeSparse(
  _Reader reader,
  String signedSuffix,
  bool flagged,
) {
  final deck = <DeckCodeCard>[];
  final numCounts = reader.popVarint();
  for (var i = 0; i < numCounts; i++) {
    final count = reader.popVarint();
    final groups = reader.popVarint();
    for (var g = 0; g < groups; g++) {
      final cards = reader.popVarint();
      final set = reader.get(0);
      final variant = reader.get(1);
      reader.skip(2);
      final setCode = _setCode(set);
      final variantCode = _variantCode(variant, signedSuffix);
      for (var j = 0; j < cards; j++) {
        final number = _readNumber(reader, flagged);
        deck.add(DeckCodeCard('$setCode-$number$variantCode', count));
      }
    }
  }
  return deck;
}

/// Numéro de carte : préfixe optionnel (0x00 normal, 0x01 rune, 0x02 spécial)
/// puis varint. Sans marqueur, le numéro est écrit nu sur trois chiffres.
String _readNumber(_Reader reader, bool flagged) {
  if (!flagged) return reader.popVarint().toString().padLeft(3, '0');
  final prefix = reader.get(0);
  reader.skip(1);
  final value = reader.popVarint();
  switch (prefix) {
    case 0x00:
      return value.toString().padLeft(3, '0');
    case 0x01:
      return 'R${value.toString().padLeft(2, '0')}';
    case 0x02:
      return 'SP$value';
    default:
      throw DeckCodeException('Marqueur de numéro inconnu ($prefix).');
  }
}

// ------------------------------------------------------------- regroupement

class _Group {
  _Group(this.set, this.variant);

  final int set;
  final int variant;
  final List<String> numbers = [];
}

List<_Group> _groupBySetAndVariant(List<DeckCodeCard> cards) {
  final groups = <String, _Group>{};
  for (final card in cards) {
    final parsed = _parseCardCode(card.cardCode);
    final key = '${parsed.set}-${parsed.variant}';
    final group = groups.putIfAbsent(
      key,
      () => _Group(_setValue(parsed.set), _variantValue(parsed.variant)),
    );
    group.numbers.add(parsed.number);
  }
  final ordered = groups.values.toList()
    ..sort((a, b) => a.set != b.set ? a.set - b.set : a.variant - b.variant);
  for (final group in ordered) {
    group.numbers.sort(_compareNumbers);
  }
  return ordered;
}

/// Ordre alphanumérique de `localeCompare(…, { numeric: true })` : les chiffres
/// avant les lettres (`007` < `R02` < `SP4`), puis la valeur numérique.
int _compareNumbers(String a, String b) {
  final rankA = _numberRank(a);
  final rankB = _numberRank(b);
  if (rankA != rankB) return rankA - rankB;
  final valueA = int.parse(a.substring(rankA == 2 ? 2 : rankA));
  final valueB = int.parse(b.substring(rankB == 2 ? 2 : rankB));
  if (valueA != valueB) return valueA - valueB;
  return a.compareTo(b);
}

int _numberRank(String number) {
  if (number.startsWith('SP')) return 2;
  if (number.startsWith('R')) return 1;
  return 0;
}

// ------------------------------------------------------------------ codes

class _ParsedCode {
  const _ParsedCode(this.set, this.number, this.variant);

  final String set;
  final String number;
  final String variant;
}

_ParsedCode _parseCardCode(String cardCode) {
  final parts = cardCode.split('-');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
    throw DeckCodeException('Code de carte invalide : $cardCode.');
  }
  final match = _cardNumber.firstMatch(parts[1]);
  if (match == null) {
    throw DeckCodeException('Code de carte invalide : $cardCode.');
  }
  return _ParsedCode(parts[0], match.group(1) ?? '', match.group(2) ?? '');
}

int _setValue(String set) {
  final value = deckCodeSetMap[set];
  if (value == null) throw DeckCodeException('Set inconnu : $set.');
  return value;
}

int _variantValue(String variant) {
  final value = deckCodeVariantMap[variant];
  if (value == null) throw DeckCodeException('Variante inconnue : $variant.');
  return value;
}

String _setCode(int value) {
  for (final entry in deckCodeSetMap.entries) {
    if (entry.value == value) return entry.key;
  }
  throw DeckCodeException('Set inconnu dans le code ($value).');
}

String _variantCode(int value, String signedSuffix) {
  if (value == 2) return signedSuffix;
  for (final entry in deckCodeVariantMap.entries) {
    if (entry.value == value) return entry.key;
  }
  return '';
}

// ----------------------------------------------------------------- varints

List<int> _varint(int value) {
  if (value == 0) return const [0];
  final bytes = <int>[];
  var rest = value;
  while (rest != 0) {
    var byte = rest & 0x7f;
    rest = rest >>> 7;
    if (rest != 0) byte |= 0x80;
    bytes.add(byte);
  }
  return bytes;
}

/// Lecture séquentielle des octets décodés (équivalent du `VarintTranslator`).
class _Reader {
  _Reader(this._bytes);

  final List<int> _bytes;
  int _offset = 0;

  int get(int index) {
    final position = _offset + index;
    if (index < 0 || position >= _bytes.length) {
      throw const DeckCodeException('Code de deck incomplet.');
    }
    return _bytes[position];
  }

  void skip(int count) => _offset += count;

  int popVarint() {
    if (_offset >= _bytes.length) {
      throw const DeckCodeException('Code de deck incomplet.');
    }
    var result = 0;
    var shift = 0;
    for (var i = _offset; i < _bytes.length; i++) {
      result |= (_bytes[i] & 0x7f) << shift;
      if ((_bytes[i] & 0x80) != 0x80) {
        _offset = i + 1;
        return result;
      }
      shift += 7;
    }
    throw const DeckCodeException('Code de deck incomplet.');
  }
}

// ------------------------------------------------------------------ base32

String _base32Encode(List<int> bytes) {
  final buffer = StringBuffer();
  var accumulator = 0;
  var bitsLeft = 0;
  for (final byte in bytes) {
    accumulator = (accumulator << 8) | byte;
    bitsLeft += 8;
    while (bitsLeft >= 5) {
      bitsLeft -= 5;
      buffer.write(_base32Alphabet[(accumulator >> bitsLeft) & 0x1f]);
    }
  }
  if (bitsLeft > 0) {
    accumulator <<= 5 - bitsLeft;
    buffer.write(_base32Alphabet[accumulator & 0x1f]);
  }
  return buffer.toString();
}

List<int> _base32Decode(String code) {
  final bytes = <int>[];
  var accumulator = 0;
  var bitsLeft = 0;
  for (final char in code.split('')) {
    final value = _base32Alphabet.indexOf(char.toUpperCase());
    if (value == -1) {
      throw DeckCodeException('Caractère invalide dans le code : « $char ».');
    }
    accumulator = (accumulator << 5) | value;
    bitsLeft += 5;
    while (bitsLeft >= 8) {
      bitsLeft -= 8;
      bytes.add((accumulator >> bitsLeft) & 0xff);
    }
  }
  if (bytes.isEmpty) throw const DeckCodeException('Code de deck incomplet.');
  return bytes;
}
