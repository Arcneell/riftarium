import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';

/// Changement de mot de passe. En cas de succès, la session locale est fermée
/// (jeton révoqué par l'API) et un message invite à se reconnecter.
Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChangePasswordDialog(ref: ref),
  );
}

/// Suppression du compte : mot de passe et pseudo exigés, comme sur le site.
Future<void> showDeleteAccountDialog(
  BuildContext context,
  WidgetRef ref,
  String handle,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DeleteAccountDialog(ref: ref, handle: handle),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
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
      await widget.ref
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
    return AlertDialog.adaptive(
      title: const Text('Changer le mot de passe'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        adaptiveAction(
          context,
          label: 'Annuler',
          onPressed: _busy ? () {} : () => Navigator.of(context).pop(),
        ),
        adaptiveAction(
          context,
          label: _busy ? 'Enregistrement…' : 'Changer',
          onPressed: _busy ? () {} : _submit,
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.ref, required this.handle});

  final WidgetRef ref;
  final String handle;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
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
      await widget.ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: _password.text, handle: _handle.text.trim());
      if (!mounted) return;
      navigator.pop();
      await showAdaptiveMessage(
        navigator.context,
        title: 'Compte supprimé',
        message: 'Tes données ont été effacées. Merci d’avoir joué avec nous.',
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
    return AlertDialog.adaptive(
      title: const Text('Supprimer mon compte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Action définitive : collection, decks et wishlist seront '
              'effacés. Saisis ton mot de passe et ton pseudo pour confirmer.',
            ),
            const SizedBox(height: 12),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        adaptiveAction(
          context,
          label: 'Annuler',
          onPressed: _busy ? () {} : () => Navigator.of(context).pop(),
        ),
        adaptiveAction(
          context,
          label: _busy ? 'Suppression…' : 'Supprimer',
          destructive: true,
          onPressed: _busy ? () {} : _submit,
        ),
      ],
    );
  }
}
