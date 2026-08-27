/// Erreur d'API lisible par l'utilisateur.
///
/// `statusCode` null = erreur réseau (pas de réponse du serveur).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => 'ApiException(${statusCode ?? 'réseau'}) : $message';
}
