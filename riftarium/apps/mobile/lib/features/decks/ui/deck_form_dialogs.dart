import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/adaptive.dart';
import 'deck_widgets.dart';

/// Boîtes de dialogue des decks : réglages d'un deck et import d'un code.

/// Réglages d'un deck (tout sauf ses cartes).
class DeckDraft {
  const DeckDraft({
    required this.name,
    this.description = '',
    this.format = 'tournament',
    this.isPublic = false,
  });

  final String name;
  final String description;
  final String format;
  final bool isPublic;
}

/// Code collé par l'utilisateur, avec les réglages du deck à créer.
class DeckImportRequest {
  const DeckImportRequest({
    required this.code,
    required this.name,
    this.format = 'tournament',
    this.isPublic = false,
  });

  final String code;
  final String name;
  final String format;
  final bool isPublic;
}

/// Formulaire d'un deck. Renvoie null si l'utilisateur annule.
Future<DeckDraft?> showDeckDraftDialog(
  BuildContext context, {
  required String title,
  DeckDraft? initial,
  String confirmLabel = 'Créer',
}) {
  return showAdaptiveDialog<DeckDraft>(
    context: context,
    builder: (context) => _DeckDraftDialog(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

/// Formulaire d'import d'un code de deck. Renvoie null si l'utilisateur annule.
Future<DeckImportRequest?> showImportCodeDialog(BuildContext context) {
  return showAdaptiveDialog<DeckImportRequest>(
    context: context,
    builder: (context) => const _ImportCodeDialog(),
  );
}

class _DeckDraftDialog extends StatefulWidget {
  const _DeckDraftDialog({
    required this.title,
    required this.confirmLabel,
    this.initial,
  });

  final String title;
  final String confirmLabel;
  final DeckDraft? initial;

  @override
  State<_DeckDraftDialog> createState() => _DeckDraftDialogState();
}

class _DeckDraftDialogState extends State<_DeckDraftDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late String _format = widget.initial?.format ?? 'tournament';
  late bool _isPublic = widget.initial?.isPublic ?? false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      DeckDraft(
        name: name,
        description: _description.text.trim(),
        format: _format,
        isPublic: _isPublic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveTextField(
              controller: _name,
              label: 'Nom du deck',
              placeholder: 'Fureur de Noxus…',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FormatChoice(
              value: _format,
              onChanged: (value) => setState(() => _format = value),
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: _description,
              label: 'Description (optionnel)',
              placeholder: 'Plan de jeu, forces, faiblesses…',
            ),
            const SizedBox(height: 8),
            PublicSwitch(
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
          ],
        ),
      ),
      actions: [
        adaptiveAction(
          context,
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
        adaptiveAction(context, label: widget.confirmLabel, onPressed: _submit),
      ],
    );
  }
}

class _ImportCodeDialog extends StatefulWidget {
  const _ImportCodeDialog();

  @override
  State<_ImportCodeDialog> createState() => _ImportCodeDialogState();
}

class _ImportCodeDialogState extends State<_ImportCodeDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController(text: 'Deck importé');
  String _format = 'tournament';
  bool _isPublic = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() => _code.text = text);
  }

  void _submit() {
    final code = _code.text.trim();
    final name = _name.text.trim();
    if (code.isEmpty || name.isEmpty) return;
    Navigator.of(context).pop(
      DeckImportRequest(
        code: code,
        name: name,
        format: _format,
        isPublic: _isPublic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: const Text('Importer un code'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colle un code de deck Riftbound (Rift Atlas, Piltover Archive…). '
              'Les cartes sont retrouvées dans la cartothèque.',
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: _code,
              label: 'Code de deck',
              placeholder: 'CMAAAAAAAAAA…',
              autocorrect: false,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AdaptiveTextButton(label: 'Coller', onPressed: _paste),
            ),
            AdaptiveTextField(
              controller: _name,
              label: 'Nom du deck',
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FormatChoice(
              value: _format,
              onChanged: (value) => setState(() => _format = value),
            ),
            const SizedBox(height: 8),
            PublicSwitch(
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
          ],
        ),
      ),
      actions: [
        adaptiveAction(
          context,
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
        adaptiveAction(context, label: 'Importer', onPressed: _submit),
      ],
    );
  }
}

/// Choix du format : « Légal » (règles officielles) ou « Illégal » (libre).
class FormatChoice extends StatelessWidget {
  const FormatChoice({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChoicePill(
            label: 'Légal',
            expand: true,
            selected: value == 'tournament',
            onTap: () => onChanged('tournament'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoicePill(
            label: 'Illégal',
            expand: true,
            selected: value == 'free',
            onTap: () => onChanged('free'),
          ),
        ),
      ],
    );
  }
}

/// Interrupteur « Rendre ce deck public ».
class PublicSwitch extends StatelessWidget {
  const PublicSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('Rendre ce deck public')),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}
