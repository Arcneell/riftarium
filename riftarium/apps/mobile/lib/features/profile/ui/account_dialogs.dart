import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../../app/widgets/auth_widgets.dart' show AuthError;

/// Changement de mot de passe. En cas de succès, la session locale est fermée
/// (jeton révoqué par l'API) et un message invite à se reconnecter.
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

/// Suppression du compte : mot de passe et pseudo exigés, comme sur le site.
Future<void> showDeleteAccountDialog(BuildContext context, String handle) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DeleteAccountDialog(handle: handle),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

/// Le dialogue tient son propre `ref` : garder celui de l'écran appelant
/// revenait à s'en servir après la disparition de ce widget.
class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 8) {
      setState(
        () => _error = 'Le nouveau mot de passe fait au moins 8 caractères.',
      );
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Les deux saisies ne correspondent pas.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      navigator.pop();
      await showAdaptiveMessage(
        navigator.context,
        title: 'Mot de passe changé',
        message:
            'Par sécurité, toutes tes sessions ont été fermées. '
            'Reconnecte-toi avec ton nouveau mot de passe.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ParchmentDialog(
      title: 'Changer le mot de passe',
      error: _error,
      confirm: GoldButton(
        label: 'Changer',
        loading: _busy,
        onPressed: _busy ? null : _submit,
      ),
      onCancel: _busy ? null : () => Navigator.of(context).pop(),
      children: [
        AdaptiveTextField(
          controller: _current,
          label: 'Mot de passe actuel',
          obscureText: true,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        AdaptiveTextField(
          controller: _next,
          label: 'Nouveau mot de passe',
          placeholder: '8 caractères minimum',
          obscureText: true,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        AdaptiveTextField(
          controller: _confirm,
          label: 'Confirmation',
          obscureText: true,
          autocorrect: false,
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({required this.handle});

  final String handle;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  final _handle = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_handle.text.trim() != widget.handle) {
      setState(() => _error = 'Le pseudo ne correspond pas.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: _password.text, handle: _handle.text.trim());
      if (!mounted) return;
      navigator.pop();
      await showAdaptiveMessage(
        navigator.context,
        title: 'Compte supprimé',
        message: 'Tes données ont été effacées.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return _ParchmentDialog(
      title: 'Supprimer mon compte',
      error: _error,
      confirm: _DangerButton(
        label: 'Supprimer',
        loading: _busy,
        onPressed: _busy ? null : _submit,
      ),
      onCancel: _busy ? null : () => Navigator.of(context).pop(),
      children: [
        Text(
          'Action définitive : collection, decks et wishlist seront '
          'effacés. Saisis ton mot de passe et ton pseudo pour confirmer.',
          style: text.small,
        ),
        const SizedBox(height: 14),
        AdaptiveTextField(
          controller: _password,
          label: 'Mot de passe',
          obscureText: true,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        AdaptiveTextField(
          controller: _handle,
          label: 'Pseudo (${widget.handle})',
          autocorrect: false,
        ),
      ],
    );
  }
}

/// Boîte de dialogue de la marque : panneau parchemin, titre Marcellus souligné
/// d'un filet or, action principale à droite.
class _ParchmentDialog extends StatelessWidget {
  const _ParchmentDialog({
    required this.title,
    required this.children,
    required this.confirm,
    required this.onCancel,
    this.error,
  });

  final String title;
  final List<Widget> children;
  final Widget confirm;
  final VoidCallback? onCancel;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: RiftPanel(
          raised: true,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: text.displaySmall),
                const SizedBox(height: 8),
                const GoldRule(width: 40),
                const SizedBox(height: 18),
                ...children,
                if (error != null) ...[
                  const SizedBox(height: 14),
                  AuthError(message: error!),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(label: 'Annuler', onPressed: onCancel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: confirm),
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

/// Action destructive : même silhouette que `GoldButton`, teinte fureur.
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final enabled = onPressed != null && !loading;
    return PressScale(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: RiftMotion.quick,
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: RiftColors.fury,
            borderRadius: BorderRadius.circular(RiftRadius.full),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: text.bodyStrong.copyWith(
                    color: Colors.white,
                    fontSize: 15.5,
                  ),
                ),
        ),
      ),
    );
  }
}
