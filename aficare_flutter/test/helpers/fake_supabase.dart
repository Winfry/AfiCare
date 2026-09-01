import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://example.supabase.co';
const _anonKey = 'dummy-anon-key';

/// Guard against `Supabase.initialize` being called more than once in the
/// current test process. Each test *file* runs in its own isolate, so a file
/// calling [initSupabase] can initialize independently of other files.
bool _initialized = false;

/// A controllable stand-in for the Supabase HTTP layer.
///
/// Routes requests to canned JSON responses by URL path prefix and records
/// every request, so tests can both shape what the database "returns" and
/// assert exactly what the app sent (table, method, query, and JSON body).
class FakeSupabase {
  final Map<String, Object?> _jsonRoutes = {};
  final Map<String, http.Response> _rawRoutes = {};
  final List<http.Request> requests = [];

  /// Clears all routes and the captured request log between tests.
  void reset() {
    _jsonRoutes.clear();
    _rawRoutes.clear();
    requests.clear();
  }

  /// Serve [body] (encoded to JSON) for requests whose URL path starts with
  /// [pathPrefix], e.g. `/rest/v1/triage_assessments` or `/auth/v1/token`.
  /// Pass a `List` for table `select` responses and a `Map` for objects.
  void routeJson(String pathPrefix, Object? body) {
    _jsonRoutes[pathPrefix] = body;
  }

  /// Serve an exact [http.Response] (e.g. an 500 error) for [pathPrefix].
  /// Takes precedence over any JSON route for the same prefix.
  void routeRaw(String pathPrefix, http.Response response) {
    _rawRoutes[pathPrefix] = response;
  }

  /// Captured requests whose HTTP method is [method] and whose path contains
  /// [pathPart], in the order the app made them.
  Iterable<http.Request> requestsTo(String method, String pathPart) {
    return requests
        .where((r) => r.method == method && r.url.path.contains(pathPart));
  }

  /// Builds the mock client that Supabase will use for every REST/Gotrue call.
  http.Client client() {
    return MockClient((request) async {
      requests.add(request);
      const headers = {'content-type': 'application/json'};
      final path = request.url.path;

      // Every response must carry `request` so that postgrest-dart's
      // `_parseResponse` (line 186) can access `response.request!.method`.
      http.Response wrap(http.Response r) =>
          http.Response(r.body, r.statusCode, headers: r.headers, request: request);

      for (final entry in _rawRoutes.entries) {
        if (path.startsWith(entry.key)) return wrap(entry.value);
      }
      for (final entry in _jsonRoutes.entries) {
        if (path.startsWith(entry.key)) {
          final body = entry.value;
          if (body == null) {
            return wrap(http.Response('', 200, headers: headers));
          }
          return wrap(http.Response(jsonEncode(body), 200, headers: headers));
        }
      }
      return wrap(http.Response(
        request.method == 'GET' ? '[]' : '{}',
        200,
        headers: headers,
      ));
    });
  }
}

/// Initializes the singleton Supabase client backed by [fake]. Only the first
/// call in a test process actually initializes; later calls are no-ops.
Future<void> initSupabase(FakeSupabase fake) async {
  if (_initialized) return;
  // Supabase stores the GoTrue session via shared_preferences; provide an
  // in-memory mock so initialization works without platform channels.
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _anonKey,
    httpClient: fake.client(),
  );
  _initialized = true;
}