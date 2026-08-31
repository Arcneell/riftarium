import 'package:flutter/widgets.dart';

/// Ancre du panneau de partage natif, à passer en `sharePositionOrigin`.
///
/// Sur iPad, la feuille de partage s'affiche en popover et le plugin
/// share_plus lève une exception si aucune origine n'est fournie ; sur iPhone
/// et Android, la valeur est simplement ignorée. Rect du widget appelant, ou
/// un point au centre de l'écran quand son rendu n'est pas mesurable.
Rect shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.attached) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
}
