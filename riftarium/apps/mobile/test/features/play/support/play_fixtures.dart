import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/auth/domain/session.dart';

/// Faux serveur `/api/play/*`.
///
/// Variante locale de `test/support/fakes.dart` : le suivi des matchs a besoin
/// de réponses qui changent d'un appel à l'autre (409 puis 200 sur `PUT state`,
/// salon qui passe de `open` à `playing` entre deux battements de sondage).
class PlayFakeApi implements HttpClientAdapter {
  PlayFakeApi([Map<String, Object>? routes]) : routes = {...?routes};

  /// Clé : `MÉTHODE chemin`. Valeur : corps JSON, [PlayFakeError], ou
  /// [PlayFakeSequence] pour une suite de réponses.
  final Map<String, Object> routes;

  final List<PlayCall> calls = [];

  /// Remplace la réponse d'une route (le salon a changé entre deux sondages).
  void set(String key, Object value) => routes[key] = value;

  List<String> get paths =>
      calls.map((call) => '${call.method} ${call.path}').toList();

  Iterable<PlayCall> on(String method, String path) =>
      calls.where((call) => call.method == method && call.path == path);

  PlayCall? last(String method, String path) {
    final matching = on(method, path);
    return matching.isEmpty ? null : matching.last;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(PlayCall(options));
    var route = routes['${options.method} ${options.path}'];
    if (route is PlayFakeSequence) route = route.next();
    if (route is PlayFakeError) {
      return ResponseBody.fromString(
        jsonEncode({'detail': route.detail}),
        route.status,
        headers: _jsonHeaders,
      );
    }
    if (route == null) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Introuvable.'}),
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

/// Une requête reçue par le faux serveur.
class PlayCall {
  PlayCall(this.options);

  final RequestOptions options;

  String get method => options.method;
  String get path => options.path;
  Map<String, dynamic> get body =>
      (options.data as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get query => options.queryParameters;
}

/// Réponse d'erreur (409 sur une version périmée, 404 sur un salon inconnu).
class PlayFakeError {
  const PlayFakeError(this.status, this.detail);

  final int status;
  final String detail;
}

/// Réponses successives d'une même route ; la dernière se répète.
class PlayFakeSequence {
  PlayFakeSequence(this.items);

  final List<Object> items;
  int _index = 0;

  Object next() {
    final item = items[_index];
    if (_index < items.length - 1) _index++;
    return item;
  }
}

// --- Corps JSON ------------------------------------------------------------

/// Carte de légende minimale (`image_url` nul : pas de réseau dans les tests).
Map<String, dynamic> legendJson({
  String id = 'OGN-001',
  String name = 'Ahri',
  List<String> domains = const ['Mind'],
}) => {
  'id': id,
  'riftbound_id': id,
  'name': name,
  'set_id': 'OGN',
  'type': 'Legend',
  'rarity': 'Epic',
  'domains': domains,
  'tags': const <String>[],
  'collector_number': 1,
  'image_url': null,
};

Map<String, dynamic> playUserJson({int id = 7, String handle = 'ezreal'}) => {
  'id': id,
  'handle': handle,
  'avatar_url': null,
};

Map<String, dynamic> playDeckJson({
  int id = 3,
  String name = 'Ahri contrôle',
  String format = 'tournament',
}) => {'id': id, 'name': name, 'format': format};

/// Deck complet (`GET /api/decks/{id}`). Sa légende y figure telle qu'elle est
/// jouée : c'est cette carte-là (variante comprise) que le salon reprend.
Map<String, dynamic> deckJson({
  int id = 3,
  String name = 'Ahri contrôle',
  String format = 'tournament',
  Map<String, dynamic>? legend,
}) => {
  'id': id,
  'name': name,
  'description': null,
  'format': format,
  'is_public': false,
  'moderation_status': 'published',
  'likes': 0,
  'liked_by_me': false,
  'views': 0,
  'owner': 'ezreal',
  'owner_avatar': null,
  'card_count': 40,
  'cards': [
    {'card': legend ?? legendJson(id: 'OGN-001-alt'), 'qty': 1},
  ],
  'checks': const <Map<String, dynamic>>[],
  'prices': const <String, dynamic>{},
  'updated_at': null,
};

Map<String, dynamic> roomPlayerJson({
  int userId = 7,
  String handle = 'ezreal',
  int seat = 0,
  bool ready = false,
  Map<String, dynamic>? legend,
  Map<String, dynamic>? deck,
}) => {
  'user': playUserJson(id: userId, handle: handle),
  'seat': seat,
  'ready': ready,
  'legend': legend,
  'deck': deck,
};

Map<String, dynamic> roomJson({
  String code = 'ABC234',
  String mode = 'duel',
  String status = 'open',
  int hostId = 7,
  List<Map<String, dynamic>>? players,
  int? matchId,
  String? expiresAt,
  int version = 1,
}) => {
  'code': code,
  'mode': mode,
  'status': status,
  'host_id': hostId,
  'players': players ?? [roomPlayerJson()],
  'match_id': matchId,
  'expires_at': expiresAt ?? '2099-01-01T00:00:00Z',
  'version': version,
  'victory_score': 8,
  'rounds_to_win': mode == 'match' ? 2 : 1,
};

Map<String, dynamic> matchPlayerJson({
  int userId = 7,
  String handle = 'ezreal',
  int seat = 0,
  int score = 0,
  int roundsWon = 0,
  bool confirmed = false,
  Map<String, dynamic>? legend,
  Map<String, dynamic>? deck,
}) => {
  'user': playUserJson(id: userId, handle: handle),
  'seat': seat,
  'score': score,
  'rounds_won': roundsWon,
  'confirmed': confirmed,
  'legend': legend,
  'deck': deck,
};

Map<String, dynamic> matchStateJson({
  int round = 1,
  int turn = 1,
  int? activeUserId = 7,
  Map<String, int> scores = const {'7': 0, '8': 0},
  Map<String, int> xp = const {'7': 0, '8': 0},
  Map<String, int> roundsWon = const {'7': 0, '8': 0},
}) => {
  'round': round,
  'turn': turn,
  'active_user_id': activeUserId,
  'scores': scores,
  'xp': xp,
  'rounds_won': roundsWon,
};

Map<String, dynamic> matchJson({
  int id = 1,
  String mode = 'duel',
  String status = 'live',
  int hostId = 7,
  int firstPlayerId = 7,
  List<Map<String, dynamic>>? players,
  Map<String, dynamic>? state,
  int version = 3,
  int? winnerUserId,
  Map<String, dynamic>? result,
  String? roomCode = 'ABC234',
}) => {
  'id': id,
  'room_code': roomCode,
  'mode': mode,
  'status': status,
  'host_id': hostId,
  'first_player_id': firstPlayerId,
  'started_at': '2026-08-27T18:00:00Z',
  'ended_at': null,
  'winner_user_id': winnerUserId,
  'players':
      players ??
      [
        matchPlayerJson(seat: 0),
        matchPlayerJson(userId: 8, handle: 'jinx', seat: 1),
      ],
  'state': state ?? matchStateJson(),
  'result': result,
  'version': version,
};

Map<String, dynamic> historyItemJson({
  int matchId = 1,
  String mode = 'duel',
  String status = 'confirmed',
  String outcome = 'win',
  String handle = 'jinx',
  int myScore = 8,
  int opponentScore = 5,
  int myRounds = 1,
  int opponentRounds = 0,
  bool anonymousOpponent = false,
}) => {
  'match_id': matchId,
  'mode': mode,
  'status': status,
  'played_at': '2026-08-26T20:12:00Z',
  'opponent': anonymousOpponent ? null : playUserJson(id: 8, handle: handle),
  'my_legend': legendJson(),
  'opponent_legend': legendJson(id: 'OGN-002', name: 'Jinx'),
  'my_deck': playDeckJson(),
  'opponent_deck': playDeckJson(id: 9, name: 'Jinx agro', format: 'free'),
  'my_score': myScore,
  'opponent_score': opponentScore,
  'my_rounds': myRounds,
  'opponent_rounds': opponentRounds,
  'outcome': outcome,
};

Map<String, dynamic> historyPageJson({
  List<Map<String, dynamic>>? items,
  int? total,
}) {
  final list = items ?? [historyItemJson()];
  return {'total': total ?? list.length, 'page': 1, 'size': 50, 'items': list};
}

Map<String, dynamic> statsJson({int played = 10, int won = 6, int lost = 4}) =>
    {
      'totals': {
        'played': played,
        'won': won,
        'lost': lost,
        'win_rate': played == 0 ? 0 : won / played,
        'current_streak': 2,
        'best_streak': 4,
      },
      'by_format': [
        {'mode': 'duel', 'played': 7, 'won': 4, 'lost': 3},
        {'mode': 'match', 'played': 3, 'won': 2, 'lost': 1},
      ],
      'by_deck': [
        {
          'deck_id': 3,
          'name': 'Ahri contrôle',
          'format': 'tournament',
          'played': 6,
          'won': 4,
          'lost': 2,
          'win_rate': 0.6666,
        },
      ],
      'by_legend': [
        {
          'card_id': 'OGN-001',
          'name': 'Ahri',
          'image_url': null,
          'played': 6,
          'won': 4,
          'lost': 2,
        },
      ],
      'by_opponent_legend': [
        {
          'card_id': 'OGN-002',
          'name': 'Jinx',
          'image_url': null,
          'played': 5,
          'won': 3,
          'lost': 2,
        },
      ],
      'recent': [
        {'day': '2026-08-25', 'played': 2, 'won': 1},
        {'day': '2026-08-26', 'played': 3, 'won': 2},
        {'day': '2026-08-27', 'played': 0, 'won': 0},
      ],
    };

Map<String, dynamic> currentPlayJson({
  Map<String, dynamic>? room,
  Map<String, dynamic>? match,
}) => {'room': room, 'match': match};

// --- Session -------------------------------------------------------------

/// Compte de test : `id` 7, pseudo `ezreal`.
const testProfile = Profile(
  id: 7,
  handle: 'ezreal',
  bio: '',
  email: 'ezreal@piltover.re',
  emailVerified: true,
  isAdmin: false,
);

/// Session déjà ouverte, sans passer par `/auth/me` : les tests de partie
/// suivie n'ont rien à dire sur l'authentification.
class SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState.signedIn(profile: testProfile);
}
