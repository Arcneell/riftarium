import 'package:flutter/widgets.dart';

/// Charte Riftarium « Vitrine hextech », transposée de
/// `apps/web/src/assets/main.css` (`:root`). Nuit de Piltover en fond, laiton
/// pour la matière, sarcelle hextech pour les interactions, une couleur par
/// domaine de jeu. Les cartes sont la source de lumière, l'écrin reste sombre :
/// clair et sombre partagent donc les mêmes valeurs (les alias dark* restent
/// pour les écrans existants).
abstract final class RiftColors {
  // Fonds (nuit)
  static const paper = Color(0xFF0A1428);
  static const paper2 = Color(0xFF13233F);
  static const surface = Color(0xB813213B); // rgba(19,33,59,.72)
  /// Surface opaque des champs de saisie et fonds pleins (ex-parchemin clair).
  static const surfaceSolid = Color(0xFF101D33);
  // Filets laiton
  static const line = Color(0x29C9A75C); // rgba(201,167,92,.16)
  static const lineStrong = Color(0x66C9A75C); // rgba(201,167,92,.4)

  /// Nuit profonde : voiles, scrims et fonds d'écrans immersifs (l'ancien
  /// « inkStrong » du thème parchemin, qui désignait l'encre la plus sombre).
  static const night = Color(0xFF0A1428);

  // Texte : bleu-clair lunaire, champagne pour les titres
  static const ink = Color(0xFFD7E0EC);
  static const inkStrong = Color(0xFFF2EAD6);
  static const muted = Color(0xFF94A3B9);

  // Laiton : goldDeep sert aux liens et intertitres (clair sur nuit)
  static const gold = Color(0xFFC9A75C);
  static const goldDeep = Color(0xFFDCC07E);
  static const goldSoft = Color(0xFFD9BD82);
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD9BD82), Color(0xFFB08A3E), Color(0xFF8A6A2F)],
    stops: [0, 0.55, 1],
  );

  // Hex (interactions, liens, focus) et fond des états « activé »
  static const hex = Color(0xFF35E0D0);
  static const hexSoft = Color(0xFF143C3F);

  // Domaines de jeu (pastilles) et variantes texte (contraste ≥ 4.5 sur nuit)
  static const fury = Color(0xFFCF4437);
  static const calm = Color(0xFF178F7F);
  static const mind = Color(0xFF7355CF);
  static const body = Color(0xFF3F8F50);
  static const chaos = Color(0xFFC2439B);
  static const order = Color(0xFFAB7C1A);
  static const furyText = Color(0xFFF0705F);
  static const calmText = Color(0xFF3ECFBB);
  static const mindText = Color(0xFFA68DF5);
  static const bodyText = Color(0xFF6CC47E);
  static const chaosText = Color(0xFFE77AC4);
  static const orderText = Color(0xFFD9A94E);

  /// Arc-en-ciel des six domaines (barres de progression, séparateurs).
  static const prism = LinearGradient(
    colors: [fury, order, body, calm, mind, chaos],
  );

  // Alias historiques du mode sombre : mêmes valeurs que le thème unique.
  static const darkPaper = paper;
  static const darkPaper2 = paper2;
  static const darkSurface = surface;
  static const darkLine = line;
  static const darkInk = ink;
  static const darkMuted = muted;

  static Color domain(String name) => switch (name.toLowerCase()) {
    'fury' || 'fureur' => fury,
    'calm' || 'calme' => calm,
    'mind' || 'esprit' => mind,
    'body' || 'corps' => body,
    'chaos' => chaos,
    'order' || 'ordre' => order,
    _ => muted,
  };

  static Color domainText(String name) => switch (name.toLowerCase()) {
    'fury' || 'fureur' => furyText,
    'calm' || 'calme' => calmText,
    'mind' || 'esprit' => mindText,
    'body' || 'corps' => bodyText,
    'chaos' => chaosText,
    'order' || 'ordre' => orderText,
    _ => muted,
  };
}

abstract final class RiftRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 28.0;
  static const card = 10.0;
  static const full = 999.0;
}

abstract final class RiftShadows {
  static const soft = [
    BoxShadow(color: Color(0x61020610), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x80020610), blurRadius: 40, offset: Offset(0, 16)),
  ];
  static const glowGold = [
    BoxShadow(color: Color(0x3DC9A75C), blurRadius: 30, offset: Offset(0, 10)),
  ];
}

/// Rythme des mouvements : rapide pour le retour d'action, lent pour l'ambiance.
abstract final class RiftMotion {
  static const quick = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
  static const foil = Duration(seconds: 7);
  static const ease = Curves.easeOutCubic;
  static const easeIn = Curves.easeInOutCubic;

  /// Décalage entre deux éléments d'une liste qui se révèle.
  static const stagger = Duration(milliseconds: 45);
}

abstract final class RiftSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const page = EdgeInsets.symmetric(horizontal: 18);
}
