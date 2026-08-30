import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design/components.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/api_exception.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../game/domain/game_mode.dart';
import '../../application/play_providers.dart';
import '../../data/play_api.dart';
import 'play_error.dart';

/// Longueur du code d'un salon (alphabet sans 0/O/1/I, côté serveur).
const int kRoomCodeLength = 6;

/// Entrée dans une partie suivie : créer un salon, ou rejoindre celui d'un
/// adversaire avec son code. Les deux exigent un compte.
class TrackedStartPanel extends ConsumerStatefulWidget {
  const TrackedStartPanel({super.key});

  @override
  ConsumerState<TrackedStartPanel> createState() => _TrackedStartPanelState();
}

class _TrackedStartPanelState extends ConsumerState<TrackedStartPanel> {
  final _code = TextEditingController();

  /// v1 : deux joueurs seulement (duel sec ou deux manches gagnantes).
  static const _modes = [GameMode.duel, GameMode.match];

  GameMode _mode = GameMode.duel;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  PlayApi get _api => ref.read(playApiProvider);

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await action();
      if (!mounted) return;
      ref.invalidate(currentPlayProvider);
      context.push(AppRoutes.room(code));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() =>
      _run(() async => (await _api.createRoom(mode: _mode.id)).code);

  Future<void> _join() {
    final code = _code.text.trim().toUpperCase();
    if (code.length != kRoomCodeLength) {
      setState(
        () => _error = 'Le code d’un salon fait $kRoomCodeLength caractères.',
      );
      return Future<void>.value();
    }
    return _run(() async => (await _api.joinRoom(code)).code);
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!signedIn) return const _AccountRequired();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('FORMAT', style: text.eyebrow),
        const SizedBox(height: 10),
        for (final mode in _modes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModeChoice(
              mode: mode,
              selected: mode == _mode,
              onTap: () => setState(() => _mode = mode),
            ),
          ),
        const SizedBox(height: 14),
        GoldButton(
          label: 'Créer un salon',
          icon: Icons.add_circle_outline,
          loading: _busy,
          onPressed: _busy ? null : _create,
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OU', style: text.eyebrow),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 18),
        Text('Rejoindre un salon', style: text.displaySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: kRoomCodeLength,
          textAlign: TextAlign.center,
          style: text.monoStrong.copyWith(fontSize: 24, letterSpacing: 8),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            _UpperCaseFormatter(),
          ],
          decoration: const InputDecoration(
            hintText: 'ABC234',
            counterText: '',
          ),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'Rejoindre',
          icon: Icons.login_rounded,
          onPressed: _busy ? null : _join,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          PlayErrorBanner(message: _error!),
        ],
      ],
    );
  }
}

/// Passe la saisie en capitales : les codes s'échangent à l'oral et à l'écrit.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      onTap: onTap,
      raised: selected,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode.label, style: text.displaySmall),
                const SizedBox(height: 2),
                Text(mode.tagline, style: text.small),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: RiftColors.gold, size: 20),
        ],
      ),
    );
  }
}

/// Invitation à se connecter, posée dans la page plutôt qu'en plein écran :
/// la partie libre reste à un geste au-dessus.
class _AccountRequired extends StatelessWidget {
  const _AccountRequired();

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final from = GoRouterState.of(context).matchedLocation;
    return RiftPanel(
      raised: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('COMPTE REQUIS', style: text.eyebrow),
          const SizedBox(height: 6),
          Text(
            'Une partie suivie relie deux comptes : le score, les decks et le '
            'résultat sont enregistrés pour vous deux.',
            style: text.body,
          ),
          const SizedBox(height: 18),
          GoldButton(
            label: 'Se connecter',
            icon: Icons.login,
            onPressed: () => context.push(AppRoutes.loginFrom(from)),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => context.push(AppRoutes.register),
              child: const Text('Créer un compte'),
            ),
          ),
        ],
      ),
    );
  }
}
