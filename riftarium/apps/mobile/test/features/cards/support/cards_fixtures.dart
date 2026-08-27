import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Faux serveur pour les tests de la cartothèque.
///
/// Variante locale de `test/support/fakes.dart` : `/api/sets` et
/// `/api/cards/{id}/variants` répondent par une liste JSON nue, que
/// `FakeResponse` (limité aux objets) ne sait pas produire.
class CardsFakeApi implements HttpClientAdapter {
  CardsFakeApi(this.routes);

  /// Clé : `MÉTHODE chemin` (sans la query string). Valeur : corps JSON
  /// (objet ou liste), [CardsFakeError] pour un échec, ou [CardsFakeRoute]
  /// pour une réponse qui dépend des paramètres de requête (pagination).
  final Map<String, Object> routes;

  final List<RequestOptions> requests = [];

  /// Requêtes reçues sur `GET /cards`, dans l'ordre.
  Iterable<Map<String, dynamic>> get cardQueries => requests
      .where((request) => request.path == '/cards')
      .map((request) => request.queryParameters);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    var route = routes['${options.method} ${options.path}'];
    if (route is CardsFakeRoute) {
      route = route.respond(options.queryParameters);
    }
    if (route is CardsFakeError) {
      return ResponseBody.fromString(
        jsonEncode({'detail': route.detail}),
        route.status,
        headers: _jsonHeaders,
      );
    }
    if (route == null) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Carte introuvable'}),
        404,
        headers: _jsonHeaders,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(route),
      200,
      headers: _jsonHeaders,
    );
  }

  static final _jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

/// Réponse construite à partir des paramètres de requête.
class CardsFakeRoute {
  const CardsFakeRoute(this.respond);

  final Object Function(Map<String, dynamic> query) respond;
}

/// Réponse d'erreur du faux serveur.
class CardsFakeError {
  const CardsFakeError(this.status, this.detail);

  final int status;
  final String detail;
}

/// Carte JSON minimale. `image_url` reste nul : les tests de widgets n'ont pas
/// de réseau, `CardImage` affiche alors son substitut.
Map<String, dynamic> cardJson({
  required String id,
  String? name,
  String? riftboundId,
  String setId = 'OGN',
  int? collectorNumber,
  String type = 'Unit',
  String? supertype,
  String rarity = 'Rare',
  List<String> domains = const ['Fury'],
  List<String> tags = const [],
  int? energy,
  int? might,
  int? power,
  String text = '',
  String? flavour,
  String? artist,
  String? orientation,
  bool alternateArt = false,
  bool signature = false,
  double? priceEur,
  int? ownedQty,
  int? wishedQty,
}) => {
  'id': id,
  'riftbound_id': riftboundId ?? id,
  'name': name ?? 'Carte $id',
  'collector_number': collectorNumber,
  'set_id': setId,
  'type': type,
  'supertype': supertype,
  'rarity': rarity,
  'domains': domains,
  'energy': energy,
  'might': might,
  'power': power,
  'text': text,
  'flavour': flavour,
  'image_url': null,
  'artist': artist,
  'orientation': orientation,
  'tags': tags,
  'alternate_art': alternateArt,
  'signature': signature,
  'overnumbered': false,
  'foil': false,
  'price_eur': priceEur,
  // Absents pour un visiteur anonyme, comme dans `card_out`.
  'owned_qty': ?ownedQty,
  'wished_qty': ?wishedQty,
};

/// Page de `GET /api/cards`.
Map<String, dynamic> cardPageJson({
  required List<Map<String, dynamic>> items,
  required int total,
  int page = 1,
  int size = 30,
}) => {'total': total, 'page': page, 'size': size, 'items': items};

/// `GET /api/cards` : `size` cartes numérotées, sur un total donné.
Map<String, dynamic> generatedPage({
  required int page,
  required int total,
  int size = 30,
}) {
  final first = (page - 1) * size + 1;
  final count = (total - (page - 1) * size).clamp(0, size);
  return cardPageJson(
    total: total,
    page: page,
    size: size,
    items: [
      for (var index = 0; index < count; index++)
        cardJson(
          id: 'OGN-${first + index}',
          name: 'Carte ${first + index}',
          collectorNumber: first + index,
        ),
    ],
  );
}

/// `GET /api/sets` : liste JSON nue, comme l'API.
const List<Map<String, dynamic>> setsJson = [
  {
    'set_id': 'OGN',
    'name': 'Origines',
    'card_count': 298,
    'published_on': '2025-10-31',
  },
  {
    'set_id': 'UNL',
    'name': 'Déchaînés',
    'card_count': 219,
    'published_on': '2026-03-13',
  },
];

/// `GET /api/prices/meta`.
const Map<String, dynamic> pricesMetaJson = {
  'updated_day': '2026-08-20',
  'rate': 0.92,
  'rate_date': '2026-08-19',
  'priced_cards': 512,
  'source': 'tcgplayer',
  'currency_note': 'Prix du marché US (TCGplayer), convertis en € (taux BCE).',
};
