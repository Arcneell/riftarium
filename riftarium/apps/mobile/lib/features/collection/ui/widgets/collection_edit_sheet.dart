import 'package:flutter/cupertino.dart' show showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/adaptive.dart';
import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../../../core/api_exception.dart';
import '../../../cards/domain/card_labels.dart';
import '../../application/collection_controller.dart';
import '../../domain/collection.dart';
import 'quantity_stepper.dart';

/// Ouvre la feuille d'édition d'une carte possédée (quantité, état, langue).
Future<void> showCollectionEditor(BuildContext context, String cardId) {
  final sheet = CollectionEditSheet(cardId: cardId);
  if (isCupertino(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => sheet,
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => sheet,
  );
}

/// Édition des lots d'une carte : un lot par état et par langue, chacun dans
/// son panneau parchemin.
class CollectionEditSheet extends ConsumerStatefulWidget {
  const CollectionEditSheet({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<CollectionEditSheet> createState() =>
      _CollectionEditSheetState();
}

class _CollectionEditSheetState extends ConsumerState<CollectionEditSheet> {
  String? _error;
  bool _busy = false;
  int _newQty = 1;
  String _newCondition = defaultCondition;
  String _newLang = defaultLang;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CollectionController get _collection =>
      ref.read(collectionControllerProvider.notifier);

  Future<void> _remove(CollectionItem item) async {
    final confirmed = await showAdaptiveMessage(
      context,
      title: 'Retirer de la collection ?',
      message:
          '${item.card.name} et ${lotCountLabel(item.entries.length).toLowerCase()} '
          'seront retirés de ton inventaire.',
      closeLabel: 'Annuler',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _collection.removeCard(widget.cardId));
    if (mounted && _error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = riftText(context);
    final item = ref
        .watch(collectionControllerProvider)
        .valueOrNull
        ?.itemOf(widget.cardId);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 8,
            bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: item == null
              ? _Removed(onClose: () => Navigator.of(context).pop())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GoldRule(),
                      const SizedBox(height: 12),
                      Text(item.card.name, style: text.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${item.card.displayCode} · ${copyCountLabel(item.totalQty)}',
                        style: text.mono,
                      ),
                      const SizedBox(height: 16),
                      for (final entry in item.entries) ...[
                        _EntryPanel(
                          entry: entry,
                          busy: _busy,
                          onQty: (qty) => _run(
                            () => _collection.updateEntry(
                              cardId: widget.cardId,
                              entry: entry,
                              qty: qty,
                            ),
                          ),
                          onCondition: (condition) => _run(
                            () => _collection.updateEntry(
                              cardId: widget.cardId,
                              entry: entry,
                              condition: condition,
                            ),
                          ),
                          onLang: (lang) => _run(
                            () => _collection.updateEntry(
                              cardId: widget.cardId,
                              entry: entry,
                              lang: lang,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      RiftPanel(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ajouter un lot', style: text.eyebrow),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _CodeChip(
                                        label: conditionLabel(_newCondition),
                                        code: _newCondition,
                                        onTap: _busy
                                            ? null
                                            : () async {
                                                final picked = await pickCode(
                                                  context,
                                                  title: 'État',
                                                  options: collectionConditions,
                                                  current: _newCondition,
                                                );
                                                if (picked != null && mounted) {
                                                  setState(
                                                    () =>
                                                        _newCondition = picked,
                                                  );
                                                }
                                              },
                                      ),
                                      _CodeChip(
                                        label: langLabel(_newLang),
                                        code: _newLang,
                                        onTap: _busy
                                            ? null
                                            : () async {
                                                final picked = await pickCode(
                                                  context,
                                                  title: 'Langue',
                                                  options: collectionLangs,
                                                  current: _newLang,
                                                );
                                                if (picked != null && mounted) {
                                                  setState(
                                                    () => _newLang = picked,
                                                  );
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                QuantityStepper(
                                  value: _newQty,
                                  min: 1,
                                  max: maxCollectionQty,
                                  enabled: !_busy,
                                  size: StepperSize.compact,
                                  semanticsLabel: 'Quantité du nouveau lot',
                                  onChanged: (qty) =>
                                      setState(() => _newQty = qty),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GoldButton(
                              label: 'Ajouter',
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => _collection.addEntry(
                                        cardId: widget.cardId,
                                        qty: _newQty,
                                        condition: _newCondition,
                                        lang: _newLang,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: text.small.copyWith(color: RiftColors.fury),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Le libellé long cède la place à « Fermer » quand
                          // l'échelle de texte est grande.
                          Flexible(
                            child: TextButton(
                              onPressed: _busy ? null : () => _remove(item),
                              style: TextButton.styleFrom(
                                foregroundColor: RiftColors.fury,
                              ),
                              child: const Text(
                                'Retirer de la collection',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Fermer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Removed extends StatelessWidget {
  const _Removed({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Cette carte ne fait plus partie de ta collection.',
          style: text.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onClose, child: const Text('Fermer')),
      ],
    );
  }
}

/// Un lot : sa quantité, son état et sa langue, dans un panneau à part.
class _EntryPanel extends StatelessWidget {
  const _EntryPanel({
    required this.entry,
    required this.busy,
    required this.onQty,
    required this.onCondition,
    required this.onLang,
  });

  final CollectionEntry entry;
  final bool busy;
  final ValueChanged<int> onQty;
  final ValueChanged<String> onCondition;
  final ValueChanged<String> onLang;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(entry.label, style: text.monoStrong)),
              IconButton(
                onPressed: busy ? null : () => onQty(0),
                tooltip: 'Supprimer le lot',
                color: RiftColors.fury,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CodeChip(
                      label: conditionLabel(entry.condition),
                      code: entry.condition,
                      onTap: busy
                          ? null
                          : () async {
                              final picked = await pickCode(
                                context,
                                title: 'État',
                                options: collectionConditions,
                                current: entry.condition,
                              );
                              if (picked != null && picked != entry.condition) {
                                onCondition(picked);
                              }
                            },
                    ),
                    _CodeChip(
                      label: langLabel(entry.lang),
                      code: entry.lang,
                      onTap: busy
                          ? null
                          : () async {
                              final picked = await pickCode(
                                context,
                                title: 'Langue',
                                options: collectionLangs,
                                current: entry.lang,
                              );
                              if (picked != null && picked != entry.lang) {
                                onLang(picked);
                              }
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              QuantityStepper(
                value: entry.qty,
                max: maxCollectionQty,
                enabled: !busy,
                size: StepperSize.compact,
                semanticsLabel:
                    'Quantité du lot ${entry.condition} ${entry.lang}',
                onChanged: onQty,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pastille de valeur courante (état, langue) : ouvre la liste des choix.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.label, required this.code, this.onTap});

  final String label;
  final String code;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$code, $label',
      child: FilterChip(
        label: Text(label),
        selected: true,
        onSelected: onTap == null ? null : (_) => onTap!(),
      ),
    );
  }
}

/// Choix d'un code (état, langue) dans une boîte de dialogue adaptative.
Future<String?> pickCode(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  required String current,
}) {
  return showAdaptiveDialog<String>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options.entries)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(option.key),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${option.key} · ${option.value}'),
                        ),
                        if (option.key == current)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        adaptiveAction(
          context,
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
