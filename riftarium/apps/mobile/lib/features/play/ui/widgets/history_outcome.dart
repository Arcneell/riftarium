import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Couleur de l'issue d'un match terminé : vert calme pour une victoire, rouge
/// fureur pour une défaite, gris muet pour un résultat contesté (il reste
/// visible mais ne compte nulle part).
///
/// Partagée par l'historique de mes parties et celui d'un profil public : les
/// deux écrans n'ont pas la même mise en page, mais le code couleur est le
/// même partout.
Color historyOutcomeColor(BuildContext context, String outcome) =>
    switch (outcome) {
      'win' => RiftColors.calm,
      'loss' => RiftColors.fury,
      _ => riftText(context).muted,
    };
