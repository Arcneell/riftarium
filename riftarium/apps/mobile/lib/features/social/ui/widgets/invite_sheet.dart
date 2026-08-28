import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/design/components.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/config.dart';

/// Feuille de partage du code d'un salon : ce qu'on lit à voix haute, ce qu'on
/// copie, ce qu'on envoie. Ouverte après « Inviter dans un salon ».
Future<void> showRoomInviteSheet(
  BuildContext context, {
  required String code,
  required String handle,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => _InviteSheet(code: code, handle: handle),
);

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.code, required this.handle});

  final String code;
  final String handle;

  String get _url => '${AppConfig.webBaseUrl}/salon/$code';

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copié.')));
  }

  Future<void> _share() => SharePlus.instance.share(
    ShareParams(
      text: 'Rejoins ma partie Riftarium : $_url',
      subject: 'Salon $code',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('INVITATION', style: text.eyebrow),
          const SizedBox(height: 2),
          Text('Inviter $handle', style: text.displaySmall),
          const SizedBox(height: 12),
          Center(
            child: SelectableText(
              code,
              style: text.monoStrong.copyWith(fontSize: 36, letterSpacing: 8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Envoie-lui ce code : il rejoindra ton salon depuis « Partie '
            'suivie », sur le site comme sur l’application.',
            style: text.small,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Copier',
                  icon: Icons.copy_rounded,
                  onPressed: () => _copy(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Partager',
                  icon: Icons.ios_share_rounded,
                  onPressed: _share,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GoldButton(
            label: 'Ouvrir le salon',
            icon: Icons.meeting_room_outlined,
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.room(code));
            },
          ),
        ],
      ),
    );
  }
}
