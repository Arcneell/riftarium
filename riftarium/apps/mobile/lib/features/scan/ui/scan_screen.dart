import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../cards/domain/card_labels.dart';
import '../application/scan_controller.dart';
import 'scan_result_sheet.dart';

/// Scanner de cartes : aperçu caméra plein écran, lecture du code collector
/// imprimé au bas de la carte, puis ajout à la collection.
///
/// Route plein écran `/scan`, hors onglets et réservée aux comptes connectés.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final camera = controller.camera;

    return Scaffold(
      backgroundColor: RiftColors.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CameraLayer(camera: camera),
          const _Veil(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  torchOn: state.torchOn,
                  torchEnabled: camera != null,
                  onClose: () => _close(context),
                  onToggleTorch: controller.toggleTorch,
                ),
                if (state.isLive) _StatusBanner(state: state),
                Expanded(
                  child: state.isLive
                      ? const _CodeGuide()
                      : _StageMessage(
                          state: state,
                          onRetry: controller.retry,
                          onClose: () => _close(context),
                        ),
                ),
                if (state.stage == ScanStage.recognized)
                  _Result(state: state, controller: controller)
                else if (state.history.isNotEmpty)
                  _History(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.cards);
    }
  }
}

/// Aperçu caméra recadré pour occuper tout l'écran (l'aperçu est au format du
/// capteur, jamais à celui du téléphone).
class _CameraLayer extends StatelessWidget {
  const _CameraLayer({required this.camera});

  final CameraController? camera;

  @override
  Widget build(BuildContext context) {
    final controller = camera;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: RiftColors.night);
    }
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// Voile encre haut et bas : la barre et la feuille de résultat restent
/// lisibles quelle que soit la scène filmée, le centre reste clair.
class _Veil extends StatelessWidget {
  const _Veil();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RiftColors.night.withValues(alpha: 0.82),
              RiftColors.night.withValues(alpha: 0.22),
              RiftColors.night.withValues(alpha: 0.28),
              RiftColors.night.withValues(alpha: 0.86),
            ],
            stops: const [0, 0.26, 0.62, 1],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.torchOn,
    required this.torchEnabled,
    required this.onClose,
    required this.onToggleTorch,
  });

  final bool torchOn;
  final bool torchEnabled;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundButton(
            icon: Icons.close,
            label: 'Fermer le scanner',
            onPressed: onClose,
          ),
          Text(
            'SCANNER',
            style: riftText(
              context,
            ).eyebrow.copyWith(color: RiftColors.goldSoft, letterSpacing: 2.4),
          ),
          _RoundButton(
            icon: torchOn ? Icons.flashlight_on : Icons.flashlight_off,
            label: torchOn ? 'Éteindre la torche' : 'Allumer la torche',
            active: torchOn,
            onPressed: torchEnabled ? onToggleTorch : null,
          ),
        ],
      ),
    );
  }
}

/// Bouton rond translucide posé sur l'aperçu.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: PressScale(
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RiftColors.night.withValues(alpha: 0.5),
              border: Border.all(
                color: active
                    ? RiftColors.gold
                    : Colors.white.withValues(alpha: 0.26),
                width: active ? 1.6 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: !enabled
                  ? Colors.white38
                  : active
                  ? RiftColors.goldSoft
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Consigne courante, en grand format : une seule phrase à la fois, qui se
/// remplace en fondu (MonoBadge agrandi, blanc sur encre).
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final error = state.message;
    final label =
        error ??
        switch (state.stage) {
          ScanStage.recognized => 'Carte reconnue',
          _ when state.reading => 'Lecture…',
          _ => 'Cadre le code de la carte',
        };
    final tint = error != null ? RiftColors.fury : RiftColors.gold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
      child: AnimatedSwitcher(
        duration: RiftMotion.base,
        switchInCurve: RiftMotion.ease,
        child: Container(
          key: ValueKey(label),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: RiftColors.night.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(RiftRadius.full),
            border: Border.all(color: tint.withValues(alpha: 0.75), width: 1.3),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: text.mono.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadre-guide : silhouette de carte, coins or qui respirent autour de la bande
/// du code — c'est là que l'œil doit poser la carte.
class _CodeGuide extends StatefulWidget {
  const _CodeGuide();

  @override
  State<_CodeGuide> createState() => _CodeGuideState();
}

class _CodeGuideState extends State<_CodeGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 10),
        child: AspectRatio(
          aspectRatio: CardImage.portraitRatio,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RiftRadius.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                height: 54,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Opacity(
                    opacity:
                        0.55 + 0.45 * Curves.easeInOut.transform(_pulse.value),
                    child: child,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: RiftColors.night.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(RiftRadius.sm),
                          ),
                        ),
                      ),
                      const _Corner(alignment: Alignment.topLeft),
                      const _Corner(alignment: Alignment.topRight),
                      const _Corner(alignment: Alignment.bottomLeft),
                      const _Corner(alignment: Alignment.bottomRight),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une équerre or de la mire.
class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: RiftColors.gold, width: 2.5);
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 18,
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: top ? side : BorderSide.none,
              bottom: top ? BorderSide.none : side,
              left: left ? side : BorderSide.none,
              right: left ? BorderSide.none : side,
            ),
          ),
        ),
      ),
    );
  }
}

