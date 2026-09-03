import '../../../core/api_exception.dart';
import '../../cards/domain/card.dart';
import '../../cards/domain/card_labels.dart';

/// États acceptés par l'API (`_norm_condition`, `apps/api/app/schemas.py`),
/// du meilleur au plus abîmé. Libellés repris du site.
const collectionConditions = <String, String>{
  'MT': 'Mint',
  'NM': 'Near Mint',
  'EX': 'Excellent',
  'GD': 'Good',
  'LP': 'Light Played',
  'PL': 'Played',
  'PO': 'Poor',
};

/// Langues acceptées par l'API (`_norm_lang`).
const collectionLangs = <String, String>{
  'EN': 'Anglais',
  'FR': 'Français',
  'DE': 'Allemand',
  'ES': 'Espagnol',
  'IT': 'Italien',
  'JP': 'Japonais',
  'KO': 'Coréen',
  'ZH': 'Chinois',
};

const defaultCondition = 'NM';
const defaultLang = 'EN';

/// Bornes des schémas Pydantic : `CollectionPut.qty` et `WishlistPut.qty`.
const maxCollectionQty = 999;
const maxWishQty = 99;

/// Une ligne dont la carte est illisible est ignorée : une page de collection
/// ou de wishlist reste consultable même si l'API a renvoyé une ligne abîmée.
List<T> readableRows<T>(Object? value, T Function(Map<String, dynamic>) build) {
  final rows = <T>[];
  for (final row
      in (value as List? ?? const []).whereType<Map<String, dynamic>>()) {
    try {
      rows.add(build(row));
    } on ApiException {
      continue;
    }
  }
  return rows;
}

/// Lots d'une carte une fois la quantité du couple (état, langue) fixée —
/// 0 retire le lot. Fonction pure, partagée par l'onglet Collection et le
/// stepper de la fiche carte.
List<CollectionEntry> entriesWithQuantity(
  List<CollectionEntry> entries,
  int qty,
  String condition,
  String lang,
) {
  final next = <CollectionEntry>[];
  var found = false;
  for (final entry in entries) {
    if (entry.condition == condition && entry.lang == lang) {
      found = true;
      if (qty > 0) next.add(entry.copyWith(qty: qty));
    } else {
      next.add(entry);
    }
  }
  if (!found && qty > 0) {
    next.add(
      CollectionEntry(id: 0, qty: qty, condition: condition, lang: lang),
    );
  }
  return next;
}

String conditionLabel(String code) => collectionConditions[code] ?? code;

String langLabel(String code) => collectionLangs[code] ?? code;

/// Un lot possédé : une quantité pour un couple (état, langue).
class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.qty,
    required this.condition,
    required this.lang,
  });

  factory CollectionEntry.fromJson(Map<String, dynamic> json) =>
      CollectionEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        condition: (json['condition'] as String?) ?? defaultCondition,
        lang: (json['lang'] as String?) ?? defaultLang,
      );

  final int id;
  final int qty;
  final String condition;
  final String lang;

  /// `2× NM EN`, tel qu'affiché dans la feuille d'édition.
  String get label => '$qty× $condition $lang';

  CollectionEntry copyWith({int? qty, String? condition, String? lang}) =>
      CollectionEntry(
        id: id,
        qty: qty ?? this.qty,
        condition: condition ?? this.condition,
        lang: lang ?? this.lang,
      );

  static List<CollectionEntry> listFrom(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CollectionEntry.fromJson)
          .toList();
}

/// Une carte de la collection : la carte, ses lots et sa valeur estimée
/// (`item_out` dans `apps/api/app/routers/collection.py`).
class CollectionItem {
  const CollectionItem({
    required this.card,
    required this.totalQty,
    required this.entries,
    this.priceEur,
    this.valueEur,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
    card: RiftCard.fromJson(
      (json['card'] as Map<String, dynamic>?) ?? const {},
    ),
    totalQty: (json['total_qty'] as num?)?.toInt() ?? 0,
    entries: CollectionEntry.listFrom(json['entries']),
    priceEur: (json['price_eur'] as num?)?.toDouble(),
    valueEur: (json['value_eur'] as num?)?.toDouble(),
  );

  final RiftCard card;
  final int totalQty;
  final List<CollectionEntry> entries;
  final double? priceEur;
  final double? valueEur;

  /// Résumé des lots : « NM · EN » pour un lot unique, « 2 lots » sinon.
  String get entriesLabel {
    if (entries.isEmpty) return '—';
    if (entries.length == 1) {
      return '${entries.first.condition} · ${entries.first.lang}';
    }
    return '${entries.length} lots';
  }

  /// Recalcule le total et la valeur à partir des lots (mise à jour optimiste).
  CollectionItem copyWith({List<CollectionEntry>? entries}) {
    final nextEntries = entries ?? this.entries;
    final nextTotal = nextEntries.fold<int>(
      0,
      (total, entry) => total + entry.qty,
    );
    final price = priceEur;
    return CollectionItem(
      card: card.copyWith(ownedQty: nextTotal),
      totalQty: nextTotal,
      entries: nextEntries,
      priceEur: price,
      valueEur: price == null
          ? null
          : double.parse((nextTotal * price).toStringAsFixed(2)),
    );
  }
}

/// Page de `GET /api/collection` : les stats sont globales, pas filtrées.
class CollectionPage {
  const CollectionPage({
    required this.totalCards,
    required this.uniqueCards,
    required this.total,
    required this.page,
    required this.size,
    required this.items,
    this.valueEur,
  });

