import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Requête vue par le faux serveur.
class RecordedRequest {
  RecordedRequest(this.options);

  final RequestOptions options;

  String get method => options.method;
  String get path => options.path;
  Map<String, dynamic> get headers => options.headers;
  Map<String, dynamic> get jsonBody =>
      (options.data as Map<String, dynamic>?) ?? const {};
}

/// Réponse préparée : `status` + JSON, ou une erreur réseau simulée.
class FakeResponse {
  const FakeResponse(this.status, this.json);

  const FakeResponse.networkError()
    : status = 0,
      json = const <String, dynamic>{};

  final int status;
  final Map<String, dynamic> json;

  bool get isNetworkError => status == 0;
}

/// Adaptateur Dio en mémoire : répond selon `method path`, enregistre les
/// requêtes. Pas de réseau, pas de plugins natifs.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  final Map<String, FakeResponse> routes;
  final List<RecordedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options));
    final key = '${options.method} ${options.path}';
    final response = routes[key];
    if (response == null) {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Not Found'}),
        404,
        headers: _jsonHeaders,
      );
    }
    if (response.isNetworkError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulé',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response.json),
      response.status,
      headers: _jsonHeaders,
    );
  }

  static final _jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

const sessionJson = {
  'handle': 'ezreal',
  'avatar_url': null,
  'is_admin': false,
  'token': 'jwt-de-test',
};

const profileJson = {
  'id': 7,
  'handle': 'ezreal',
  'bio': 'Explorateur',
  'avatar_card_id': 'OGN-001',
  // Pas d’URL d’avatar : les tests de widgets n’ont pas de réseau.
  'avatar_url': null,
  'created_at': '2026-08-01T10:00:00+00:00',
  'email': 'ezreal@piltover.re',
  'email_verified': true,
  'notify_moderation': true,
  'is_admin': false,
  'stats': {'decks': 3, 'collection': 120},
};
