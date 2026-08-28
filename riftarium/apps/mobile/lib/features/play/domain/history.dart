import '../../cards/domain/card.dart';
import '../../game/domain/card_codec.dart';
import '../../game/domain/game_mode.dart';
import 'room.dart';

/// Une ligne de `GET /api/play/history` : un match terminé, vu de mon côté.
class HistoryItem {
  const HistoryItem({
    required this.matchId,
    required this.mode,
    required this.status,
    required this.outcome,
    required this.myScore,
    required this.opponentScore,
    required this.myRounds,
    required this.opponentRounds,
    this.playedAt,
    this.opponent,
    this.myLegend,
    this.opponentLegend,
    this.myDeck,
    this.opponentDeck,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    matchId: (json['match_id'] as num?)?.toInt() ?? 0,
    mode: (json['mode'] as String?) ?? 'duel',
    status: (json['status'] as String?) ?? 'confirmed',
    outcome: (json['outcome'] as String?) ?? 'disputed',
    playedAt: DateTime.tryParse('${json['played_at']}'),
    opponent: PlayUser.maybe(json['opponent']),
    myLegend: cardFromJson(json['my_legend']),
    opponentLegend: cardFromJson(json['opponent_legend']),
    myDeck: PlayDeck.maybe(json['my_deck']),
    opponentDeck: PlayDeck.maybe(json['opponent_deck']),
    myScore: (json['my_score'] as num?)?.toInt() ?? 0,
    opponentScore: (json['opponent_score'] as num?)?.toInt() ?? 0,
    myRounds: (json['my_rounds'] as num?)?.toInt() ?? 0,
    opponentRounds: (json['opponent_rounds'] as num?)?.toInt() ?? 0,
  );

  final int matchId;
  final String mode;

  /// `confirmed`, `disputed` ou `abandoned`.
  final String status;

  /// `win`, `loss` ou `disputed` (exclu des statistiques).
  final String outcome;
  final DateTime? playedAt;

  /// Null quand l'adversaire a supprimé son compte.
  final PlayUser? opponent;
  final RiftCard? myLegend;
  final RiftCard? opponentLegend;
  final PlayDeck? myDeck;
  final PlayDeck? opponentDeck;
  final int myScore;
  final int opponentScore;
  final int myRounds;
  final int opponentRounds;

  bool get isWin => outcome == 'win';
  bool get isLoss => outcome == 'loss';
  bool get isDisputed => outcome == 'disputed';

  GameMode get gameMode => GameMode.byId(mode) ?? GameMode.duel;

  String get modeLabel => gameMode.label;

  String get outcomeLabel => switch (outcome) {
    'win' => 'Victoire',
    'loss' => 'Défaite',
    _ => 'Contesté',
  };

  /// Score affiché : les manches en mode `match`, les points sinon.
  String get scoreLabel => gameMode.roundsToWin > 1
      ? '$myRounds – $opponentRounds'
      : '$myScore – $opponentScore';

  Map<String, dynamic> toJson() => {
    'match_id': matchId,
    'mode': mode,
    'status': status,
    'outcome': outcome,
    'played_at': playedAt?.toIso8601String(),
    'opponent': opponent?.toJson(),
    'my_legend': myLegend == null ? null : cardToJson(myLegend!),
    'opponent_legend': opponentLegend == null
        ? null
        : cardToJson(opponentLegend!),
    'my_deck': myDeck?.toJson(),
    'opponent_deck': opponentDeck?.toJson(),
    'my_score': myScore,
    'opponent_score': opponentScore,
    'my_rounds': myRounds,
    'opponent_rounds': opponentRounds,
  };
}

/// Page d'historique : `{total, page, size, items}` (`size` ≤ 50). Une liste
/// nue est acceptée par tolérance, mais l'API renvoie bien l'objet paginé.
class HistoryPage {
  const HistoryPage({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.size = 20,
  });

  factory HistoryPage.fromJson(Object? source) {
    if (source is List) {
      final items = source
          .whereType<Map>()
          .map((item) => HistoryItem.fromJson(item.cast<String, dynamic>()))
          .toList();
      return HistoryPage(items: items, total: items.length, size: items.length);
    }
    final json = source is Map
        ? source.cast<String, dynamic>()
        : const <String, dynamic>{};
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => HistoryItem.fromJson(item.cast<String, dynamic>()))
        .toList();
    return HistoryPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? items.length,
    );
  }

  final List<HistoryItem> items;
  final int total;
  final int page;
  final int size;

  bool get hasMore => items.length < total && items.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'total': total,
    'page': page,
    'size': size,
    'items': items.map((item) => item.toJson()).toList(),
  };
}
