import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CameraLayer(camera: camera),
          if (state.isLive)
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x66000000)),
            ),
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
      return const ColoredBox(color: Colors.black);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            color: Colors.white,
            tooltip: 'Fermer le scanner',
            icon: const Icon(Icons.close),
          ),
          IconButton(
            onPressed: torchEnabled ? onToggleTorch : null,
            color: torchOn ? kRiftariumGold : Colors.white,
            disabledColor: Colors.white38,
            tooltip: torchOn ? 'Éteindre la torche' : 'Allumer la torche',
            icon: Icon(torchOn ? Icons.flashlight_on : Icons.flashlight_off),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context) {
    final error = state.message;
    final label =
        error ??
        switch (state.stage) {
          ScanStage.recognized => 'Carte reconnue',
          _ when state.reading => 'Lecture…',
          _ => 'Cadre le code de la carte',
        };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: error != null
                ? Colors.redAccent
                : kRiftariumGold.withValues(alpha: 0.7),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}

/// Cadre-guide : silhouette de carte, avec la bande du code mise en évidence.
class _CodeGuide extends StatelessWidget {
  const _CodeGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.78,
        child: AspectRatio(
          aspectRatio: CardImage.portraitRatio,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: kRiftariumGold, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Code de la carte ici',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
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
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    }
    final (icon, title, detail) = switch (state.stage) {
      ScanStage.permissionDenied => (
        Icons.no_photography_outlined,
        'Accès à la caméra refusé',
        'Autorise la caméra pour Riftarium dans les réglages de ton téléphone, '
            'puis reviens sur cet écran.',
      ),
      ScanStage.noCamera => (
        Icons.videocam_off_outlined,
        'Aucune caméra',
        state.message ??
            'Cet appareil n’a pas de caméra utilisable pour le scan.',
      ),
      _ => (
        Icons.error_outline,
        'Scan indisponible',
        state.message ?? 'Le scanner n’a pas pu démarrer.',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            if (state.stage == ScanStage.failed)
              AdaptiveFilledButton(label: 'Réessayer', onPressed: onRetry),
            AdaptiveTextButton(label: 'Fermer', onPressed: onClose),
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
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return ScanResultSheet(
      card: card,
      code: state.code,
      addedQty: state.addedQty,
      adding: state.adding,
      addError: state.addError,
      onAdd: controller.addOne,
      onOpenCard: () => context.go(AppRoutes.card(card.id)),
      onNext: controller.scanNext,
    );
  }
}

/// Rangée des dernières cartes reconnues pendant la session.
class _History extends StatelessWidget {
  const _History({required this.state});

  final ScanState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: state.history.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = state.history[index];
          return GestureDetector(
            onTap: () => context.go(AppRoutes.card(entry.card.id)),
            child: Tooltip(
              message: '${entry.card.name} · ${entry.code}',
              child: CardImage(card: entry.card, width: 46),
            ),
          );
        },
      ),
    );
  }
}
