import 'package:flutter/material.dart';

import '../../../app/design/components.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../cards/domain/card.dart';
import '../../cards/domain/card_labels.dart';

/// Feuille de résultat affichée au bas de l'écran de scan.
///
/// Volontairement sans Riverpod ni routeur : tout arrive en paramètre, ce qui
/// permet de la monter seule dans un test de widget (la caméra, elle, n'est pas
/// testable).
class ScanResultSheet extends StatefulWidget {
  const ScanResultSheet({
    super.key,
    required this.card,
    required this.code,
    required this.addedQty,
    required this.adding,
    required this.addError,
    required this.onAdd,
    required this.onOpenCard,
    required this.onNext,
  });

  final RiftCard card;

  /// Code lu, tel qu'imprimé (« OGN 209/298 »).
  final String? code;

  /// Exemplaires ajoutés depuis cet écran de résultat.
  final int addedQty;
  final bool adding;
  final String? addError;

  /// Ajout à la collection, avec la quantité choisie au stepper.
  final ValueChanged<int> onAdd;
  final VoidCallback onOpenCard;
  final VoidCallback onNext;

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  /// La feuille monte au premier repaint : le geste doit se voir, la carte
  /// « arrive » sous le cadre.
  bool _raised = false;

  /// Quantité à ajouter d'un coup (booster ouvert, playset) : 1 à 99, remise
  /// à 1 quand une nouvelle carte est reconnue.
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _raised = true);
    });
  }

  @override
  void didUpdateWidget(ScanResultSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) setState(() => _qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = riftText(context);
    final card = widget.card;
    final price = card.priceEur;
    final owned = card.ownedQty ?? 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final raised = _raised || reduceMotion;

    return AnimatedSlide(
      offset: raised ? Offset.zero : const Offset(0, 1),
      duration: RiftMotion.base,
      curve: RiftMotion.ease,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: RiftColors.paper2,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RiftRadius.lg),
          ),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: RiftShadows.raised,
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardImage(
                  card: card,
                  width: 110,
                  // Le reflet foil tourne en boucle : on ne l'allume pas quand
                  // le système demande moins de mouvement.
                  foil: !reduceMotion,
                  foilIntensity: 0.6,
                  heroTag: 'card-${card.id}',
                  shadow: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: text.displaySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          MonoBadge(label: widget.code ?? card.displayCode),
                          for (final domain in card.domains)
                            DomainChip(domain: domain, compact: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        price == null
                            ? 'Prix estimé indisponible'
                            : _qty == 1
                            ? 'Prix estimé ${formatEuro(price)}'
                            : 'Prix estimé ${formatEuro(price)} · '
                                  '×$_qty ≈ ${formatEuro(price * _qty)}',
                        style: text.monoStrong.copyWith(
                          fontSize: 14,
                          color: RiftColors.gold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: RiftMotion.base,
                        switchInCurve: RiftMotion.ease,
                        child: Text(
                          owned == 0
                              ? 'Pas encore dans ta collection'
                              : 'Dans ta collection : $owned',
                          key: ValueKey(owned),
                          style: text.small.copyWith(
                            color: owned == 0
                                ? text.muted
                                : RiftColors.calmText,
                            fontVariations: RiftFonts.weight(
                              owned == 0 ? 400 : 600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.addError != null) ...[
              const SizedBox(height: 12),
              _SheetNote(
                message: widget.addError!,
                color: RiftColors.fury,
                textColor: RiftColors.furyText,
                icon: Icons.error_outline,
              ),
            ],
            if (widget.addedQty > 0) ...[
              const SizedBox(height: 12),
              _SheetNote(
                message: widget.addedQty == 1
                    ? '1 exemplaire ajouté.'
                    : '${widget.addedQty} exemplaires ajoutés.',
                color: RiftColors.calm,
                textColor: RiftColors.calmText,
                icon: Icons.check_circle_outline,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _QtyStepper(
                  qty: _qty,
                  onChanged: (value) => setState(() => _qty = value),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldButton(
                    label: '+$_qty dans ma collection',
                    icon: Icons.add,
                    loading: widget.adding,
                    onPressed: () => widget.onAdd(_qty),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Fiche',
                    icon: Icons.article_outlined,
                    onPressed: widget.onOpenCard,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: widget.onNext,
                    child: const Text('Scanner la suivante'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Note de la feuille : ajout confirmé (calme) ou refus (fureur).
class _SheetNote extends StatelessWidget {
  const _SheetNote({
    required this.message,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: text.small.copyWith(color: textColor)),
          ),
        ],
      ),
    );
  }
}

/// Quantité à ajouter : − / valeur / +, bornée de 1 à 99.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Un exemplaire de moins',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: qty > 1 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: text.monoStrong.copyWith(fontSize: 15),
            ),
          ),
          IconButton(
            tooltip: 'Un exemplaire de plus',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: qty < 99 ? () => onChanged(qty + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
