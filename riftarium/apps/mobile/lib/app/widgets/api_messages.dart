import '../../core/api_exception.dart';

/// Message affichable d'une erreur de provider.
///
/// Les appels API lèvent des [ApiException] dont le message est déjà en
/// français ; tout le reste (bug, format inattendu) tombe sur une phrase qui
/// dit quoi faire, comme le demande la charte.
String messageOf(Object? error) => error is ApiException
    ? error.message
    : 'Chargement impossible. Réessaie plus tard.';
