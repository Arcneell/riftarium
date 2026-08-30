import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/components.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../game/application/game_providers.dart';
import '../../game/ui/widgets/game_theme.dart';
import '../../game/ui/widgets/table_view.dart';
import '../../game/ui/widgets/victory_overlay.dart';
import '../application/play_providers.dart';
import '../application/tracked_match_controller.dart';
import '../domain/match.dart';
import 'widgets/play_avatar.dart';

/// Match suivi : la table du compteur, partagée par deux téléphones.
///
/// L'hôte compte (ses gestes partent au serveur, une pastille dit où en est
/// l'envoi) ; l'invité regarde la même table, figée, mise à jour par sondage.
/// À la victoire, l'hôte envoie le résultat et l'invité le confirme ou le
/// conteste : sans confirmation, rien n'entre dans les statistiques.
class TrackedMatchScreen extends ConsumerStatefulWidget {
  const TrackedMatchScreen({super.key, required this.matchId});

  final int matchId;

  @override
  ConsumerState<TrackedMatchScreen> createState() => _TrackedMatchScreenState();
}

class _TrackedMatchScreenState extends ConsumerState<TrackedMatchScreen> {
  /// Gardé en champ : `dispose` ne peut plus lire un provider.
  late final ScreenAwake _screen;

  @override
  void initState() {
    super.initState();
    _screen = ref.read(screenAwakeProvider);
    _screen.enable();
  }

  @override
  void dispose() {
    _screen.disable();
    super.dispose();
  }

  TrackedMatchController get _controller =>
      ref.read(trackedMatchControllerProvider(widget.matchId).notifier);

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.game);
    }
  }

  void _report(Object error) {
    if (!mounted) return;
    final message = error is ApiException
        ? error.message
        : 'Action impossible pour le moment.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) ref.invalidate(currentPlayProvider);
    } on ApiException catch (error) {
      _report(error);
    }
  }

  Future<bool> _confirmAbandon() async {
    final abandon = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner la partie ?'),
        content: const Text(
          'Ton adversaire l’emporte. Le résultat est enregistré sans '
          'confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer à jouer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return abandon == true;
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!signedIn) {
      return SignInRequired(
        title: 'Partie suivie',
        eyebrow: 'Compteur',
        message: 'Connecte-toi pour retrouver ta partie en cours.',
        returnTo: AppRoutes.trackedMatch(widget.matchId),
      );
    }

    final tracked = ref.watch(trackedMatchControllerProvider(widget.matchId));
    return gameTheme(
      child: Scaffold(
        backgroundColor: RiftColors.inkStrong,
        body: SafeArea(
          child: tracked.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: error is ApiException
                  ? error.message
                  : 'Cette partie est introuvable.',
              onRetry: _controller.reload,
            ),
            data: _body,
          ),
        ),
      ),
    );
  }

  Widget _body(TrackedMatch tracked) {
    final match = tracked.match;
    final myId = ref.watch(myUserIdProvider);
    final isHost = match.isHost(myId);

    if (!match.isLive) {
      return _ResultView(
        match: match,
        myId: myId,
        onConfirm: () => _act(_controller.confirmResult),
        onDispute: () => _act(_controller.disputeResult),
        onClose: _close,
      );
    }

    final over = tracked.board.isOver;
    return Stack(
      children: [
        Positioned.fill(
          child: GameTableView(
            state: tracked.board,
            actions: _controller,
            readOnly: !isHost,
            allowRestart: false,
            quitLabel: 'Abandonner',
            confirmQuit: _confirmAbandon,
            onQuit: () => _act(_controller.abandonMatch),
            notice: _Notice(
              isHost: isHost,
              sync: tracked.sync,
              waitingForHost: over && !isHost,
            ),
          ),
        ),
        if (over && isHost)
          VictoryOverlay(
            state: tracked.board,
            allowNewGame: false,
            finishLabel: 'Envoyer le résultat',
            onNewRound: _controller.newRound,
            onNewGame: _controller.newRound,
            onFinish: () => _act(_controller.finishMatch),
          ),
      ],
    );
  }
}

/// Bandeau discret de la barre de commande : qui compte, et où en est l'envoi.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.isHost,
    required this.sync,
    required this.waitingForHost,
  });

  final bool isHost;
  final PlaySync sync;
  final bool waitingForHost;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final (IconData icon, String label, Color color) = switch ((
      isHost,
      waitingForHost,
      sync,
    )) {
      (false, true, _) => (
        Icons.hourglass_empty_rounded,
        'L’hôte va envoyer le résultat.',
        RiftColors.goldSoft,
      ),
      (false, _, _) => (
        Icons.visibility_outlined,
        'L’hôte tient le compte.',
        RiftColors.goldSoft,
      ),
      (true, _, PlaySync.synced) => (
        Icons.cloud_done_outlined,
        'Synchronisé',
        RiftColors.calm,
      ),
      (true, _, PlaySync.pending) => (
        Icons.cloud_sync_outlined,
        'Envoi…',
        RiftColors.goldSoft,
      ),
      (true, _, PlaySync.offline) => (
        Icons.cloud_off_outlined,
        'Hors ligne : le compte repartira tout seul.',
        RiftColors.fury,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.small.copyWith(fontSize: 11.5, color: color),
          ),
        ),
      ],
    );
  }
}

