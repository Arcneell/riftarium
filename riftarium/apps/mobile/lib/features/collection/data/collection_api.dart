import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/collection.dart';

final collectionApiProvider = Provider<CollectionApi>(
  (ref) => CollectionApi(ref.watch(dioProvider)),
);

/// Appels `/api/collection*` et `/api/wishlist*`.
///
/// Les deux ressources partagent ce client : la wishlist n'a ni pagination ni
/// filtres, elle tient en trois appels.
class CollectionApi {
  CollectionApi(this._dio);

  final Dio _dio;

  /// `GET /api/collection` : page de cartes possédées + stats globales.
  Future<CollectionPage> list({
    String? query,
    String? setId,
    String? sort,
    int page = 1,
    int size = 60,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/collection',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (setId != null && setId.isNotEmpty) 'set_id': setId,
          if (sort != null && sort.isNotEmpty) 'sort': sort,
          'page': page,
          'size': size,
        },
      );
      return CollectionPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `GET /api/collection/sets` : complétion par set et cumul.
  Future<CollectionProgress> progress() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/collection/sets');
      return CollectionProgress.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `GET /api/collection/{card_id}` : les lots possédés d'une carte.
  Future<CardCollectionState> cardState(String cardId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/collection/${Uri.encodeComponent(cardId)}',
      );
      return CardCollectionState.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `PUT /api/collection/{card_id}` : fixe la quantité du lot (état, langue).
  /// `qty: 0` supprime le lot. La réponse ne décrit que ce lot, pas la carte
  /// entière : l'appelant recharge s'il a besoin du total.
  Future<void> setQuantity({
    required String cardId,
    required int qty,
    String condition = defaultCondition,
    String lang = defaultLang,
  }) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/collection/${Uri.encodeComponent(cardId)}',
        data: {'qty': qty, 'condition': condition, 'lang': lang},
      );
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `POST /api/collection/{card_id}/entries` : ajoute un lot (les quantités
  /// s'additionnent quand le couple état/langue existe déjà).
  Future<CardCollectionState> addEntry({
    required String cardId,
    required int qty,
    String condition = defaultCondition,
    String lang = defaultLang,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/collection/${Uri.encodeComponent(cardId)}/entries',
        data: {'qty': qty, 'condition': condition, 'lang': lang},
      );
      return CardCollectionState.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `PATCH /api/collection/entries/{entry_id}` : modifie un lot existant.
  /// `qty: 0` le supprime.
  Future<CardCollectionState> updateEntry({
    required int entryId,
    int? qty,
    String? condition,
    String? lang,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/collection/entries/$entryId',
        data: {'qty': ?qty, 'condition': ?condition, 'lang': ?lang},
      );
      return CardCollectionState.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `POST /api/collection/bulk` : retire toutes les cartes visées d'un coup
  /// (`remove`). Un seul appel, donc pas d'échec à moitié comme lorsque les
  /// lots étaient supprimés un par un.
  Future<void> removeCards(List<String> cardIds) async {
    if (cardIds.isEmpty) return;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/collection/bulk',
        data: {'card_ids': cardIds, 'remove': true},
      );
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `GET /api/wishlist` : toute la wishlist, la plus récente d'abord.
  Future<Wishlist> wishlist() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/wishlist');
      return Wishlist.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `PUT /api/wishlist/{card_id}` : quantité souhaitée (1 à 99), 204.
  Future<void> setWish({required String cardId, required int qty}) async {
    try {
      await _dio.put<void>(
        '/wishlist/${Uri.encodeComponent(cardId)}',
        data: {'qty': qty},
      );
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// `DELETE /api/wishlist/{card_id}` : retire la carte de la wishlist, 204.
  Future<void> removeWish(String cardId) async {
    try {
      await _dio.delete<void>('/wishlist/${Uri.encodeComponent(cardId)}');
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}
