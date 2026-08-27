import 'package:flutter/widgets.dart';

/// Charte Riftarium, transposée de `apps/web/src/assets/main.css` (`:root`).
/// Parchemin et encre bleu nuit, or comme accent, hex (sarcelle) pour les
/// interactions, une couleur par domaine de jeu.
abstract final class RiftColors {
  // Fonds
  static const paper = Color(0xFFF5EFE1);
  static const paper2 = Color(0xFFEDE4CF);
  static const surface = Color(0xD1FDFAF2); // rgba(253,250,242,.82)
  static const line = Color(0x338A6A2F); // rgba(138,106,47,.2)
  static const lineStrong = Color(0x738A6A2F); // rgba(138,106,47,.45)

  // Encre
  static const ink = Color(0xFF16283A);
  static const inkStrong = Color(0xFF0A1428);
  static const muted = Color(0xFF6B6450);

  // Or
  static const gold = Color(0xFFB08A3E);
  static const goldDeep = Color(0xFF7A5D28);
  static const goldSoft = Color(0xFFD9BD82);
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9A75C), Color(0xFFA98338), Color(0xFF8A6A2F)],
    stops: [0, 0.55, 1],
  );

  // Hex (interactions, liens, focus)
  static const hex = Color(0xFF0B8F84);
  static const hexSoft = Color(0xFFD7F2EF);

  // Domaines de jeu (pastilles) et variantes texte (contraste ≥ 4.5 sur parchemin)
  static const fury = Color(0xFFCF4437);
  static const calm = Color(0xFF178F7F);
  static const mind = Color(0xFF7355CF);
  static const body = Color(0xFF3F8F50);
  static const chaos = Color(0xFFC2439B);
  static const order = Color(0xFFAB7C1A);
  static const furyText = Color(0xFFC03A2E);
  static const calmText = Color(0xFF10756A);
  static const mindText = Color(0xFF7355CF);
  static const bodyText = Color(0xFF2F7340);
  static const chaosText = Color(0xFFB0348A);
  static const orderText = Color(0xFF8A641A);

  /// Arc-en-ciel des six domaines (barres de progression, séparateurs).
  static const prism = LinearGradient(
    colors: [fury, order, body, calm, mind, chaos],
  );

  // Mode sombre : encre en fond, parchemin en texte, or inchangé.
  static const darkPaper = Color(0xFF0E1826);
  static const darkPaper2 = Color(0xFF15233A);
  static const darkSurface = Color(0xCC1A2B45);
  static const darkLine = Color(0x40D9BD82);
  static const darkInk = Color(0xFFF1EADB);
  static const darkMuted = Color(0xFFB7AD98);

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
    BoxShadow(color: Color(0x1A4A3816), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x244A3816), blurRadius: 40, offset: Offset(0, 16)),
  ];
  static const glowGold = [
    BoxShadow(color: Color(0x478A6A2F), blurRadius: 30, offset: Offset(0, 10)),
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