/// Écrans pleins : initialisation, permission refusée, absence de caméra, panne.
class _StageMessage extends StatelessWidget {
  const _StageMessage({
    required this.state,
    required this.onRetry,
    required this.onClose,
  });

  final ScanState state;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (state.stage == ScanStage.initializing) {
      return const Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: RiftColors.goldSoft,
          ),
        ),
      );
    }
    final (icon, title, detail) = switch (state.stage) {
      ScanStage.permissionDenied => (
        Icons.no_photography_outlined,
        'Accès à la caméra refusé',
        'Autorise la caméra pour Riftarium dans les réglages du téléphone.',
      ),
      ScanStage.noCamera => (
        Icons.videocam_off_outlined,
        'Aucune caméra',
        state.message,
      ),
      _ => (Icons.error_outline, 'Scan indisponible', state.message),
    };
    // Le fond est encre : on force la palette sombre pour que les textes de
    // l'état vide restent en parchemin clair.
    return Theme(
      data: buildTheme(),
      child: EmptyView(
        icon: icon,
        title: title,
        detail: detail,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.stage == ScanStage.failed) ...[
              GoldButton(
                label: 'Réessayer',
                icon: Icons.refresh,
                expand: false,
                onPressed: onRetry,
              ),
              const SizedBox(height: 6),
            ],
            TextButton(onPressed: onClose, child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state, required this.controller});

  final ScanState state;
  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    final card = state.card;
    if (card == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RiftRadius.lg),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return ScanResultSheet(
      card: card,
      code: state.code,
      addedQty: state.addedQty,
      adding: state.adding,
      addError: state.addError,
      onAdd: controller.add,
      onOpenCard: () => context.go(AppRoutes.card(card.id)),
      onNext: controller.scanNext,
    );
  }
}

/// Rangée des dernières cartes reconnues pendant la session : chaque vignette
/// porte son prix estimé, et l'en-tête cumule la valeur de ce qui a été scanné.
class _History extends StatelessWidget {
  const _History({required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final history = state.history;
    // Cumul de ce qui a été rangé : le prix d'une carte compte autant de fois
    // qu'on en a ajouté d'exemplaires (un « +3 » vaut trois fois son prix).
    var total = 0.0;
    var priced = 0;
    for (final entry in history) {
      final price = entry.card.priceEur;
      final copies = entry.addedQty > 0 ? entry.addedQty : 1;
      if (price != null) {
        total += price * copies;
        priced++;
      }
    }
    final count = history.length;
    final label = StringBuffer(
      count == 1 ? '1 carte scannée' : '$count cartes scannées',
    );
    if (priced > 0) label.write(' · ~${formatEuro(total)}');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Text(
            label.toString(),
            style: text.mono.copyWith(fontSize: 11.5),
          ),
        ),
        SizedBox(
          // Vignette 44 px de large au ratio 5/7, le prix dessous, plus le
          // rembourrage vertical.
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final entry = history[index];
              final price = entry.card.priceEur;
              return Reveal(
                index: index,
                child: PressScale(
                  onTap: () => context.go(AppRoutes.card(entry.card.id)),
                  child: Tooltip(
                    message: '${entry.card.name} · ${entry.code}',
                    child: SizedBox(
                      width: 44,
                      child: Column(
                        children: [
                          CardImage(card: entry.card, width: 44, shadow: true),
                          const SizedBox(height: 3),
                          Text(
                            price == null ? '—' : formatEuro(price),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            style: text.mono.copyWith(
                              fontSize: 9.5,
                              color: RiftColors.goldDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
