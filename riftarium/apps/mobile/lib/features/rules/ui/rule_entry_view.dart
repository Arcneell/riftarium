import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/rules.dart';

/// Rendu d'une règle : numéro doré, indentation selon `depth`, texte
/// sélectionnable, exemples en encart et renvois cliquables.
class RuleEntryView extends StatelessWidget {
  const RuleEntryView({
    super.key,
    required this.entry,
    this.highlighted = false,
    this.onFollowReference,
  });

  final RuleEntry entry;

  /// Règle atteinte par une recherche ou un renvoi : fond mis en évidence.
  final bool highlighted;

  final ValueChanged<RuleReference>? onFollowReference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    return Container(
      margin: EdgeInsets.fromLTRB(
        12 + math.min(math.max(entry.depth, 0), 4) * 14.0,
        4,
        12,
        4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: highlighted
          ? BoxDecoration(
              color: kRiftariumGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kRiftariumGold.withValues(alpha: 0.5)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${entry.number} ',
                  style: body?.copyWith(
                    color: kRiftariumGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: entry.text, style: body),
              ],
            ),
          ),
          for (final example in entry.examples) _ExampleBox(text: example.text),
          if (entry.refs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reference in entry.refs)
                    _ReferenceChip(
                      reference: reference,
                      onTap: onFollowReference == null
                          ? null
                          : () => onFollowReference!(reference),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExampleBox extends StatelessWidget {
  const _ExampleBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          left: BorderSide(
            color: kRiftariumGold.withValues(alpha: 0.7),
            width: 3,
          ),
        ),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exemple',
            style: theme.textTheme.labelMedium?.copyWith(
              color: kRiftariumGold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.reference, this.onTap});

  final RuleReference reference;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: kRiftariumGold.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '→ ${reference.number} ${reference.label}',
          style: theme.textTheme.labelMedium?.copyWith(color: kRiftariumGold),
        ),
      ),
    );
  }
}
