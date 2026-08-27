import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Champ de recherche des règles : pilule parchemin, loupe, croix d'effacement.
/// Le même sur le hub, l'aide avancée et le texte officiel.
class RulesSearchField extends StatelessWidget {
  const RulesSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.label,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;

  /// Libellé lu par les lecteurs d'écran (le champ n'a pas d'étiquette
  /// visible : la loupe et l'exemple suffisent à l'œil).
  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Semantics(
      textField: true,
      label: label,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          style: text.body,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RiftRadius.full),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RiftRadius.full),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RiftRadius.full),
              borderSide: const BorderSide(color: RiftColors.hex, width: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}
