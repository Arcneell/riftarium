import 'package:flutter/painting.dart';

import '../../../app/design/tokens.dart';
import '../../cards/domain/card.dart';
import 'card_codec.dart';

/// Un joueur autour de la table : un nom, éventuellement une légende, un siège
/// (sa place dans la disposition) et un camp (son équipe en 2c2, lui-même
/// ailleurs).
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.seat,
    required this.team,
    this.legend,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: (json['id'] as String?) ?? 'p${json['seat']}',
    name: (json['name'] as String?) ?? '',
    seat: (json['seat'] as num?)?.toInt() ?? 0,
    team: (json['team'] as num?)?.toInt() ?? 0,
    legend: cardFromJson(json['legend']),
  );

  final String id;
  final String name;
  final int seat;
  final int team;
  final RiftCard? legend;

  /// Couleurs de repli quand le joueur n'a pas choisi de légende : une par
  /// camp, l'or d'abord (en 2c2 : équipe A en or, équipe B en sarcelle).
  static const fallbackColors = [
    RiftColors.gold,
    RiftColors.hex,
    RiftColors.chaos,
    RiftColors.body,
  ];

  /// Couleur du panneau : le premier domaine de la légende, sinon le camp.
  Color get color {
    final domains = legend?.domains ?? const <String>[];
    if (domains.isNotEmpty) {
      final color = RiftColors.domain(domains.first);
      if (color != RiftColors.muted) return color;
    }
    return fallbackColors[team % fallbackColors.length];
  }

  Player copyWith({
    String? name,
    int? team,
    RiftCard? legend,
    bool clearLegend = false,
  }) => Player(
    id: id,
    name: name ?? this.name,
    seat: seat,
    team: team ?? this.team,
    legend: clearLegend ? null : (legend ?? this.legend),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seat': seat,
    'team': team,
    'legend': legend == null ? null : cardToJson(legend!),
  };
}
