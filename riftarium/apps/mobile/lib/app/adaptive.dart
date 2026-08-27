import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Widgets qui suivent les conventions de la plateforme : Cupertino sur iOS
/// et macOS, Material 3 ailleurs. Le reste de l'application ne teste jamais la
/// plateforme directement : il passe par ces composants.
bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
          trailing: trailing,
        ),
        child: SafeArea(child: body),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: trailing == null ? null : [trailing!],
      ),
      body: body,
    );
  }
}

class AdaptiveFilledButton extends StatelessWidget {
  const AdaptiveFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : Text(label);
    final enabled = onPressed != null && !loading;
    if (isCupertino(context)) {
      return CupertinoButton.filled(
        onPressed: enabled ? onPressed : null,
        child: child,
      );
    }
    return FilledButton(onPressed: enabled ? onPressed : null, child: child);
  }
}

class AdaptiveTextButton extends StatelessWidget {
  const AdaptiveTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoButton(onPressed: onPressed, child: Text(label));
    }
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      final theme = CupertinoTheme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            autocorrect: autocorrect,
            enableSuggestions: autocorrect,
            onSubmitted: onSubmitted,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      );
    }
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        errorText: errorText,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: autocorrect,
      onSubmitted: onSubmitted,
    );
  }
}

/// Boîte de dialogue d'information ou de confirmation. Renvoie true si
/// `confirmLabel` a été choisi (toujours false sans bouton de confirmation).
Future<bool> showAdaptiveMessage(
  BuildContext context, {
  required String title,
  required String message,
  String closeLabel = 'OK',
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        adaptiveAction(
          context,
          label: closeLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (confirmLabel != null)
          adaptiveAction(
            context,
            label: confirmLabel,
            destructive: destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
      ],
    ),
  );
  return result ?? false;
}

Widget adaptiveAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool destructive = false,
}) {
  if (isCupertino(context)) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: destructive,
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: destructive
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    ),
  );
}
