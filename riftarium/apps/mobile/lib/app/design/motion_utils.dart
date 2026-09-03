import 'package:flutter/widgets.dart';

/// Aides de mouvement : un seul endroit pour respecter le réglage
/// d'accessibilité « réduire les animations » (règle du système de design :
/// tout mouvement passe par ici).

/// Le système demande moins de mouvement.
bool riftReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Durée d'animation annulée en mouvement réduit.
Duration riftDuration(BuildContext context, Duration duration) =>
    riftReduceMotion(context) ? Duration.zero : duration;

/// Animation neutralisée (déjà terminée) en mouvement réduit : l'écran affiche
/// l'état final sans jouer la transition.
Animation<double> riftAnimation(
  BuildContext context,
  Animation<double> animation,
) => riftReduceMotion(context) ? kAlwaysCompleteAnimation : animation;
