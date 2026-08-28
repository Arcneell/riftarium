import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Message d'erreur d'une action de partie suivie : posé dans la page, il
/// n'interrompt rien (le sondage continue, l'action peut se retenter).
class PlayErrorBanner extends StatelessWidget {
  const PlayErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RiftColors.fury.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        border: Border.all(color: RiftColors.fury.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: RiftColors.fury),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: text.small)),
        ],
      ),
    );
  }
}
