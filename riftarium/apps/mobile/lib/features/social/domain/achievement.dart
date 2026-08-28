import 'package:flutter/material.dart';

import '../../../app/theme.dart';

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
    unlockedAt: DateTime.tryParse('${json['unlocked_at']}'),
  );

  /// Accepte la liste nue comme l'objet paginé `{items: [...]}`.
  static List<Achievement> listFrom(Object? source) {
    final list = source is Map ? source['items'] : source;
    return (list as List? ?? const [])
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

/// Dégradé du médaillon, ou null pour un aplat de [achievementTierColor].
Gradient? achievementTierGradient(String tier) => switch (tier) {
  'gold' => RiftColors.goldGradient,
  'prism' => RiftColors.prism,
  _ => null,
};

String achievementTierLabel(String tier) => switch (tier) {
  'silver' => 'Argent',
  'gold' => 'Or',
  'prism' => 'Prisme',
  _ => 'Bronze',
};

/// Icône d'un haut fait. Le catalogue vit côté API : on traduit son nom
/// Material en `IconData` (les icônes doivent être citées en dur pour survivre
/// au tree-shaking), avec un repli par famille si le nom n'est pas connu.
IconData achievementIcon(String icon, {String family = ''}) =>
    _icons[icon] ?? _familyIcons[family] ?? Icons.emoji_events_outlined;

const _familyIcons = <String, IconData>{
  'duels': Icons.sports_martial_arts,
  'collection': Icons.style,
  'decks': Icons.layers,
  'social': Icons.group,
};

const _icons = <String, IconData>{
  'directions_run': Icons.directions_run,
  'swords': Icons.sports_martial_arts,
  'architecture': Icons.architecture,
  'auto_awesome': Icons.auto_awesome,
  'auto_stories': Icons.auto_stories,
  'bolt': Icons.bolt,
  'bookmark': Icons.bookmark,
  'calendar_month': Icons.calendar_month,
  'casino': Icons.casino,
  'celebration': Icons.celebration,
  'collections_bookmark': Icons.collections_bookmark,
  'construction': Icons.construction,
  'diamond': Icons.diamond,
  'emoji_events': Icons.emoji_events,
  'event_repeat': Icons.event_repeat,
  'favorite': Icons.favorite,
  'flag': Icons.flag,
  'gavel': Icons.gavel,
  'grade': Icons.grade,
  'group': Icons.group,
  'groups': Icons.groups,
  'hexagon': Icons.hexagon,
  'history': Icons.history,
  'insights': Icons.insights,
  'inventory_2': Icons.inventory_2,
  'layers': Icons.layers,
  'local_fire_department': Icons.local_fire_department,
  'military_tech': Icons.military_tech,
  'palette': Icons.palette,
  'people': Icons.people,
  'person_add': Icons.person_add,
  'psychology': Icons.psychology,
  'public': Icons.public,
  'rocket_launch': Icons.rocket_launch,
  'shield': Icons.shield,
  'sports_esports': Icons.sports_esports,
  'sports_martial_arts': Icons.sports_martial_arts,
  'star': Icons.star,
  'stars': Icons.stars,
  'style': Icons.style,
  'thumb_up': Icons.thumb_up,
  'timeline': Icons.timeline,
  'today': Icons.today,
  'trending_up': Icons.trending_up,
  'verified': Icons.verified,
  'whatshot': Icons.whatshot,
  'workspace_premium': Icons.workspace_premium,
};
