import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import 'adaptive.dart';

/// Ouvre une page du site (CGU, confidentialité, mentions légales) dans le
/// navigateur. Si le système ne sait pas la prendre en charge, l'adresse est
/// montrée en clair plutôt que perdue.
Future<void> openWebPage(BuildContext context, String path) async {
  final uri = Uri.parse('${AppConfig.webBaseUrl}$path');
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    await showAdaptiveMessage(
      context,
      title: 'Ouverture impossible',
      message: uri.toString(),
    );
  }
}
