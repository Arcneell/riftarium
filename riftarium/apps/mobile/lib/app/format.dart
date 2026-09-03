/// Formats d'affichage partagés par plusieurs domaines : une seule écriture
/// pour toute l'application.
library;

/// Date courte à la française : `27/08/2026`. L'heure n'est jamais montrée :
/// une date de partie ou d'inscription se lit au jour.
String formatSocialDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
