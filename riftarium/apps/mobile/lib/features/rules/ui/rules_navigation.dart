import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';

/// Empile un écran dans la pile de l'onglet « Règles » (chapitres, sections
/// et renvois du texte officiel restent dans cet onglet).
Future<void> pushAdaptiveScreen(BuildContext context, WidgetBuilder builder) {
  final route = isCupertino(context)
      ? CupertinoPageRoute<void>(builder: builder)
      : MaterialPageRoute<void>(builder: builder);
  return Navigator.of(context).push(route);
}

/// Retour depuis un écran de règles : la pile quand il y en a une, sinon le
/// hub (les paliers sont atteints par `context.go`, sans empilement).
void goBackToRules(BuildContext context, {String fallback = AppRoutes.rules}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}

/// Bouton de retour des écrans de règles, posé dans la bannière.
class RulesBackButton extends StatelessWidget {
  const RulesBackButton({super.key, this.fallback = AppRoutes.rules});

  final String fallback;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Retour',
    icon: const Icon(Icons.arrow_back),
    onPressed: () => goBackToRules(context, fallback: fallback),
  );
}

/// Nombre lisible : `2137` → « 2 137 », comme sur le site.
String formatRuleCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
