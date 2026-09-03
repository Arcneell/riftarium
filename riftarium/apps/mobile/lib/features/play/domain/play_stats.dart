import '../../game/domain/game_mode.dart';

/// Compteurs généraux (`StatsOut.totals`).
class PlayTotals {
  const PlayTotals({
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.winRate = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  factory PlayTotals.fromJson(Object? source) {
    final json = source is Map
        ? source.cast<String, dynamic>()
        : const <String, dynamic>{};
    return PlayTotals(
      played: _int(json['played']),
      won: _int(json['won']),
      lost: _int(json['lost']),
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      currentStreak: _int(json['current_streak']),
      bestStreak: _int(json['best_streak']),
    );
  }

  final int played;
  final int won;
  final int lost;

  /// Taux de victoire tel que l'API le renvoie : une fraction de 0 à 1
  /// (`round(won / played, 3)`, 0 s'il n'y a aucune partie).
  final double winRate;
  final int currentStreak;
  final int bestStreak;

  /// Ramené à l'intervalle 0–1 quelle que soit l'échelle reçue.
  double get winRatio {
    final rate = winRate > 1 ? winRate / 100 : winRate;
    if (rate > 0) return rate.clamp(0.0, 1.0);
    return played == 0 ? 0 : won / played;
  }

  String get winRateLabel => '${(winRatio * 100).round()} %';
}

/// Une ligne « par format » (`StatsOut.by_format`).
class FormatStat {
  const FormatStat({
    required this.mode,
    required this.played,
    required this.won,
    required this.lost,
  });

  factory FormatStat.fromJson(Map<String, dynamic> json) => FormatStat(
    mode: (json['mode'] as String?) ?? 'duel',
    played: _int(json['played']),
    won: _int(json['won']),
    lost: _int(json['lost']),
  );

  final String mode;
  final int played;
  final int won;
  final int lost;

  String get label => (GameMode.byId(mode) ?? GameMode.duel).label;
}

/// Une ligne « par deck » (`StatsOut.by_deck`).
class DeckStat {
  const DeckStat({
    required this.deckId,
    required this.name,
    required this.format,
    required this.played,
    required this.won,
    required this.lost,
    this.winRate = 0,
  });

  factory DeckStat.fromJson(Map<String, dynamic> json) => DeckStat(
    deckId: _int(json['deck_id']),
    name: (json['name'] as String?) ?? '',
    format: (json['format'] as String?) ?? 'tournament',
    played: _int(json['played']),
    won: _int(json['won']),
    lost: _int(json['lost']),
    winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
  );

  final int deckId;
  final String name;
  final String format;
  final int played;
  final int won;
  final int lost;
  final double winRate;

  double get winRatio {
    final rate = winRate > 1 ? winRate / 100 : winRate;
    if (rate > 0) return rate.clamp(0.0, 1.0);
    return played == 0 ? 0 : won / played;
  }
}

/// Une ligne « par légende » (`by_legend` et `by_opponent_legend`).
class LegendStat {
  const LegendStat({
    required this.cardId,
    required this.name,
    required this.played,
    required this.won,
    required this.lost,
    this.imageUrl,
  });

  factory LegendStat.fromJson(Map<String, dynamic> json) => LegendStat(
    cardId: (json['card_id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    imageUrl: json['image_url'] as String?,
    played: _int(json['played']),
    won: _int(json['won']),
    lost: _int(json['lost']),
  );

  final String cardId;
  final String name;
  final String? imageUrl;
  final int played;
  final int won;
  final int lost;

  double get winRatio => played == 0 ? 0 : won / played;
}

/// Un jour des trente derniers (`StatsOut.recent`).
class DayStat {
  const DayStat({required this.day, required this.played, required this.won});

  factory DayStat.fromJson(Map<String, dynamic> json) => DayStat(
    day: (json['day'] as String?) ?? '',
    played: _int(json['played']),
    won: _int(json['won']),
  );

  /// Jour au format ISO (`2026-08-27`).
  final String day;
  final int played;
  final int won;

  DateTime? get date => DateTime.tryParse(day);
}

/// Statistiques de mes parties suivies (`GET /api/play/stats`).
class PlayStats {
  const PlayStats({
    this.totals = const PlayTotals(),
    this.byFormat = const [],
    this.byDeck = const [],
    this.byLegend = const [],
    this.byOpponentLegend = const [],
    this.recent = const [],
  });

  factory PlayStats.fromJson(Map<String, dynamic> json) => PlayStats(
    totals: PlayTotals.fromJson(json['totals']),
    byFormat: _list(json['by_format'], FormatStat.fromJson),
    byDeck: _list(json['by_deck'], DeckStat.fromJson),
    byLegend: _list(json['by_legend'], LegendStat.fromJson),
    byOpponentLegend: _list(json['by_opponent_legend'], LegendStat.fromJson),
    recent: _list(json['recent'], DayStat.fromJson),
  );

  final PlayTotals totals;
  final List<FormatStat> byFormat;
  final List<DeckStat> byDeck;
  final List<LegendStat> byLegend;
  final List<LegendStat> byOpponentLegend;
  final List<DayStat> recent;

  bool get isEmpty => totals.played == 0;
}

List<T> _list<T>(Object? source, T Function(Map<String, dynamic>) build) =>
    (source as List? ?? const [])
        .whereType<Map>()
        .map((item) => build(item.cast<String, dynamic>()))
        .toList();

int _int(Object? value) => value is num ? value.toInt() : 0;
