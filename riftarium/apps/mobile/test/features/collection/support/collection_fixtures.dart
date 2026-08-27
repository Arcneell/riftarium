import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';

import '../../../support/fakes.dart';

/// Carte telle que `card_out` la renvoie. `image_url` reste null : les tests de
/// widgets n'ont pas de réseau.
Map<String, dynamic> cardJson({
  required String id,
  String name = 'Jinx, la Gâchette folle',
  int collectorNumber = 209,
  String setId = 'OGN',
  double? priceEur,
  int? ownedQty,
  int? wishedQty,
}) => {
  'id': id,
  'riftbound_id': id,
  'name': name,
  'collector_number': collectorNumber,
  'set_id': setId,
  'type': 'Unit',
  'supertype': 'Champion',
  'rarity': 'Epic',
  'domains': ['Fury'],
  'tags': ['Zaun'],
  'energy': 5,
  'might': 4,
  'power': 2,
  'text': 'Quand Jinx arrive, infligez 2 dégâts.',
  'flavour': null,
  'image_url': null,
  'artist': 'Riot Games',
  'orientation': 'portrait',
  'alternate_art': false,
  'signature': false,
  'overnumbered': false,
  'foil': false,
  'price_eur': priceEur,
  'owned_qty': ?ownedQty,
  'wished_qty': ?wishedQty,
};

Map<String, dynamic> entryJson({
  required int id,
  int qty = 1,
  String condition = 'NM',
  String lang = 'EN',
}) => {'id': id, 'qty': qty, 'condition': condition, 'lang': lang};

Map<String, dynamic> collectionItemJson({
  required Map<String, dynamic> card,
  required List<Map<String, dynamic>> entries,
  double? priceEur,
}) {
  final totalQty = entries.fold<int>(
    0,
    (total, e) => total + (e['qty'] as int),
  );
  return {
    'card': card,
    'total_qty': totalQty,
    'entries': entries,
    'price_eur': priceEur,
    'value_eur': priceEur == null ? null : totalQty * priceEur,
  };
}

Map<String, dynamic> collectionPageJson({
  List<Map<String, dynamic>> items = const [],
  int? total,
  int totalCards = 0,
  int uniqueCards = 0,
  double? valueEur,
  int page = 1,
  int size = 60,
}) => {
  'total_cards': totalCards,
  'unique_cards': uniqueCards,
  'value_eur': valueEur,
  'total': total ?? items.length,
  'page': page,
  'size': size,
  'items': items,
};

Map<String, dynamic> cardStateJson({
  required String cardId,
  List<Map<String, dynamic>> entries = const [],
}) => {
  'card_id': cardId,
  'total_qty': entries.fold<int>(0, (total, e) => total + (e['qty'] as int)),
  'entries': entries,
};

const setsProgressJson = {
  'sets': [
    {
      'set_id': 'OGN',
      'name': 'Origines',
      'total': 100,
      'owned': 25,
      'missing': 75,
      'missing_cost_eur': 210.5,
      'owned_value_eur': 64.0,
    },
  ],
  'overall': {
    'total': 100,
    'owned': 25,
    'missing': 75,
    'missing_cost_eur': 210.5,
    'owned_value_eur': 64.0,
  },
};

Map<String, dynamic> wishlistJson({
  List<Map<String, dynamic>> items = const [],
  double? valueEur,
}) => {'total': items.length, 'value_eur': valueEur, 'items': items};

Map<String, dynamic> wishItemJson({
  required Map<String, dynamic> card,
  int qty = 1,
}) => {'card': card, 'qty': qty, 'created_at': '2026-08-01T10:00:00+00:00'};

/// Conteneur Riverpod branché sur le faux serveur, session ouverte ou non.
ProviderContainer collectionContainer(
  FakeHttpAdapter adapter, {
  String? token = 'jwt',
}) {
  final store = InMemoryTokenStore(token);
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      dioProvider.overrideWith(
        (ref) => createApiClient(
          readToken: store.read,
          baseUrl: 'https://api.test/api',
          adapter: adapter,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
