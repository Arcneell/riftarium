import 'package:flutter/material.dart';

import '../theme.dart';

/// Champ de recherche en pilule, partagé par la cartothèque et la collection :
/// loupe en préfixe, croix d'effacement dès qu'il y a du texte, liseré hextech
/// au focus.
class RiftSearchField extends StatelessWidget {
  const RiftSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Jinx, ogn-202, réaction…',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final theme = Theme.of(context);
    final round = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RiftRadius.full),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        style: text.body,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          prefixIcon: Icon(Icons.search, size: 20, color: text.muted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  icon: Icon(Icons.close, size: 18, color: text.muted),
                  onPressed: controller.clear,
                ),
          border: round,
          enabledBorder: round,
          focusedBorder: round.copyWith(
            borderSide: const BorderSide(color: RiftColors.hex, width: 1.6),
          ),
        ),
      ),
    );
  }
}
