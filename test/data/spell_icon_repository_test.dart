import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotational_quiz/data/repositories/spell_icon_repository.dart';
import 'package:rotational_quiz/data/services/local_store.dart';
import 'package:rotational_quiz/data/services/spell_icon_service.dart';

void main() {
  late int requests;

  /// Answers like Wowhead's tooltip API for the ids in [icons].
  SpellIconService service(Map<int, String> icons) => SpellIconService(
    client: MockClient((request) async {
      requests++;
      final id = int.parse(request.url.pathSegments.last);
      final icon = icons[id];
      if (icon == null) return http.Response('{"error":"no"}', 404);
      return http.Response(jsonEncode({'name': 'X', 'icon': icon}), 200);
    }),
  );

  setUp(() => requests = 0);

  test('looks an icon up once, then serves it from memory', () async {
    final repo = SpellIconRepository(
      service: service({51505: 'spell_shaman_lavaburst'}),
      store: InMemoryStore(),
    );
    var notified = 0;
    repo.addListener(() => notified++);

    expect(repo.iconUrl(51505), isNull);
    expect(repo.iconUrl(51505), isNull, reason: 'no second request');
    await pumpEventQueue();

    expect(notified, 1);
    expect(requests, 1);
    expect(
      repo.iconUrl(51505).toString(),
      'https://wow.zamimg.com/images/wow/icons/large/spell_shaman_lavaburst.jpg',
    );
  });

  test('remembers icons across launches', () async {
    final store = InMemoryStore();
    SpellIconRepository(
      service: service({8042: 'spell_nature_earthshock'}),
      store: store,
    ).iconUrl(8042);
    await pumpEventQueue();

    final reloaded = SpellIconRepository(service: service({}), store: store);
    expect(reloaded.iconUrl(8042), isNotNull);
    expect(requests, 1);
  });

  test('unknown spells and unsafe names give no icon', () async {
    final repo = SpellIconRepository(
      service: service({1: '../../evil?x=<script>'}),
      store: InMemoryStore({'spell_icons': '{"2":"bad name/../x"}'}),
    );
    repo
      ..iconUrl(1)
      ..iconUrl(3);
    await pumpEventQueue();
    expect(repo.iconUrl(1), isNull);
    expect(repo.iconUrl(2), isNull, reason: 'cached names are validated');
    expect(repo.iconUrl(3), isNull);
  });

  test('network failures leave the fallback in place', () async {
    final repo = SpellIconRepository(
      service: SpellIconService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      ),
      store: InMemoryStore(),
    );
    expect(repo.iconUrl(51505), isNull);
    await pumpEventQueue();
    expect(repo.iconUrl(51505), isNull);
  });
}
