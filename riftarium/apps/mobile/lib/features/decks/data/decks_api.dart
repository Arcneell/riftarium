import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/deck.dart';

final decksApiProvider = Provider<DecksApi>(
  (ref) => DecksApi(ref.watch(dioProvider)),
);

/// Filtres de `GET /api/community/decks` (mêmes noms que les paramètres).
class CommunityFilters {
  const CommunityFilters({
    this.query = '',
    this.legends = const [],
    this.domains = const [],
    this.formats = const [],
    this.sort = 'likes',
    this.liked = false,
    this.buildable = false,
  });

  final String query;
  final List<String> legends;
  final List<String> domains;
  final List<String> formats;

  /// `likes` (tendance), `views` (plus vus) ou `recent` (récents).
  final String sort;
  final bool liked;
  final bool buildable;

  int get activeCount =>
      (query.isEmpty ? 0 : 1) +
      (legends.isEmpty ? 0 : 1) +
      (domains.isEmpty ? 0 : 1) +
      (formats.isEmpty ? 0 : 1) +
      (liked ? 1 : 0) +
      (buildable ? 1 : 0);

  Map<String, dynamic> toQuery() => {
    if (query.isNotEmpty) 'q': query,
    if (legends.isNotEmpty) 'legend': legends.join(','),
    if (domains.isNotEmpty) 'domain': domains.join(','),
    if (formats.isNotEmpty) 'format': formats.join(','),
    'sort': sort,
    if (liked) 'liked': '1',
    if (buildable) 'buildable': '1',
  };

  CommunityFilters copyWith({
    String? query,
    List<String>? legends,
    List<String>? domains,
    List<String>? formats,
    String? sort,
    bool? liked,
    bool? buildable,
  }) => CommunityFilters(
    query: query ?? this.query,
    legends: legends ?? this.legends,
    domains: domains ?? this.domains,
    formats: formats ?? this.formats,
    sort: sort ?? this.sort,
    liked: liked ?? this.liked,
    buildable: buildable ?? this.buildable,
  );

  @override
  bool operator ==(Object other) =>
      other is CommunityFilters &&
      other.query == query &&
      other.sort == sort &&
      other.liked == liked &&
      other.buildable == buildable &&
      other.legends.join(',') == legends.join(',') &&
      other.domains.join(',') == domains.join(',') &&
      other.formats.join(',') == formats.join(',');

  @override
  int get hashCode => Object.hash(
    query,
    sort,
    liked,
    buildable,
    legends.join(','),
    domains.join(','),
    formats.join(','),
  );
}

/// Appels `/api/decks*` et `/api/community/*`.
class DecksApi {
  DecksApi(this._dio);

  final Dio _dio;

  /// Mes decks, du plus récemment modifié au plus ancien.
  Future<List<Deck>> mine() async {
    try {
      final response = await _dio.get<dynamic>('/decks/mine');
      return (response.data as List? ?? const [])
          .whereType<Map>()
          .map((item) => Deck.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Deck> get(int deckId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/decks/$deckId');
      return Deck.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Deck> create(DeckInput input) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/decks',
        data: input.toJson(),
      );
      return Deck.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Deck> update(int deckId, DeckInput input) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/decks/$deckId',
        data: input.toJson(),
      );
      return Deck.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<void> delete(int deckId) async {
    try {
      await _dio.delete<void>('/decks/$deckId');
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Copie privée d'un deck accessible, dans « Mes decks ».
  Future<Deck> copy(int deckId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/decks/$deckId/copy',
      );
      return Deck.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<DeckLikeResult> toggleLike(int deckId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/decks/$deckId/like',
      );
      return DeckLikeResult.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Compte une visite (le propriétaire n'est jamais compté).
  Future<int> recordView(int deckId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/decks/$deckId/view',
      );
      return ((response.data ?? const {})['views'] as num?)?.toInt() ?? 0;
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Liste d'achats du deck (propriétaire uniquement).
  Future<DeckMissing> missing(int deckId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/decks/$deckId/missing',
      );
      return DeckMissing.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<List<CommunityLegend>> communityLegends() async {
    try {
      final response = await _dio.get<dynamic>('/community/legends');
      return (response.data as List? ?? const [])
          .whereType<Map>()
          .map((item) => CommunityLegend.fromJson(item.cast<String, dynamic>()))
          .toList();
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<CommunityPage> communityDecks({
    CommunityFilters filters = const CommunityFilters(),
    int page = 1,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/community/decks',
        queryParameters: {...filters.toQuery(), 'page': page, 'size': size},
      );
      return CommunityPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}
