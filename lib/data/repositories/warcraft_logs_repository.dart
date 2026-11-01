import '../../domain/models/enemy_group.dart';
import '../../domain/models/enemy_presence.dart';
import '../../domain/models/fight_log.dart';
import '../../domain/models/spec_definition.dart';
import '../../domain/specs/rotation_spec.dart';
import '../../utils/result.dart';
import '../services/warcraft_logs_service.dart';
import 'warcraft_logs_hits.dart';
import 'warcraft_logs_mapper.dart';

/// Fetches fights and rankings from Warcraft Logs as domain models.
class WarcraftLogsRepository {
  WarcraftLogsRepository({required this.spec, required this._service});

  /// The longest silence in the player's hits on a boss that still counts as
  /// hittable. The doc's 8 s, from rank 1 and rank 28 of Coiled Altar.
  static const bossHitGap = Duration(seconds: 8);

  final RotationSpec spec;
  final WarcraftLogsService _service;

  /// One player's data for one fight. Identify the player by [sourceId], as
  /// a report URL does, or by [playerName], as rankings do. With
  /// [includeTargetsHit] the player's damage is read too, to set
  /// [LogCast.targetsHit] (a page or so more, about 2 points).
  Future<Result<FightLog>> loadFight({
    required String reportCode,
    required int fightId,
    int? sourceId,
    String? playerName,
    bool includeTargetsHit = false,
  }) async {
    try {
      final report = await _service.report(code: reportCode, fightId: fightId);
      final fight = _firstMap(report['fights']);
      if (fight == null) {
        throw WarcraftLogsException('Fight $fightId was not found.');
      }
      final masterData = report['masterData'];
      final actor = _findPlayer(masterData, sourceId, playerName);
      final id = (actor['id']! as num).toInt();
      final start = WarcraftLogsMapper.fightStart(fight);

      Future<List<JsonMap>> events(
        WclEventType type, {
        bool includeResources = false,
        int? abilityId,
      }) => _service.events(
        code: reportCode,
        fightId: fightId,
        sourceId: id,
        abilityId: abilityId,
        type: type,
        start: start,
        end: WarcraftLogsMapper.fightEnd(fight),
        includeResources: includeResources,
      );

      final casts = await events(WclEventType.casts, includeResources: true);
      final resources = await events(WclEventType.resources);
      final buffs = await events(WclEventType.buffs);
      final info = await events(WclEventType.combatantInfo);
      final debuffs = <JsonMap>[
        for (final aura in spec.auras)
          if (aura.kind == AuraKind.dot && aura.spellId != null)
            ...await events(WclEventType.debuffs, abilityId: aura.spellId),
      ];
      final buffTable = await _service.buffTable(
        code: reportCode,
        fightId: fightId,
        sourceId: id,
        start: start,
        end: WarcraftLogsMapper.fightEnd(fight),
      );
      final damage = includeTargetsHit
          ? await events(WclEventType.damageDone)
          : const <JsonMap>[];

      return Result.ok(
        FightLog(
          reportCode: reportCode,
          fight: WarcraftLogsMapper.fight(fight),
          playerName: actor['name'] as String? ?? '',
          playerId: id,
          abilityNames: _abilityNames(masterData),
          casts: WarcraftLogsMapper.withTargetsHit(
            [
              for (final row in casts)
                ?WarcraftLogsMapper.cast(
                  row,
                  start,
                  aliases: spec.logRules.castAliases,
                ),
            ],
            damage,
            start,
            id,
            spec.logRules.aoeDamage,
          ),
          resourceGains: [
            for (final row in resources)
              ?WarcraftLogsMapper.resourceGain(row, start),
          ],
          buffEvents: [
            for (final row in buffs) ?WarcraftLogsMapper.buffEvent(row, start),
          ],
          talents: _talentTokens(info),
          debuffEvents: [
            for (final row in debuffs)
              ?WarcraftLogsMapper.buffEvent(row, start),
          ],
          receivedBuffs: WarcraftLogsMapper.receivedBuffs(buffTable),
        ),
      );
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  /// The extra enemies of a fight (adds): enemy NPCs with more than one copy,
  /// since the boss has one. Costs one query per kind.
  Future<Result<List<EnemyGroup>>> loadEnemyGroups({
    required String reportCode,
    required int fightId,
  }) async {
    try {
      return Result.ok((await _enemyGroups(reportCode, fightId)).$1);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  /// Which enemies were up and when: each kind of add with when every copy
  /// arrived and left, and the bosses throughout. Only adds the player
  /// ([playerId]) damaged count. Costs what [loadEnemyGroups] does for those
  /// kinds, one query for every enemy death, the player's damage, and one more
  /// for each kind of add with no death in the log (see
  /// `docs/warcraft-logs.md`, "Enemies alive"). `hitGroups` come from the same
  /// damage page, at no cost.
  Future<Result<EnemyPresence>> loadEnemyPresence({
    required String reportCode,
    required int fightId,
    required int playerId,
  }) async {
    try {
      final (groups, hitGroups) = await _enemyGroups(
        reportCode,
        fightId,
        playerId: playerId,
      );
      return Result.ok(EnemyPresence(groups, hitGroups: hitGroups));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  /// The ability ids of the player's own spells on damage events: the spell
  /// table's, and the damage ids of the area abilities in the log rules. Gear
  /// procs are not among them.
  Set<int> get _damageIds => {
    for (final spell in spec.spells.values) ?spell.spellId,
    for (final aoe in spec.logRules.aoeDamage.values) aoe.damageId,
  };

  /// The enemies alive (casts, deaths) and, with a [playerId], the stretches
  /// the player's own spells hit each kind, from the same damage page.
  Future<(List<EnemyGroup>, List<EnemyGroup>)> _enemyGroups(
    String reportCode,
    int fightId, {
    int? playerId,
  }) async {
    final withDepartures = playerId != null;
    final report = await _service.report(code: reportCode, fightId: fightId);
    final fight = _firstMap(report['fights']);
    if (fight == null) {
      throw WarcraftLogsException('Fight $fightId was not found.');
    }
    final masterData = report['masterData'];
    final npcs = masterData is JsonMap ? masterData['npcs'] : null;
    final names = {
      if (npcs is List)
        for (final npc in npcs.whereType<JsonMap>())
          if (npc['id'] case final num id) id.toInt(): npc['name'],
    };
    final start = WarcraftLogsMapper.fightStart(fight);
    Future<List<JsonMap>> enemyEvents(WclEventType type, [int? source]) =>
        _service.events(
          code: reportCode,
          fightId: fightId,
          sourceId: source,
          type: type,
          start: start,
          end: WarcraftLogsMapper.fightEnd(fight),
          enemy: true,
        );

    final deaths = withDepartures
        ? await enemyEvents(WclEventType.deaths)
        : const <JsonMap>[];
    // ponytail: an add counts only if the player damaged it, which drops
    // Barbed Bulwark (crowd controlled, not killed). A kind the player simply
    // ignored drops out too; the ceiling is a fight with a real add left alone.
    final damage = playerId == null
        ? null
        : await _service.events(
            code: reportCode,
            fightId: fightId,
            sourceId: playerId,
            type: WclEventType.damageDone,
            start: start,
            end: WarcraftLogsMapper.fightEnd(fight),
          );
    final hits = damage == null
        ? null
        : WarcraftLogsMapper.reallyDamaged(damage, playerId!);
    final hitGroups = <EnemyGroup>[];
    final hitRows = damage == null ? null : WarcraftLogsHits(damage, playerId!);
    final enemies = fight['enemyNPCs'];
    final groups = <EnemyGroup>[];
    for (final npc
        in enemies is List ? enemies.whereType<JsonMap>() : <JsonMap>[]) {
      final id = npc['id'];
      final copies = npc['instanceCount'];
      if (id is! num || copies is! num || copies < 1) continue;
      final name = names[id.toInt()] as String? ?? 'Enemy ${id.toInt()}';
      if (hitRows != null) {
        // ponytail: a copy is up while the player's own spells keep hitting
        // it (gear procs and pets don't), in stretches split at bossHitGap. The
        // ceiling is a copy in reach that the player ignored: it reads as
        // absent. A boss never hit this way keeps the whole-fight span.
        final spans = WarcraftLogsHits.spansOfCopies(
          name,
          hitRows.timesByCopy(id.toInt(), _damageIds).values,
          start,
          bossHitGap,
        );
        if (spans != null) {
          hitGroups.add(spans);
        } else if (copies == 1) {
          hitGroups.add(
            EnemyGroup(name: name, arrivals: const [Duration.zero]),
          );
        }
      }
      if (copies == 1) {
        if (withDepartures) {
          // ponytail: a boss is hittable while the player keeps hitting it; a
          // silence over bossHitGap ends the stretch. The ceiling is a boss
          // the player chose to ignore while it was hittable. No hits at all
          // keeps the whole-fight span.
          groups.add(
            WarcraftLogsMapper.hittableSpans(
                  name,
                  hits?[id.toInt()] ?? const [],
                  start,
                  bossHitGap,
                ) ??
                EnemyGroup(name: name, arrivals: const [Duration.zero]),
          );
        }
        continue;
      }
      if (hits != null && !hits.containsKey(id.toInt())) continue;
      final casts = await enemyEvents(WclEventType.casts, id.toInt());
      var ends = [
        for (final death in deaths)
          if (death['targetID'] == id) death,
      ];
      // Some adds die without a death event. The last damage they took stands
      // in for it.
      final noDeaths = withDepartures && ends.isEmpty;
      if (noDeaths) {
        ends = await enemyEvents(WclEventType.damageTaken, id.toInt());
      }
      groups.add(
        WarcraftLogsMapper.enemyGroup(
          name,
          casts,
          start,
          endEvents: ends,
          unseenGoneAtArrival: noDeaths,
        ),
      );
    }
    return (groups, hitGroups);
  }

  /// Up to [count] ranked logs for this spec on a boss, best first. Rows with
  /// no public report are left out.
  Future<Result<List<RankedLog>>> topLogs({
    required int encounterId,
    required int difficulty,
    int count = 100,
  }) async {
    try {
      final logs = <RankedLog>[];
      var rank = 0;
      for (var page = 1; logs.length < count; page++) {
        final result = await _service.rankings(
          encounterId: encounterId,
          className: spec.logClassName,
          specName: spec.logSpecName,
          difficulty: difficulty,
          page: page,
          metric: spec.logRules.rankingMetric,
        );
        final rows = result['rankings'];
        if (rows is! List || rows.isEmpty) break;
        for (final row in rows.whereType<JsonMap>()) {
          rank++;
          final log = WarcraftLogsMapper.rankedLog(row, rank);
          if (log != null && logs.length < count) logs.add(log);
        }
        if (result['hasMorePages'] != true) break;
      }
      return Result.ok(logs);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  JsonMap _findPlayer(Object? masterData, int? sourceId, String? playerName) {
    final actors = masterData is JsonMap ? masterData['actors'] : null;
    if (actors is List) {
      for (final actor in actors.whereType<JsonMap>()) {
        final id = actor['id'];
        if (id is num &&
            ((sourceId != null && id.toInt() == sourceId) ||
                (sourceId == null && actor['name'] == playerName))) {
          return actor;
        }
      }
    }
    throw WarcraftLogsException(
      'Player ${sourceId ?? playerName} is not in this report.',
    );
  }

  Map<int, String> _abilityNames(Object? masterData) {
    final abilities = masterData is JsonMap ? masterData['abilities'] : null;
    return {
      if (abilities is List)
        for (final ability in abilities.whereType<JsonMap>())
          if ((ability['gameID'], ability['name']) case (
            final num id,
            final String name,
          ))
            id.toInt(): name,
    };
  }

  Set<String> _talentTokens(List<JsonMap> combatantInfo) {
    final tokens = {
      for (final node in spec.talentTree.nodes)
        for (final entry in node.entries) entry.id: entry.token,
    };
    for (final row in combatantInfo) {
      final ids = WarcraftLogsMapper.talentEntryIds(row);
      if (ids.isNotEmpty) return {for (final id in ids) ?tokens[id]};
    }
    return const {};
  }

  static JsonMap? _firstMap(Object? value) =>
      value is List ? value.whereType<JsonMap>().firstOrNull : null;
}
