import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';

/// Empile un écran dans la pile de l'onglet « Règles » (une seule route
/// go_router : chapitres, sections et renvois restent dans cet onglet).
Future<void> pushAdaptiveScreen(BuildContext context, WidgetBuilder builder) {
  final route = isCupertino(context)
      ? CupertinoPageRoute<void>(builder: builder)
      : MaterialPageRoute<void>(builder: builder);
  return Navigator.of(context).push(route);
}
