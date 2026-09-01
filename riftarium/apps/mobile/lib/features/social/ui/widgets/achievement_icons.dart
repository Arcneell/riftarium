/// Icônes gravées des hauts faits : un dessin unique par haut fait, clé du
/// catalogue de l'API (`apps/api/app/achievements.py`). Tracés 24×24 au trait,
/// pensés pour rester lisibles à 18 px dans la gemme. Les séries (Habitué →
/// Pilier, Vainqueur → Légende…) gardent un motif commun qui s'enrichit avec
/// le palier.
///
/// Miroir JavaScript : `apps/web/src/achievementIcons.js` — toute modification
/// se reporte des deux côtés.
library;

const _icons = <String, List<String>>{
  // ---- Duels ----
  // Premier sang : dague et goutte.
  'first_blood': [
    'M11 3.5 L13 8 L11 16.5 L9 8 Z',
    'M7.8 9.5 H14.2',
    'M11 16.5 V20',
    'M17.3 12 C18.9 14.3 18.8 16.2 17.3 16.2 '
        'C15.8 16.2 15.7 14.3 17.3 12 Z',
  ],
  // Habitué : écu nu.
  'veteran_10': [
    'M12 3.5 L18.8 6 V11 C18.8 15.4 16 18.9 12 20.8 '
        'C8 18.9 5.2 15.4 5.2 11 V6 Z',
  ],
  // Vétéran : écu au chevron.
  'veteran_50': [
    'M12 3.5 L18.8 6 V11 C18.8 15.4 16 18.9 12 20.8 '
        'C8 18.9 5.2 15.4 5.2 11 V6 Z',
    'M8.6 10.2 L12 13.2 L15.4 10.2',
  ],
  // Pilier : colonne, chapiteau et socle.
  'veteran_200': [
    'M6 4.5 H18',
    'M7.2 7 H16.8',
    'M9 7 V17 M12 7 V17 M15 7 V17',
    'M7.2 17 H16.8',
    'M6 19.5 H18',
  ],
  // Vainqueur : deux branches de laurier.
  'winner_10': [
    'M9.4 4.5 C5.8 8.4 5.3 14.4 8.2 19.3',
    'M6.4 9.6 L8.6 10.4 M6 13 L8.4 13.2 M6.9 16.4 L9 15.8',
    'M14.6 4.5 C18.2 8.4 18.7 14.4 15.8 19.3',
    'M17.6 9.6 L15.4 10.4 M18 13 L15.6 13.2 M17.1 16.4 L15 15.8',
  ],
  // Champion : coupe à anses.
  'winner_50': [
    'M7.2 4.8 H16.8 V9 C16.8 12 14.8 14 12 14 C9.2 14 7.2 12 7.2 9 Z',
    'M7.2 6.2 H4.6 C4.6 9.2 5.7 10.9 7.6 11.2',
    'M16.8 6.2 H19.4 C19.4 9.2 18.3 10.9 16.4 11.2',
    'M12 14 V17.4',
    'M8.6 19.8 H15.4',
  ],
  // Légende : couronne.
  'winner_100': [
    'M5.2 16.6 V8 L9 11.2 L12 5.6 L15 11.2 L18.8 8 V16.6 Z',
    'M5.2 19.2 H18.8',
  ],
  // Sur sa lancée : une flamme.
  'streak_3': [
    'M12 4 C15.4 8 16.8 11 16.8 13.9 A4.8 4.8 0 0 1 7.2 13.9 '
        'C7.2 11 8.6 8 12 4 Z',
  ],
  // En feu : la flamme et son cœur.
  'streak_5': [
    'M12 4 C15.4 8 16.8 11 16.8 13.9 A4.8 4.8 0 0 1 7.2 13.9 '
        'C7.2 11 8.6 8 12 4 Z',
    'M12 10.8 C13.5 12.7 14 13.9 14 14.9 A2 2 0 0 1 10 14.9 '
        'C10 13.9 10.5 12.7 12 10.8 Z',
  ],
  // Invaincu : le brasier, trois flammes.
  'streak_10': [
    'M12 3.5 C14.7 6.9 15.9 9.6 15.9 12.2 A3.9 3.9 0 0 1 8.1 12.2 '
        'C8.1 9.6 9.3 6.9 12 3.5 Z',
    'M5.9 12.3 C7.2 13.9 7.7 15.1 7.7 16.2 A1.9 1.9 0 0 1 3.9 16.2 '
        'C3.9 15 4.5 13.7 5.9 12.3 Z',
    'M18.1 12.3 C19.5 13.7 20.1 15 20.1 16.2 A1.9 1.9 0 0 1 16.3 16.2 '
        'C16.3 15.1 16.8 13.9 18.1 12.3 Z',
  ],
  // Les six domaines : gemme hex aux six facettes.
  'six_domains': [
    'M12 3.2 L19.6 7.6 V16.4 L12 20.8 L4.4 16.4 V7.6 Z',
    'M12 12 V6.6 M12 12 L16.7 9.3 M12 12 L16.7 14.7 '
        'M12 12 V17.4 M12 12 L7.3 14.7 M12 12 L7.3 9.3',
  ],
  // Tueur de géants : la grande épée croise la courte.
  'giant_slayer': [
    'M4.8 19.6 L17.2 7.2',
    'M14.9 4.9 L19.5 9.5',
    'M19.2 19.6 L13.8 14.2',
    'M12.6 17 L16.4 20.8',
  ],
  // Marathon : le fanion d'arrivée.
  'marathon': [
    'M7 4 V20.5',
    'M7 4.6 H18 L15.4 8 L18 11.4 H7',
    'M11 4.6 V11.4',
    'M7 8 H15.4',
  ],

  // ---- Collection ----
  // Collectionneur : une carte.
  'collector_100': [
    'M8 4.5 H16 A1.5 1.5 0 0 1 17.5 6 V18 A1.5 1.5 0 0 1 16 19.5 H8 '
        'A1.5 1.5 0 0 1 6.5 18 V6 A1.5 1.5 0 0 1 8 4.5 Z',
    'M6.5 14.5 H17.5',
    'M9.3 17 H12.5',
  ],
  // Grand collectionneur : deux cartes en éventail.
  'collector_500': [
    'M9.8 7.6 L5.2 9.4 L9 19.2 L13.6 17.4',
    'M9.8 5.2 H17.2 A1.3 1.3 0 0 1 18.5 6.5 V16.7 '
        'A1.3 1.3 0 0 1 17.2 18 H11.1 A1.3 1.3 0 0 1 9.8 16.7 Z',
  ],
  // Conservateur : trois cartes en éventail.
  'collector_1000': [
    'M8.8 7.4 L4.6 9 L8 18.2',
    'M15.2 7.4 L19.4 9 L16 18.2',
    'M8.8 5.5 H15.2 V17.8 H8.8 Z',
    'M10.8 8.4 H13.2',
  ],
  // Set complet : la grille pleine.
  'set_complete': [
    'M5 5 H19 V19 H5 Z',
    'M5 9.7 H19 M5 14.3 H19',
    'M9.7 5 V19 M14.3 5 V19',
  ],
  // Vitrine : le scintillement showcase.
  'showcase_10': [
    'M12 4.5 C12.6 8.3 14.7 10.9 18.5 11.5 C14.7 12.1 12.6 14.7 12 18.5 '
        'C11.4 14.7 9.3 12.1 5.5 11.5 C9.3 10.9 11.4 8.3 12 4.5 Z',
    'M18.4 16.4 V19.4 M16.9 17.9 H19.9',
    'M5.8 4.6 V7.2 M4.5 5.9 H7.1',
  ],

  // ---- Decks ----
  // Architecte : le compas.
  'architect_1': [
    'M12 3 m-1.6 0 a1.6 1.6 0 1 0 3.2 0 a1.6 1.6 0 1 0 -3.2 0',
    'M11 4.4 L6.6 19.4',
    'M13 4.4 L17.4 19.4',
    'M8.2 14.6 A7.6 7.6 0 0 0 15.8 14.6',
  ],
  // Bâtisseur : le plan déroulé.
  'architect_5': [
    'M5.5 6.5 C7 5.4 8.2 5.4 9.7 6.5 V17.5 C8.2 16.4 7 16.4 5.5 17.5 Z',
    'M9.7 6.5 H18.5 V17.5 H9.7',
    'M12.2 9.6 H16 M12.2 12 H16 M12.2 14.4 H14.2',
  ],
  // Maître d'œuvre : la tour crénelée.
  'architect_20': [
    'M7 20.5 V8.6 H8.9 V6.2 H10.7 V8.6 H13.3 V6.2 H15.1 V8.6 H17 V20.5',
    'M10.4 20.5 V15.8 A1.6 2 0 0 1 13.6 15.8 V20.5',
    'M5.4 20.5 H18.6',
  ],
  // Coup de cœur : le cœur acclamé.
  'crowd_favorite': [
    'M12 19 C7.2 15.2 4.8 12 4.8 9.2 A3.7 3.7 0 0 1 12 7.6 '
        'A3.7 3.7 0 0 1 19.2 9.2 C19.2 12 16.8 15.2 12 19 Z',
    'M18.9 3.8 V6.4 M17.6 5.1 H20.2',
  ],
  // Dans les règles : la liste vérifiée.
  'legal_eagle': [
    'M6.5 4 H15.5 L17.5 6 V20 H6.5 Z',
    'M15.5 4 V6 H17.5',
    'M9.4 13.6 L11.4 15.6 L15 11.4',
  ],

  // ---- Social ----
  // Sociable : deux compagnons.
  'sociable_5': [
    'M9 5.8 m-2.3 0 a2.3 2.3 0 1 0 4.6 0 a2.3 2.3 0 1 0 -4.6 0',
    'M4.6 19 C4.6 15.6 6.6 13.7 9 13.7 C11.4 13.7 13.4 15.6 13.4 19',
    'M16 8 m-1.9 0 a1.9 1.9 0 1 0 3.8 0 a1.9 1.9 0 1 0 -3.8 0',
    'M15 13.9 C17.5 13.5 19.4 15.3 19.6 18.2',
  ],
  // Fidèle au poste : le calendrier étoilé.
  'regular': [
    'M4.8 6.5 H19.2 V20 H4.8 Z',
    'M4.8 10 H19.2',
    'M8.5 4 V8 M15.5 4 V8',
    'M12 11.8 L13 14 L15.4 14.3 L13.7 15.9 L14.1 18.2 L12 17.1 '
        'L9.9 18.2 L10.3 15.9 L8.6 14.3 L11 14 Z',
  ],
};