  factory CollectionPage.fromJson(Map<String, dynamic> json) => CollectionPage(
    totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
    uniqueCards: (json['unique_cards'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    size: (json['size'] as num?)?.toInt() ?? 0,
    valueEur: (json['value_eur'] as num?)?.toDouble(),
    items: readableRows(json['items'], CollectionItem.fromJson),
  );

  final int totalCards;
  final int uniqueCards;
  final int total;
  final int page;
  final int size;
  final double? valueEur;
  final List<CollectionItem> items;
}

/// Lots d'une carte (`card_state`) : réponse de `GET /api/collection/{id}`,
/// de l'ajout de lot et du patch de lot.
class CardCollectionState {
  const CardCollectionState({
    required this.cardId,
    required this.totalQty,
    required this.entries,
  });

  const CardCollectionState.empty(this.cardId)
    : totalQty = 0,
      entries = const [];

  factory CardCollectionState.fromJson(Map<String, dynamic> json) =>
      CardCollectionState(
        cardId: (json['card_id'] as String?) ?? '',
        totalQty: (json['total_qty'] as num?)?.toInt() ?? 0,
        entries: CollectionEntry.listFrom(json['entries']),
      );

  final String cardId;
  final int totalQty;
  final List<CollectionEntry> entries;

  /// Lot que pilote le stepper de la fiche carte : le lot unique s'il n'y en a
  /// qu'un, sinon le lot NM/EN (celui que crée l'ajout par défaut).
  CollectionEntry? get mainEntry {
    if (entries.length == 1) return entries.first;
    for (final entry in entries) {
      if (entry.condition == defaultCondition && entry.lang == defaultLang) {
        return entry;
      }
    }
    return null;
  }

  bool get hasSeveralLots => entries.length > 1;

  CardCollectionState copyWith({
    int? totalQty,
    List<CollectionEntry>? entries,
  }) => CardCollectionState(
    cardId: cardId,
    totalQty: totalQty ?? this.totalQty,
    entries: entries ?? this.entries,
  );
}

/// Avancement d'un set (`GET /api/collection/sets`). `overall` réutilise la
/// même forme, sans identifiant de set.
class SetCompletion {
  const SetCompletion({
    required this.setId,
    required this.name,
    required this.total,
    required this.owned,
    required this.missing,
    this.missingCostEur,
    this.ownedValueEur,
  });

  factory SetCompletion.fromJson(Map<String, dynamic> json, {String? name}) =>
      SetCompletion(
        setId: (json['set_id'] as String?) ?? '',
        name: (json['name'] as String?) ?? name ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        owned: (json['owned'] as num?)?.toInt() ?? 0,
        missing: (json['missing'] as num?)?.toInt() ?? 0,
        missingCostEur: (json['missing_cost_eur'] as num?)?.toDouble(),
        ownedValueEur: (json['owned_value_eur'] as num?)?.toDouble(),
      );

  final String setId;
  final String name;
  final int total;
  final int owned;
  final int missing;
  final double? missingCostEur;
  final double? ownedValueEur;

  int get percent => total == 0 ? 0 : (owned * 100 / total).round();

  double get ratio => total == 0 ? 0 : owned / total;

  /// « il manque 12 cartes (~34,50 €) » ou « set complet ».
  String get missingLabel {
    if (missing == 0) return 'set complet';
    final cost = missingCostEur == null ? null : formatEuro(missingCostEur!);
    final plural = missing > 1 ? 's' : '';
    return 'il manque $missing carte$plural${cost == null ? '' : ' (~$cost)'}';
  }
}

/// Progression complète : une ligne par set et le cumul.
class CollectionProgress {
  const CollectionProgress({required this.sets, required this.overall});

  factory CollectionProgress.fromJson(Map<String, dynamic> json) =>
      CollectionProgress(
        sets: (json['sets'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((set) => SetCompletion.fromJson(set))
            .toList(),
        overall: SetCompletion.fromJson(
          (json['overall'] as Map<String, dynamic>?) ?? const {},
          name: 'Tous sets confondus',
        ),
      );

  static const empty = CollectionProgress(
    sets: [],
    overall: SetCompletion(
      setId: '',
      name: 'Tous sets confondus',
      total: 0,
      owned: 0,
      missing: 0,
    ),
  );

  final List<SetCompletion> sets;
  final SetCompletion overall;

  bool get isEmpty => sets.isEmpty && overall.total == 0;
}

/// Une carte souhaitée (`GET /api/wishlist`).
class WishItem {
  const WishItem({required this.card, required this.qty, this.createdAt});

  factory WishItem.fromJson(Map<String, dynamic> json) => WishItem(
    card: RiftCard.fromJson(
      (json['card'] as Map<String, dynamic>?) ?? const {},
    ),
    qty: (json['qty'] as num?)?.toInt() ?? 1,
    createdAt: json['created_at'] as String?,
  );

  final RiftCard card;
  final int qty;
  final String? createdAt;

  /// Prix estimé de la ligne : prix unitaire × quantité souhaitée.
  double? get valueEur {
    final price = card.priceEur;
    return price == null
        ? null
        : double.parse((price * qty).toStringAsFixed(2));
  }

  WishItem copyWith({int? qty}) =>
      WishItem(card: card, qty: qty ?? this.qty, createdAt: createdAt);
}

/// Wishlist complète : l'API la renvoie d'un bloc, sans pagination.
class Wishlist {
  const Wishlist({required this.total, required this.items, this.valueEur});

  factory Wishlist.fromJson(Map<String, dynamic> json) => Wishlist(
    total: (json['total'] as num?)?.toInt() ?? 0,
    valueEur: (json['value_eur'] as num?)?.toDouble(),
    items: readableRows(json['items'], WishItem.fromJson),
  );

  static const empty = Wishlist(total: 0, items: []);

  final int total;
  final double? valueEur;
  final List<WishItem> items;
}
