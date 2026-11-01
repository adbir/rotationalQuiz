import '../../domain/models/enemy_group.dart';
import '../../domain/models/fight_log.dart';
import '../../domain/specs/rotation_spec.dart';
import '../../utils/result.dart';
import '../services/warcraft_logs_service.dart';
import 'warcraft_logs_mapper.dart';

/// Fetches fights and rankings from Warcraft Logs as domain models.
class WarcraftLogsRepository {
  WarcraftLogsRepository({required this.spec, required this._service});

  final RotationSpec spec;
  final WarcraftLogsService _service;

  /// One player's data for one fight. Identify the player by [sourceId], as
  /// a report URL does, or by [playerName], as rankings do.
  Future<Result<FightLog>> loadFight({
    required String reportCode,
    required int fightId,
    int? sourceId,
    String? playerName,
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
      }) => _service.events(
        code: reportCode,
        fightId: fightId,
        sourceId: id,
        type: type,
        start: start,
        end: WarcraftLogsMapper.fightEnd(fight),
        includeResources: includeResources,
      );

      final casts = await events(WclEventType.casts, includeResources: true);
      final resources = await events(WclEventType.resources);
      final buffs = await events(WclEventType.buffs);
      final info = await events(WclEventType.combatantInfo);

      return Result.ok(
        FightLog(
          reportCode: reportCode,
          fight: WarcraftLogsMapper.fight(fight),
          playerName: actor['name'] as String? ?? '',
          playerId: id,
          abilityNames: _abilityNames(masterData),
          casts: [
            for (final row in casts)
              ?WarcraftLogsMapper.cast(
                row,
                start,
                aliases: spec.logRules.castAliases,
              ),
          ],
          resourceGains: [
            for (final row in resources)
              ?WarcraftLogsMapper.resourceGain(row, start),
          ],
          buffEvents: [
            for (final row in buffs) ?WarcraftLogsMapper.buffEvent(row, start),
          ],
          talents: _talentTokens(info),
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
      final enemies = fight['enemyNPCs'];
      final groups = <EnemyGroup>[];
      for (final npc
          in enemies is List ? enemies.whereType<JsonMap>() : <JsonMap>[]) {
        final id = npc['id'];
        final copies = npc['instanceCount'];
        if (id is! num || copies is! num || copies < 2) continue;
        final casts = await _service.events(
          code: reportCode,
          fightId: fightId,
          sourceId: id.toInt(),
          type: WclEventType.casts,
          start: start,
          end: WarcraftLogsMapper.fightEnd(fight),
          enemy: true,
        );
        groups.add(
          EnemyGroup(
            name: names[id.toInt()] as String? ?? 'Enemy ${id.toInt()}',
            arrivals: WarcraftLogsMapper.enemyArrivals(casts, start),
          ),
        );
      }
      return Result.ok(groups);
    } on Exception catch (e) {
      return Result.error(e);
    }
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
