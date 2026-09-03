import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/design/components.dart';
import '../../../app/design/motion_utils.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/share_origin.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../auth/application/auth_controller.dart';
import '../../game/domain/game_mode.dart';
import '../../game/domain/player.dart';
import '../../game/ui/widgets/draw_overlay.dart';
import '../../game/ui/widgets/game_theme.dart';
import '../../game/ui/widgets/legend_picker_sheet.dart';
import '../application/play_providers.dart';
import '../application/room_controller.dart';
import '../domain/room.dart';
import 'widgets/deck_picker_sheet.dart';
import 'widgets/play_avatar.dart';
import 'widgets/play_error.dart';

/// Salon d'attente d'une partie suivie.
///
/// Le code est la clé du salon : on le lit à voix haute, on le copie, on le
/// partage. Chacun choisit sa légende et son deck, se déclare prêt ; l'hôte
/// tire au sort qui commence et lance la partie. L'écran se tient à jour par
/// sondage (2 s) : une coupure réseau ne fait que retarder le prochain
/// battement, rien ne se perd.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with SingleTickerProviderStateMixin {
  final _random = Random();

  /// Créé d'emblée (et non paresseusement) : `dispose` ne doit jamais avoir à
  /// fabriquer un contrôleur alors que l'arbre est déjà démonté.
  late final AnimationController _spin;

  List<Player> _drawPlayers = const [];
  int _drawTarget = 0;
  int _spinSteps = 0;
  bool _drawing = false;
  bool _busy = false;
  bool _leaving = false;
  bool _navigated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  RoomController get _controller =>
      ref.read(roomControllerProvider(widget.code).notifier);

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.game);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
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

  Future<void> _copy(Room room) async {
    await Clipboard.setData(ClipboardData(text: room.code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copié.')));
  }

  Future<void> _share(Room room) async {
    final url = room.shareUrl(AppConfig.webBaseUrl);
    await SharePlus.instance.share(
      ShareParams(
        text: 'Rejoins ma partie Riftarium : $url',
        subject: 'Salon ${room.code}',
        sharePositionOrigin: shareOriginOf(context),
      ),
    );
  }

  Future<void> _pickLegend() async {
    final legend = await showLegendPicker(context);
    if (legend == null || !mounted) return;
    await _guard(() => _controller.setLegend(legend));
  }

  Future<void> _pickDeck() async {
    final choice = await showDeckPicker(context);
    if (choice == null || !mounted) return;
    await _guard(() => _controller.setDeck(choice.deck));
  }

  Future<void> _leave(Room room, {required bool isHost}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHost ? 'Annuler le salon ?' : 'Quitter le salon ?'),
        content: Text(
          isHost
              ? 'Ton adversaire sera prévenu et le salon se fermera.'
              : 'Tu pourras y revenir avec le code tant qu’il reste ouvert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isHost ? 'Annuler le salon' : 'Quitter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _leaving = true;
    var left = false;
    await _guard(() async {
      if (isHost) {
        await _controller.cancel();
      } else {
        await _controller.leave();
      }
      left = true;
      if (!mounted) return;
      ref.invalidate(currentPlayProvider);
      _close();
    });
    // Échec (le bandeau l'annonce) : l'écran redevient un salon ordinaire, et
    // le passage automatique au match doit redevenir possible.
    if (!left) _leaving = false;
  }

  /// Le spectateur prend le siège libre.
  Future<void> _join() => _guard(_controller.join);

  /// Tirage au sort du premier joueur, puis lancement : le même rituel qu'en
  /// partie libre, la roue en plein écran.
  Future<void> _draw(Room room) async {
    final players = _playersOf(room);
    if (players.length < 2) return;
    final target = _random.nextInt(players.length);
    setState(() {
      _drawPlayers = players;
      _drawTarget = target;
      _spinSteps = players.length * 3 + target;
      _drawing = true;
    });
    if (riftReduceMotion(context)) return;
    await _spin.forward(from: 0);
    if (!mounted) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> _start() async {
    if (!_drawing) return;
    final winner = _drawPlayers[_drawTarget % _drawPlayers.length];
    setState(() => _drawing = false);
    final firstPlayerId = int.tryParse(winner.id);
    if (firstPlayerId == null) return;
    await _guard(() async {
      await _controller.start(firstPlayerId);
      if (mounted) ref.invalidate(currentPlayProvider);
    });
  }

  List<Player> _playersOf(Room room) {
    final seats = [...room.players]..sort((a, b) => a.seat.compareTo(b.seat));
    return [
      for (final seat in seats)
        Player(
          id: '${seat.user.id}',
          name: seat.user.displayName,
          seat: seat.seat,
          team: seat.seat,
          legend: seat.legend,
        ),
    ];
  }

  void _goToMatch(int matchId) {
    if (_navigated || _leaving) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement(AppRoutes.trackedMatch(matchId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!signedIn) {
      return SignInRequired(
        title: 'Salon ${widget.code}',
        eyebrow: 'Partie suivie',
        message:
            'Connecte-toi pour rejoindre ce salon : une partie suivie relie '
            'deux comptes.',
        returnTo: AppRoutes.room(widget.code),
      );
    }

    // Le passage au match est un effet, pas un rendu : il s'écoute plutôt
    // que de partir de `build` (le sondage fera arriver le salon en
    // « playing », l'écoute déclenchera la navigation).
    ref.listen(roomControllerProvider(widget.code), (previous, next) {
      final room = next.valueOrNull;
      final matchId = room?.matchId;
      if (room != null && room.isPlaying && matchId != null) {
        _goToMatch(matchId);
      }
    });

    final room = ref.watch(roomControllerProvider(widget.code));
    return gameTheme(
      child: Scaffold(
        backgroundColor: RiftColors.night,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: room.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(
                    message: error is ApiException
                        ? error.message
                        : 'Ce salon est introuvable.',
                    onRetry: _controller.reload,
                  ),
                  data: _body,
                ),
              ),
              if (_drawing)
                DrawOverlay(
                  players: _drawPlayers,
                  nameOf: (player) => player.name,
                  animation: riftAnimation(context, _spin),
                  steps: _spinSteps,
                  target: _drawTarget,
                  note: GameMode.duel.firstTurnNotes.first,
                  onDismiss: _start,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(Room room) {
    final text = riftText(context);
    final myId = ref.watch(myUserIdProvider);
    final isHost = room.isHost(myId);
    final me = room.playerOf(myId);

    if (room.isCancelled || room.expired()) {
      return _Closed(
        title: room.isCancelled ? 'Salon annulé' : 'Salon expiré',
        detail: room.isCancelled
            ? 'L’hôte a refermé ce salon.'
            : 'Un salon reste ouvert deux heures. Crée-s’en un autre pour '
                  'rejouer.',
        onClose: _close,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(code: room.code, onClose: _close),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            children: [
              _CodePanel(
                room: room,
                onCopy: () => _copy(room),
                onShare: () => _share(room),
              ),
              const SizedBox(height: 22),
              Text('JOUEURS', style: text.eyebrow),
              const SizedBox(height: 10),
              _SeatCard(
                player: room.host,
                seat: 0,
                isMe: room.host?.user.id == myId,
                onLegend: _pickLegend,
                onDeck: _pickDeck,
                onReady: (ready) => _guard(() => _controller.setReady(ready)),
              ),
              const SizedBox(height: 10),
              _SeatCard(
                player: room.guest,
                seat: 1,
                isMe: room.guest?.user.id == myId,
                onLegend: _pickLegend,
                onDeck: _pickDeck,
                onReady: (ready) => _guard(() => _controller.setReady(ready)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                PlayErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              if (isHost) ...[
                GoldButton(
                  label: 'Lancer la partie',
                  icon: Icons.play_arrow_rounded,
                  loading: _busy,
                  onPressed: room.bothReady && !_busy
                      ? () => _draw(room)
                      : null,
                ),
                if (!room.bothReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    room.guest == null
                        ? 'En attente du second joueur.'
                        : 'Il manque encore un « Prêt ».',
                    textAlign: TextAlign.center,
                    style: text.small,
                  ),
                ],
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => _leave(room, isHost: true),
                    child: const Text('Annuler le salon'),
                  ),
                ),
              ] else if (me == null) ...[
                if (room.isOpen && room.guest == null) ...[
                  Text(
                    'Le siège de l’invité est libre : prends-le pour jouer '
                    'cette partie.',
                    textAlign: TextAlign.center,
                    style: text.small,
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: 'Rejoindre ce salon',
                    icon: Icons.login_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _join,
                  ),
                ] else ...[
                  Text(
                    'Salon complet : tu le consultes en spectateur.',
                    textAlign: TextAlign.center,
                    style: text.small,
                  ),
                  const SizedBox(height: 12),
                  GhostButton(
                    label: 'Revenir au jeu',
                    icon: Icons.arrow_back_rounded,
                    onPressed: _close,
                  ),
                ],
              ] else ...[
                Text(
                  'L’hôte lance la partie quand vous êtes prêts tous les '
                  'deux.',
                  textAlign: TextAlign.center,
                  style: text.small,
                ),
                const SizedBox(height: 12),
                GhostButton(
                  label: 'Quitter le salon',
                  icon: Icons.logout_rounded,
                  onPressed: () => _leave(room, isHost: false),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.code, required this.onClose});

  final String code;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PARTIE SUIVIE', style: text.eyebrow),
                const SizedBox(height: 4),
                Text('Salon', style: text.displayMedium),
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
    );
  }
}

/// Le code, en très grand : c'est lui qu'on dicte à l'autre bout de la table.
class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.room,
    required this.onCopy,
    required this.onShare,
  });

  final Room room;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      raised: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CODE DU SALON', style: text.eyebrow),
          const SizedBox(height: 10),
          Center(
            child: SelectableText(
              room.code,
              style: text.monoStrong.copyWith(
                fontSize: 40,
                letterSpacing: 10,
                color: RiftColors.goldSoft,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                MonoBadge(label: room.modeLabel),
                MonoBadge(label: 'Victoire ${room.victoryScore}'),
                MonoBadge(
                  label: room.roundsToWin == 1
                      ? '1 manche'
                      : '${room.roundsToWin} manches gagnantes',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Copier',
                  icon: Icons.copy_rounded,
                  onPressed: onCopy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Partager',
                  icon: Icons.ios_share_rounded,
                  onPressed: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une place autour de la table : le joueur, sa légende, son deck, son « Prêt ».
/// Seul le siège du joueur courant est modifiable.
class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.player,
    required this.seat,
    required this.isMe,
    required this.onLegend,
    required this.onDeck,
    required this.onReady,
  });

  final RoomPlayer? player;
  final int seat;
  final bool isMe;
  final VoidCallback onLegend;
  final VoidCallback onDeck;
  final void Function(bool ready) onReady;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final role = seat == 0 ? 'Hôte' : 'Invité';
    final person = player;

    if (person == null) {
      return ActiveGlow(
        active: true,
        child: RiftPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: Row(
            children: [
              const PlayAvatar(user: null, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.toUpperCase(), style: text.eyebrow),
                    const SizedBox(height: 4),
                    Text('En attente de l’adversaire…', style: text.bodyStrong),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final legend = person.legend;
    final deck = person.deck;
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                // Le pseudo mène au profil public de l'adversaire.
                child: PressScale(
                  onTap: person.user.handle.isEmpty
                      ? null
                      : () =>
                            context.push(AppRoutes.player(person.user.handle)),
                  child: Row(
                    children: [
                      PlayAvatar(user: person.user, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(role.toUpperCase(), style: text.eyebrow),
                            const SizedBox(height: 2),
                            Text(
                              person.user.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.title,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MonoBadge(
                label: person.ready ? 'Prêt' : 'Pas prêt',
                color: person.ready ? RiftColors.calm : RiftColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                child: legend == null
                    ? Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: RiftColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(RiftRadius.card),
                          border: Border.all(
                            color: RiftColors.goldSoft.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: RiftColors.goldSoft,
                        ),
                      )
                    : CardImage(card: legend, thumbWidth: CardArtSize.tile),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      legend?.name ?? 'Aucune légende',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deck == null ? 'Sans deck' : deck.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isMe) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onLegend,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Ma légende'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDeck,
                    icon: const Icon(Icons.layers_outlined, size: 16),
                    label: const Text('Mon deck'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              value: person.ready,
              onChanged: onReady,
              contentPadding: EdgeInsets.zero,
              title: Text('Prêt', style: text.bodyStrong),
            ),
          ],
        ],
      ),
    );
  }
}

/// Salon fermé : plus rien à attendre, on repart de l'écran Jouer.
class _Closed extends StatelessWidget {
  const _Closed({
    required this.title,
    required this.detail,
    required this.onClose,
  });

  final String title;
  final String detail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RiftPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center, style: text.small),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Revenir au jeu',
                icon: Icons.arrow_back_rounded,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
