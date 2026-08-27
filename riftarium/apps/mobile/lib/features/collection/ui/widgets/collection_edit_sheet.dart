import 'package:flutter/cupertino.dart' show showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/adaptive.dart';
import '../../../../core/api_exception.dart';
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

/// Édition des lots d'une carte : un lot par état et par langue.
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
          '${item.card.name} et ses ${item.entries.length} lot(s) seront retirés de ton inventaire.',
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
    final item = ref
        .watch(collectionControllerProvider)
        .valueOrNull
        ?.itemOf(widget.cardId);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: item == null
              ? _Removed(onClose: () => Navigator.of(context).pop())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.card.name, style: theme.textTheme.titleMedium),
                      Text(
                        '${item.card.displayCode} · ${item.totalQty} exemplaire(s)',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      for (final entry in item.entries)
                        _EntryRow(
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
                      const Divider(height: 28),
                      Text('Ajouter un lot', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          QuantityStepper(
                            value: _newQty,
                            min: 1,
                            max: maxCollectionQty,
                            enabled: !_busy,
                            semanticsLabel: 'Quantité du nouveau lot',
                            onChanged: (qty) => setState(() => _newQty = qty),
                          ),
                          _CodePill(
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
                                      setState(() => _newCondition = picked);
                                    }
                                  },
                          ),
                          _CodePill(
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
                                      setState(() => _newLang = picked);
                                    }
                                  },
                          ),
                          AdaptiveTextButton(
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
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AdaptiveTextButton(
                            label: 'Retirer de la collection',
                            onPressed: _busy ? null : () => _remove(item),
                          ),
                          AdaptiveTextButton(
                            label: 'Fermer',
                            onPressed: () => Navigator.of(context).pop(),
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Cette carte ne fait plus partie de ta collection.'),
      AdaptiveTextButton(label: 'Fermer', onPressed: onClose),
    ],
  );
}

/// Une ligne de lot : quantité, état et langue modifiables.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          QuantityStepper(
            value: entry.qty,
            max: maxCollectionQty,
            enabled: !busy,
            semanticsLabel: 'Quantité du lot ${entry.condition} ${entry.lang}',
            onChanged: onQty,
          ),
          _CodePill(
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
          _CodePill(
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
                    if (picked != null && picked != entry.lang) onLang(picked);
                  },
          ),
          AdaptiveTextButton(
            label: 'Supprimer',
            onPressed: busy ? null : () => onQty(0),
          ),
        ],
      ),
    );
  }
}

/// Pastille « code · libellé » qui ouvre la liste des valeurs possibles.
class _CodePill extends StatelessWidget {
  const _CodePill({required this.label, required this.code, this.onTap});

  final String label;
  final String code;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$code, $label',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            code,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
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