/// Écran de fin : le résultat, et ce qu'il reste à faire pour qu'il compte.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.match,
    required this.myId,
    required this.onConfirm,
    required this.onDispute,
    required this.onClose,
  });

  final Match match;
  final int? myId;
  final VoidCallback onConfirm;
  final VoidCallback onDispute;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final me = match.playerOf(myId);
    final opponent = match.opponentOf(myId);
    final iWon = match.winnerUserId != null && match.winnerUserId == myId;
    final awaiting = match.isAwaitingConfirmation;
    final mustAnswer = awaiting && me != null && !me.confirmed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PARTIE SUIVIE', style: text.eyebrow),
                  const SizedBox(height: 4),
                  Text(match.statusLabel, style: text.displayMedium),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Fermer',
            ),
          ],
        ),
        const SizedBox(height: 12),
        RiftPanel(
          raised: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  match.winnerUserId == null
                      ? 'Sans vainqueur'
                      : (iWon ? 'Victoire' : 'Défaite'),
                  style: text.displayLarge.copyWith(
                    fontSize: 34,
                    color: match.winnerUserId == null
                        ? RiftColors.goldSoft
                        : (iWon ? RiftColors.calm : RiftColors.fury),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(child: GoldRule(width: 64)),
              const SizedBox(height: 16),
              _Side(player: me, label: 'Moi'),
              const SizedBox(height: 10),
              _Side(player: opponent, label: 'Adversaire'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (mustAnswer) ...[
          Text(
            'Le résultat ne comptera dans vos statistiques qu’une fois '
            'confirmé par vous deux.',
            style: text.small,
          ),
          const SizedBox(height: 12),
          GoldButton(
            label: 'Confirmer le résultat',
            icon: Icons.check_rounded,
            onPressed: onConfirm,
          ),
          const SizedBox(height: 8),
          GhostButton(
            label: 'Contester',
            icon: Icons.flag_outlined,
            onPressed: onDispute,
          ),
        ] else if (awaiting) ...[
          Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 18,
                color: RiftColors.goldSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'En attente de confirmation'
                  '${opponent == null ? '' : ' de ${opponent.user.displayName}'}.',
                  style: text.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GhostButton(
            label: 'Revenir au jeu',
            icon: Icons.arrow_back_rounded,
            onPressed: onClose,
          ),
        ] else ...[
          // Le statut « Résultat confirmé » se lit déjà plus haut : on
          // n'explique que les cas qui demandent une suite.
          if (match.status != 'confirmed') ...[
            Text(switch (match.status) {
              'disputed' =>
                'Résultat contesté : il est exclu des statistiques. '
                    'Rejouez la partie pour trancher.',
              _ =>
                'Partie abandonnée : elle compte comme une défaite pour celui '
                    'qui a abandonné.',
            }, style: text.small),
            const SizedBox(height: 16),
          ],
          GoldButton(
            label: 'Voir l’historique',
            icon: Icons.history_rounded,
            onPressed: () => context.push(AppRoutes.history),
          ),
          const SizedBox(height: 8),
          GhostButton(
            label: 'Revenir au jeu',
            icon: Icons.arrow_back_rounded,
            onPressed: onClose,
          ),
        ],
      ],
    );
  }
}

/// Une ligne de résultat : le joueur, sa légende, son score et ses manches.
class _Side extends StatelessWidget {
  const _Side({required this.player, required this.label});

  final MatchPlayer? player;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final person = player;
    if (person == null) {
      return Text('$label : joueur retiré', style: text.small);
    }
    final legend = person.legend;
    return Row(
      children: [
        PlayAvatar(user: person.user, size: 38),
        const SizedBox(width: 12),
        if (legend != null) ...[
          SizedBox(
            width: 28,
            child: CardImage(card: legend, thumbWidth: CardArtSize.tile),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyStrong,
              ),
              Text(
                [
                  if (legend != null) legend.name,
                  if (person.deck != null) person.deck!.name,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.small.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${person.score}',
              style: text.displayMedium.copyWith(color: RiftColors.goldSoft),
            ),
            Text('${person.roundsWon} manche(s)', style: text.mono),
          ],
        ),
      ],
    );
  }
}
