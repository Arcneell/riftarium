import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/card.dart';

final cardsApiProvider = Provider<CardsApi>(
  (ref) => CardsApi(ref.watch(dioProvider)),
);

/// Filtres de `GET /api/cards` (mêmes noms que les paramètres de requête).
class CardFilters {
  const CardFilters({
    this.query,
    this.setId,
    this.type,
    this.domain,
    this.rarity,
    this.energy,
    this.owned,
    this.sort,
  });

  final String? query;
  final String? setId;
  final String? type;
  final String? domain;
  final String? rarity;
  final String? energy;

  /// `'1'` = possédées, `'0'` = manquantes (utilisateur connecté uniquement).
  final String? owned;

  /// `null` (set + numéro), `'rarity'` ou `'random'`.
  final String? sort;

  bool get isEmpty =>
      (query == null || query!.isEmpty) &&
      setId == null &&
      type == null &&
      domain == null &&
      rarity == null &&
      energy == null &&
      owned == null &&
      sort == null;

  Map<String, dynamic> toQuery() => {
    if (query != null && query!.isNotEmpty) 'q': query,
    if (setId != null) 'set_id': setId,
    if (type != null) 'type': type,
    if (domain != null) 'domain': domain,
    if (rarity != null) 'rarity': rarity,
    if (energy != null) 'energy': energy,
    if (owned != null) 'owned': owned,
    if (sort != null) 'sort': sort,
  };

  CardFilters copyWith({
    String? query,
    String? setId,
    String? type,
    String? domain,
    String? rarity,
    String? energy,
    String? owned,
    String? sort,
    bool clearSetId = false,
    bool clearType = false,
    bool clearDomain = false,
    bool clearRarity = false,
    bool clearEnergy = false,
    bool clearOwned = false,
    bool clearSort = false,
  }) => CardFilters(
    query: query ?? this.query,
    setId: clearSetId ? null : (setId ?? this.setId),
    type: clearType ? null : (type ?? this.type),
    domain: clearDomain ? null : (domain ?? this.domain),
    rarity: clearRarity ? null : (rarity ?? this.rarity),
    energy: clearEnergy ? null : (energy ?? this.energy),
    owned: clearOwned ? null : (owned ?? this.owned),
    sort: clearSort ? null : (sort ?? this.sort),
  );
}

/// Appels `/api/cards*`, `/api/sets`, `/api/prices/meta`.
///
/// Pas d'appel à `/cards/{id}/variants` : `GET /cards/{id}` renvoie déjà la
/// famille de variantes dans son champ `variants`.
class CardsApi {
  CardsApi(this._dio);

  final Dio _dio;

  Future<CardPage> list({
    CardFilters filters = const CardFilters(),
    int page = 1,
    int size = 30,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/cards',
        queryParameters: {...filters.toQuery(), 'page': page, 'size': size},
      );
      return CardPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<RiftCard> get(String cardId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/cards/$cardId');
      return RiftCard.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Sets connus (`GET /api/sets`) : l'API répond par une liste JSON nue
  /// (`list_sets`, `apps/api/app/routers/cards.py`).
  Future<List<Map<String, dynamic>>> sets() async {
    try {
      final response = await _dio.get<List<dynamic>>('/sets');
      return (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Métadonnées des prix (`GET /api/prices/meta`) : date, taux, source.
  Future<Map<String, dynamic>> pricesMeta() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/prices/meta');
      return response.data ?? const {};
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}
