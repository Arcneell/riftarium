import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../application/game_providers.dart';
import 'widgets/game_theme.dart';
import 'widgets/setup_view.dart';
import 'widgets/table_view.dart';
import 'widgets/victory_overlay.dart';

/// Compteur de partie : l'écran que l'on pose au milieu de la table.
///
/// Trois étapes dans un seul écran plein : configuration, table, victoire.
/// Tout fonctionne hors ligne et sans compte ; l'écran reste allumé tant que
/// la partie dure.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  /// Gardé en champ : `dispose` ne peut plus lire un provider, et c'est
  /// justement là qu'il faut rendre la main à la veille du système.
  late final ScreenAwake _screen;
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    _screen = ref.read(screenAwakeProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_awake) _screen.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En arrière-plan, on rend la main à la veille du système ; au retour,
    // la table reprend son écran allumé.
    if (state == AppLifecycleState.resumed) {
      _syncAwake(_awake);
    } else if (state == AppLifecycleState.paused) {
      _screen.disable();
    }
  }

  void _syncAwake(bool shouldStayAwake) {
    _awake = shouldStayAwake;
    if (shouldStayAwake) {
      _screen.enable();
    } else {
      _screen.disable();
    }
  }

  void _close() {
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final playing = game != null;
    if (playing != _awake) {
      // Après la frame : `build` ne doit pas déclencher d'effet de bord.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAwake(playing);
      });
    }

    return gameTheme(
      child: Scaffold(
        backgroundColor: RiftColors.inkStrong,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: game == null
                    ? GameSetupView(onClose: _close)
                    : GameTableView(state: game, onQuit: _close),
              ),
              if (game != null && game.isOver)
                VictoryOverlay(
                  state: game,
                  onNewRound: ref
                      .read(gameControllerProvider.notifier)
                      .newRound,
                  onNewGame: ref.read(gameControllerProvider.notifier).reset,
                  onFinish: ref.read(gameControllerProvider.notifier).quit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
