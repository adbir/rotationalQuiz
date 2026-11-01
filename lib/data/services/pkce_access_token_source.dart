import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'browser_navigation.dart';
import 'local_store.dart';
import 'sha256.dart';

/// The app's public client on Warcraft Logs. It is public by design (PKCE
/// needs no secret); never put a client secret in the app.
const wclPublicClientId = '01a1980b-9e7f-71b2-becb-6ef250010ab0';

/// Where Warcraft Logs sends the user back to: the live site, or the local
/// `flutter run -d chrome --web-port 5000` server.
Uri wclRedirectUri([Uri? base]) {
  final page = base ?? Uri.base;
  return page.host == 'localhost' || page.host == '127.0.0.1'
      ? Uri.parse('http://localhost:5000/')
      : Uri.parse('https://adbir.github.io/rotationalQuiz/');
}

/// Signs the user in to Warcraft Logs with the authorization-code flow and
/// PKCE, and keeps the token in [LocalStore] under `wcl_token`.
///
/// Pass [call] as the `AccessTokenSource` for `WarcraftLogsService`.
class PkceAccessTokenSource extends ChangeNotifier {
  PkceAccessTokenSource({
    required this._store,
    required this._client,
    required this._navigation,
    required this.redirectUri,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static final authorizeEndpoint = Uri.parse(
    'https://www.warcraftlogs.com/oauth/authorize',
  );
  static final tokenEndpoint = Uri.parse(
    'https://www.warcraftlogs.com/oauth/token',
  );
  static const tokenKey = 'wcl_token';
  static const verifierKey = 'wcl_verifier';
  static const stateKey = 'wcl_state';

  final LocalStore _store;
  final http.Client _client;
  final BrowserNavigation _navigation;
  final Uri redirectUri;
  final DateTime Function() _now;
  final Random _random;

  /// Why the last sign-in failed, or `null`.
  String? error;

  /// Expired tokens count as signed out; there is no refresh flow.
  bool get isSignedIn => _readToken() != null;

  /// A valid token, or throws when the user hasn't signed in.
  Future<String> call() async {
    final token = _readToken();
    if (token == null) {
      throw StateError('Sign in to Warcraft Logs on the Setup screen.');
    }
    return token;
  }

  /// Sends the browser to Warcraft Logs. Returns after storing the verifier.
  Future<void> signIn() async {
    final verifier = _randomString(64);
    final state = _randomString(24);
    await _store.setString(verifierKey, verifier);
    await _store.setString(stateKey, state);
    _navigation.goTo(authorizeUri(verifier: verifier, state: state));
  }

  Uri authorizeUri({required String verifier, required String state}) =>
      authorizeEndpoint.replace(
        queryParameters: {
          'client_id': wclPublicClientId,
          'redirect_uri': redirectUri.toString(),
          'response_type': 'code',
          'code_challenge': challengeFor(verifier),
          'code_challenge_method': 'S256',
          'state': state,
        },
      );

  /// The S256 challenge: base64url (no padding) of SHA-256 of the verifier.
  static String challengeFor(String verifier) =>
      base64UrlEncode(sha256(ascii.encode(verifier))).replaceAll('=', '');

  /// Call once on startup. If the page has a `?code=` return, trades it for a
  /// token and removes the query from the address bar.
  Future<void> handleRedirect() async {
    final params = _navigation.current.queryParameters;
    final code = params['code'];
    final failure = params['error'];
    if (code == null && failure == null) return;
    _navigation.replaceUrl(redirectUri);

    final verifier = _store.getString(verifierKey);
    final state = _store.getString(stateKey);
    await _store.remove(verifierKey);
    await _store.remove(stateKey);
    if (failure != null) {
      error = 'Warcraft Logs refused the sign-in ($failure).';
    } else if (verifier == null || state != params['state']) {
      error = 'Sign-in was not started from this browser. Try again.';
    } else {
      await _exchange(code!, verifier);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _store.remove(tokenKey);
    error = null;
    notifyListeners();
  }

  Future<void> _exchange(String code, String verifier) async {
    try {
      final response = await _client.post(
        tokenEndpoint,
        body: {
          'client_id': wclPublicClientId,
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': redirectUri.toString(),
        },
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['access_token'];
      if (response.statusCode != 200 || token is! String) {
        error = 'Warcraft Logs rejected the sign-in (${response.statusCode}).';
        return;
      }
      final lifetime = Duration(seconds: (body['expires_in'] as num).toInt());
      await _store.setString(
        tokenKey,
        jsonEncode({
          'access_token': token,
          'expires_at': _now().add(lifetime).millisecondsSinceEpoch,
        }),
      );
      error = null;
    } on Object catch (e) {
      error = 'Could not reach Warcraft Logs: $e';
    }
  }

  String? _readToken() {
    final raw = _store.getString(tokenKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        (json['expires_at'] as num).toInt(),
      );
      return _now().isBefore(expiresAt) ? json['access_token'] as String : null;
    } on Object {
      return null;
    }
  }

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  String _randomString(int length) => String.fromCharCodes([
    for (var i = 0; i < length; i++)
      _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
  ]);
}