/// Repli par nom d'icône Material (haut fait ajouté à l'API avant son dessin).
const _byMaterialIcon = <String, String>{
  'military_tech': 'first_blood',
  'shield': 'veteran_10',
  'emoji_events': 'winner_50',
  'local_fire_department': 'streak_3',
  'hexagon': 'six_domains',
  'swords': 'giant_slayer',
  'sports_martial_arts': 'giant_slayer',
  'directions_run': 'marathon',
  'style': 'collector_100',
  'inventory_2': 'set_complete',
  'auto_awesome': 'showcase_10',
  'architecture': 'architect_1',
  'favorite': 'crowd_favorite',
  'verified': 'legal_eagle',
  'group': 'sociable_5',
  'groups': 'sociable_5',
  'person_add': 'sociable_5',
  'calendar_month': 'regular',
  'event_repeat': 'regular',
};

/// Étoile : repli quand ni la clé ni l'icône ne sont connues.
const _fallback = [
  'M12 3.5 L14.4 8.9 L20.2 9.5 L15.9 13.4 L17.2 19.2 L12 16.2 '
      'L6.8 19.2 L8.1 13.4 L3.8 9.5 L9.6 8.9 Z',
];

/// Document SVG de l'icône d'un haut fait, à teinter via `colorFilter`.
String achievementIconSvg(String key, String icon) {
  final paths = _icons[key] ?? _icons[_byMaterialIcon[icon]] ?? _fallback;
  final body = paths.map((d) => '<path d="$d"/>').join();
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="#ffffff" stroke-width="1.7" '
      'stroke-linecap="round" stroke-linejoin="round">$body</svg>';
}
