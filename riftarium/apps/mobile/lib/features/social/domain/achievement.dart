import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'api_date.dart';

/// Familles du catalogue (`docs/profils-et-hauts-faits.md`), dans l'ordre
/// d'affichage. Une famille inconnue est rangée à la fin, telle quelle.
const achievementFamilies = <String>['duels', 'collection', 'decks', 'social'];

const _familyLabels = <String, String>{
  'duels': 'Duels',
  'collection': 'Collection',
  'decks': 'Decks',
  'social': 'Social',
};

String achievementFamilyLabel(String family) => _familyLabels[family] ?? family;

/// Un haut fait, débloqué ou non (`GET /api/me/achievements`, et la liste
/// réduite aux débloqués d'un profil public).
class Achievement {
  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    required this.family,
    required this.threshold,
    required this.current,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    key: (json['key'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    icon: (json['icon'] as String?) ?? '',
    tier: (json['tier'] as String?) ?? 'bronze',
    family: (json['family'] as String?) ?? '',
    threshold: (json['threshold'] as num?)?.toInt() ?? 1,
    current: (json['current'] as num?)?.toInt() ?? 0,
    unlockedAt: parseApiDate(json['unlocked_at']),
  );

  /// Accepte la liste nue comme l'objet paginé `{items: [...]}`.
  static List<Achievement> listFrom(Object? source) {
    final list = source is Map ? source['items'] : source;
    return list is! List
        ? const []
        : list
              .whereType<Map>()
              .map((item) => Achievement.fromJson(item.cast<String, dynamic>()))
              .toList();
  }

  final String key;
  final String title;
  final String description;

  /// Nom d'icône Material partagé avec le site (`military_tech`…).
  final String icon;

  /// `bronze`, `silver`, `gold` ou `prism`.
  final String tier;
  final String family;
  final int threshold;

  /// Valeur atteinte de la métrique (progression = `current / threshold`).
  final int current;
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;

  double get progress {
    if (isUnlocked || threshold <= 0) return 1;
    return (current / threshold).clamp(0.0, 1.0);
  }

  /// `3 / 10` : la progression telle qu'on la lit sous la barre.
  String get progressLabel => '$current / $threshold';
}

/// Couleur d'un palier, prise dans la charte : bronze = or profond, argent =
/// gris muet, or = or, prisme = violet d'Esprit (le dégradé prismatique porte
/// alors le médaillon).
Color achievementTierColor(String tier) => switch (tier) {
  'silver' => RiftColors.muted,
  'gold' => RiftColors.gold,
  'prism' => RiftColors.mind,
  _ => RiftColors.goldDeep,
};

String achievementTierLabel(String tier) => switch (tier) {
  'silver' => 'Argent',
  'gold' => 'Or',
  'prism' => 'Prisme',
  _ => 'Bronze',
};

/* L'icône d'un haut fait est un tracé SVG unique par clé du catalogue :
   voir ui/widgets/achievement_icons.dart (rendu par AchievementMedallion). */
