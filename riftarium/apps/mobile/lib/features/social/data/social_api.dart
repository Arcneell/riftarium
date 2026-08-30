import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../collection/domain/collection.dart';
import '../../play/domain/history.dart';
import '../domain/achievement.dart';
import '../domain/public_profile.dart';

final socialApiProvider = Provider<SocialApi>(
  (ref) => SocialApi(ref.watch(dioProvider)),
);

/// Appels des profils publics, des hauts faits et des amis
/// (contrat `docs/profils-et-hauts-faits.md`).
///
/// La lecture d'un profil public marche aussi sans session ; tout le reste
/// exige un compte. Les erreurs remontent en [ApiException] avec le `detail`
/// de l'API, déjà rédigé en français.
class SocialApi {
  SocialApi(this._dio);

  final Dio _dio;

  /// Tous les hauts faits du catalogue, débloqués ou non.
  Future<List<Achievement>> achievements() async {
    try {
      final response = await _dio.get<dynamic>('/me/achievements');
      return Achievement.listFrom(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Profil public d'un joueur. 404 si le pseudo est inconnu.
  Future<PublicProfile> profile(String handle) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/$handle');
      return PublicProfile.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Collection d'un joueur (403 si elle est masquée).
  Future<CollectionPage> collection(
    String handle, {
    String? query,
    String? setId,
    int page = 1,
    int size = 60,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/$handle/collection',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (setId != null && setId.isNotEmpty) 'set_id': setId,
          'page': page,
          'size': size,
        },
      );
      return CollectionPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Historique des matchs suivis d'un joueur (403 si les stats sont masquées).
  Future<HistoryPage> history(
    String handle, {
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/users/$handle/history',
        queryParameters: {'page': page, 'size': size},
      );
      return HistoryPage.fromJson(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Comptes dont le pseudo commence par [query] (2 caractères au minimum).
  Future<List<SocialUser>> search(String query) async {
    try {
      final response = await _dio.get<dynamic>(
        '/users/search',
        queryParameters: {'q': query},
      );
      return SocialUser.listFrom(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<FollowLists> follows() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/me/follows');
      return FollowLists.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Suivre un joueur (idempotent). 409 si c'est soi-même.
  Future<void> follow(String handle) async {
    try {
      await _dio.put<void>('/users/$handle/follow');
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<void> unfollow(String handle) async {
    try {
      await _dio.delete<void>('/users/$handle/follow');
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}
