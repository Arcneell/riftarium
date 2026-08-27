import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Faux serveur des tests de decks.
///
/// Variante locale de `test/support/fakes.dart` : `/api/decks/mine` et
/// `/api/community/legends` répondent par une liste JSON nue, que
/// `FakeResponse` (limité aux objets) ne sait pas produire.
class DecksFakeApi implements HttpClientAdapter {
  DecksFakeApi(this.routes);

  /// Clé : `MÉTHODE chemin` (sans query string). Valeur : corps JSON (objet ou
  /// liste) ou [DecksFakeError].
  final Map<String, Object> routes;

  final List<RequestOptions> requests = [];

  /// Chemins reçus, dans l'ordre (`GET /decks/mine`).
  List<String> get calls =>
      requests.map((request) => '${request.method} ${request.path}').toList();

  Iterable<RequestOptions> on(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes['${options.method} ${options.path}'];
    if (route is DecksFakeError) {
      return ResponseBody.fromString(
        jsonEncode({'detail': route.detail}),
        route.status,
        headers: _jsonHeaders,
      );
    }
    if (route == null) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Deck introuvable'}),
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

/// Réponse d'erreur du faux serveur.
class DecksFakeError {
  const DecksFakeError(this.status, this.detail);

  final int status;
  final String detail;
}

/// Carte JSON minimale. `image_url` reste nul : les tests de widgets n'ont pas
/// de réseau, `CardImage` affiche alors son substitut.
Map<String, dynamic> deckCardJson({
  required String id,
  String? name,
  String? riftboundId,
  String setId = 'OGN',
  int? collectorNumber,
  String type = 'Unit',
  String? supertype,
  List<String> domains = const ['Fury'],
  List<String> tags = const [],
  int? energy,
  String text = '',
  String? orientation,
  double? priceEur,
  int? ownedQty,
}) => {
  'id': id,
  'riftbound_id': riftboundId ?? id.toLowerCase(),
  'name': name ?? 'Carte $id',
  'collector_number': collectorNumber,
  'set_id': setId,
  'type': type,
  'supertype': supertype,
  'rarity': 'Rare',
  'domains': domains,
  'energy': energy,
  'might': null,
  'power': null,
  'text': text,
  'flavour': null,
  'image_url': null,
  'artist': null,
  'orientation': orientation,
  'tags': tags,
  'alternate_art': false,
  'signature': false,
  'overnumbered': false,
  'foil': false,
  'price_eur': priceEur,
  'owned_qty': ?ownedQty,
};

/// Un contrôle de `validate_deck`.
Map<String, dynamic> checkJson(String rule, bool ok, String message) => {
  'rule': rule,
  'ok': ok,
  'message': message,
};

/// Deck complet (`deck_out`).
Map<String, dynamic> deckJson({
  required int id,
  String name = 'Fureur d’Ahri',
  String? description,
  String format = 'tournament',
  bool isPublic = false,
  String moderationStatus = 'published',
  int likes = 0,
  bool likedByMe = false,
  int views = 0,
  String owner = 'ezreal',
  int? cardCount,
  double? totalEur,
  double? missingEur,
  List<Map<String, dynamic>> cards = const [],
  List<Map<String, dynamic>> checks = const [],
}) => {
  'id': id,
  'name': name,
  'description': description,
  'format': format,
  'is_public': isPublic,
  'moderation_status': moderationStatus,
  'likes': likes,
  'liked_by_me': likedByMe,
  'views': views,
  'owner': owner,
  'owner_avatar': null,
  'card_count':
      cardCount ??
      cards.fold<int>(0, (total, entry) => total + (entry['qty'] as int)),
  'prices': {'total_eur': totalEur, 'missing_eur': missingEur},
  'cards': cards,
  'checks': checks,
  'updated_at': '2026-08-20T10:00:00+00:00',
};

/// Entrée `{card, qty}` d'un deck.
Map<String, dynamic> deckEntryJson(Map<String, dynamic> card, int qty) => {
  'card': card,
  'qty': qty,
};

/// Deck du listing communautaire (`_community_deck_out`).
Map<String, dynamic> communityDeckJson({
  required int id,
  String name = 'Deck partagé',
  String format = 'tournament',
  bool legal = true,
  int likes = 0,
  bool likedByMe = false,
  int views = 0,
  String owner = 'jinx',
  int cardCount = 56,
  Map<String, dynamic>? legend,
  List<String> domains = const ['Fury'],
  int? missingCards,
  double? missingCostEur,
}) => {
  'id': id,
  'name': name,
  'description': null,
  'format': format,
  'legal': legal,
  'likes': likes,
  'liked_by_me': likedByMe,
  'views': views,
  'owner': owner,
  'owner_avatar': null,
  'card_count': cardCount,
  'legend': legend,
  'domains': domains,
  'missing_cards': missingCards,
  'missing_cost_eur': missingCostEur,
  'updated_at': '2026-08-20T10:00:00+00:00',
};

/// Page de `GET /api/community/decks`.
Map<String, dynamic> communityPageJson({
  required List<Map<String, dynamic>> items,
  int? total,
  int page = 1,
  int size = 20,
}) => {
  'total': total ?? items.length,
  'page': page,
  'size': size,
  'items': items,
};

/// Page de `GET /api/cards`.
Map<String, dynamic> cardPageJson(List<Map<String, dynamic>> items) => {
  'total': items.length,
  'page': 1,
  'size': 30,
  'items': items,
};
