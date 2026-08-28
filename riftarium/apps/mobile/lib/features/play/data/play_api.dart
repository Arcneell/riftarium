import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/history.dart';
import '../domain/match.dart';
import '../domain/play_stats.dart';
import '../domain/room.dart';

final playApiProvider = Provider<PlayApi>(
  (ref) => PlayApi(ref.watch(dioProvider)),
);

/// Appels `/api/play/*` (contrat `docs/suivi-des-matchs.md`).
///
/// Tous les chemins exigent une session : le jeton part avec chaque requête
/// (intercepteur du client). Les erreurs remontent en [ApiException] avec le
/// `detail` de l'API, déjà rédigé en français.
class PlayApi {
  PlayApi(this._dio);

  final Dio _dio;

  /// Crée un salon. 409 si un salon actif existe déjà.
  Future<Room> createRoom({required String mode}) async {
    return _room(
      () =>
          _dio.post<Map<String, dynamic>>('/play/rooms', data: {'mode': mode}),
    );
  }

  Future<Room> room(String code) =>
      _room(() => _dio.get<Map<String, dynamic>>('/play/rooms/$code'));

  /// Rejoint le siège 1. 409 si plein, fermé, expiré, ou si j'ai déjà un salon.
  Future<Room> joinRoom(String code) =>
      _room(() => _dio.post<Map<String, dynamic>>('/play/rooms/$code/join'));

  /// Mon choix dans le salon. Les trois champs partent toujours : une valeur
  /// nulle explicite est le seul moyen de retirer une légende ou un deck.
  Future<Room?> updateMe(
    String code, {
    String? legendCardId,
    int? deckId,
    required bool ready,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/play/rooms/$code/me',
        data: {
          'legend_card_id': legendCardId,
          'deck_id': deckId,
          'ready': ready,
        },
      );
      return _maybeRoom(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// L'invité quitte le salon, qui redevient `open` avec l'hôte seul.
  Future<Room?> leaveRoom(String code) async {
    try {
      final response = await _dio.post<dynamic>('/play/rooms/$code/leave');
      return _maybeRoom(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// L'hôte annule le salon ; l'API renvoie le salon à jour (`cancelled`).
  Future<Room?> cancelRoom(String code) async {
    try {
      final response = await _dio.delete<dynamic>('/play/rooms/$code');
      return _maybeRoom(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Lance la partie (hôte). 409 si les deux joueurs ne sont pas prêts.
  Future<Match> startMatch(String code, {required int firstPlayerId}) => _match(
    () => _dio.post<Map<String, dynamic>>(
      '/play/rooms/$code/start',
      data: {'first_player_id': firstPlayerId},
    ),
  );

  Future<Match> match(int matchId) =>
      _match(() => _dio.get<Map<String, dynamic>>('/play/matches/$matchId'));

  /// Remplace l'instantané du compteur (hôte). 409 si `version` est périmée.
  Future<Match> putState(
    int matchId, {
    required int version,
    required MatchState state,
  }) => _match(
    () => _dio.put<Map<String, dynamic>>(
      '/play/matches/$matchId/state',
      data: {'version': version, 'state': state.toJson()},
    ),
  );

  /// Clôture la partie (hôte) : le match passe en attente de confirmation.
  Future<Match> finish(
    int matchId, {
    required int winnerUserId,
    required Map<String, dynamic> result,
  }) => _match(
    () => _dio.post<Map<String, dynamic>>(
      '/play/matches/$matchId/finish',
      data: {'winner_user_id': winnerUserId, 'result': result},
    ),
  );

  Future<Match> confirm(int matchId) => _match(
    () => _dio.post<Map<String, dynamic>>('/play/matches/$matchId/confirm'),
  );

  Future<Match> dispute(int matchId) => _match(
    () => _dio.post<Map<String, dynamic>>('/play/matches/$matchId/dispute'),
  );

  /// Abandon : défaite de celui qui abandonne, sans confirmation.
  Future<Match> abandon(int matchId) => _match(
    () => _dio.post<Map<String, dynamic>>('/play/matches/$matchId/abandon'),
  );

  /// Mes matchs terminés, plus récents d'abord.
  Future<HistoryPage> history({int page = 1, int size = 20}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/play/history',
        queryParameters: {'page': page, 'size': size},
      );
      return HistoryPage.fromJson(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<PlayStats> stats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/play/stats');
      return PlayStats.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Mon salon actif et/ou mon match en cours (reprise).
  Future<CurrentPlay> current() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/play/current');
      return CurrentPlay.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Room> _room(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final response = await call();
      return Room.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Match> _match(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final response = await call();
      return Match.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Salon renvoyé par une action qui peut aussi répondre sans corps (204).
  static Room? _maybeRoom(Object? data) {
    if (data is! Map) return null;
    final json = data.cast<String, dynamic>();
    return json['code'] is String ? Room.fromJson(json) : null;
  }
}
