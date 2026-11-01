import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/data/services/pkce_access_token_source.dart';
import 'package:rotational_quiz/data/services/sha256.dart';

import '../test_helpers.dart';

void main() {
  late InMemoryStore store;
  late FakeNavigation browser;
  late DateTime clock;
  late List<http.Request> requests;
  late http.Response Function() reply;

  PkceAccessTokenSource build() => PkceAccessTokenSource(
    store: store,
    client: MockClient((request) async {
      requests.add(request);
      return reply();
    }),
    navigation: browser,
    redirectUri: FakeNavigation.site,
    now: () => clock,
    random: Random(1),
  );

  setUp(() {
    store = InMemoryStore();
    browser = FakeNavigation();
    clock = DateTime(2026, 11, 1, 12);
    requests = [];
    reply = () => http.Response(
      '{"access_token":"tok","token_type":"Bearer","expires_in":3600}',
      200,
    );
  });

  test('sha256 matches the known test vectors', () {
    String hex(String text) =>
        sha256(utf8.encode(text))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
    expect(
      hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      hex('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });

  test('the S256 challenge matches the RFC 7636 example', () {
    expect(
      PkceAccessTokenSource.challengeFor(
        'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      ),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('signing in sends the browser to the authorize URL', () async {
    final source = build();
    await source.signIn();

    final url = browser.wentTo!;
    expect(
      '${url.scheme}://${url.host}${url.path}',
      'https://www.warcraftlogs.com/oauth/authorize',
    );
    final q = url.queryParameters;
    expect(q['client_id'], wclPublicClientId);
    expect(q['response_type'], 'code');
    expect(q['code_challenge_method'], 'S256');
    expect(q['redirect_uri'], 'https://adbir.github.io/rotationalQuiz/');
    final verifier = store.getString(PkceAccessTokenSource.verifierKey)!;
    expect(verifier.length, greaterThanOrEqualTo(43));
    expect(q['code_challenge'], PkceAccessTokenSource.challengeFor(verifier));
    expect(q['state'], store.getString(PkceAccessTokenSource.stateKey));
  });

  test('redirect URL is the site, or localhost when run locally', () {
    expect(
      wclRedirectUri(Uri.parse('https://adbir.github.io/rotationalQuiz/')),
      Uri.parse('https://adbir.github.io/rotationalQuiz/'),
    );
    expect(
      wclRedirectUri(Uri.parse('http://localhost:5000/#/x')),
      Uri.parse('http://localhost:5000/'),
    );
  });

  test('returning with a code exchanges it and stores the token', () async {
    final source = build();
    await source.signIn();
    final state = store.getString(PkceAccessTokenSource.stateKey)!;
    final verifier = store.getString(PkceAccessTokenSource.verifierKey)!;
    browser.current = FakeNavigation.site.replace(
      queryParameters: {'code': 'abc123', 'state': state},
    );

    await source.handleRedirect();

    expect(requests.single.url, PkceAccessTokenSource.tokenEndpoint);
    expect(requests.single.bodyFields, {
      'client_id': wclPublicClientId,
      'grant_type': 'authorization_code',
      'code': 'abc123',
      'code_verifier': verifier,
      'redirect_uri': 'https://adbir.github.io/rotationalQuiz/',
    });
    expect(source.isSignedIn, isTrue);
    expect(await source(), 'tok');
    expect(store.getString(PkceAccessTokenSource.tokenKey), contains('tok'));
    expect(browser.current.query, isEmpty, reason: 'code is stripped');
    expect(store.getString(PkceAccessTokenSource.verifierKey), isNull);
  });

  test('a page without a code does nothing', () async {
    final source = build();
    await source.handleRedirect();
    expect(requests, isEmpty);
    expect(source.isSignedIn, isFalse);
  });

  test('a return with the wrong state is refused', () async {
    final source = build();
    await source.signIn();
    browser.current = FakeNavigation.site.replace(
      queryParameters: {'code': 'abc123', 'state': 'forged'},
    );

    await source.handleRedirect();

    expect(requests, isEmpty);
    expect(source.isSignedIn, isFalse);
    expect(source.error, isNotNull);
  });

  test('a rejected exchange leaves the user signed out', () async {
    reply = () => http.Response('{"error":"invalid_grant"}', 400);
    final source = build();
    await source.signIn();
    browser.current = FakeNavigation.site.replace(
      queryParameters: {
        'code': 'x',
        'state': store.getString(PkceAccessTokenSource.stateKey)!,
      },
    );

    await source.handleRedirect();

    expect(source.isSignedIn, isFalse);
    expect(source.error, contains('400'));
  });

  test('the token expires with its lifetime', () async {
    final source = build();
    await source.signIn();
    browser.current = FakeNavigation.site.replace(
      queryParameters: {
        'code': 'x',
        'state': store.getString(PkceAccessTokenSource.stateKey)!,
      },
    );
    await source.handleRedirect();

    clock = clock.add(const Duration(minutes: 59));
    expect(source.isSignedIn, isTrue);

    clock = clock.add(const Duration(minutes: 2));
    expect(source.isSignedIn, isFalse);
    await expectLater(source(), throwsStateError);
  });

  test('signing out clears the stored token', () async {
    final source = build();
    await store.setString(
      PkceAccessTokenSource.tokenKey,
      jsonEncode({
        'access_token': 'tok',
        'expires_at': clock
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      }),
    );
    expect(source.isSignedIn, isTrue);

    await source.signOut();

    expect(source.isSignedIn, isFalse);
    expect(store.getString(PkceAccessTokenSource.tokenKey), isNull);
  });
}
