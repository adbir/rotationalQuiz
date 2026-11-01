import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../data/repositories/warcraft_logs_repository.dart';
import '../../../../data/services/pkce_access_token_source.dart';
import '../../../../domain/models/boss_comparison.dart';
import '../../../../domain/models/enemy_group.dart';
import '../../../../domain/models/fight_log.dart';
import '../../../../domain/models/report_reference.dart';
import '../../../../domain/use_cases/build_reminders.dart';
import '../../../../domain/use_cases/compare_fights.dart';
import '../../../../domain/use_cases/format_nsrt_note.dart';
import '../../../../domain/use_cases/pick_comparison_logs.dart';
import '../../../../utils/result.dart';

enum BossEvaluationStatus { idle, loading, failed, loaded }

/// Compares a pasted Warcraft Logs fight with a similar top log and rank 1.
class BossEvaluationViewModel extends ChangeNotifier {
  BossEvaluationViewModel({required this._repository, required this._signIn}) {
    _signIn.addListener(notifyListeners);
  }

  final WarcraftLogsRepository _repository;
  final PkceAccessTokenSource _signIn;
  var _disposed = false;

  BossEvaluationStatus status = BossEvaluationStatus.idle;

  /// What is being fetched, while [status] is loading.
  String progress = '';

  /// Why the last load failed, while [status] is failed.
  String? error;

  /// The latest result, while [status] is loaded.
  BossComparison? comparison;

  /// The boss the result is for.
  String bossName = '';

  /// Whether the NSRT note also covers waves the top log did not hold for.
  bool get allWaves => _allWaves;
  set allWaves(bool value) {
    _allWaves = value;
    notifyListeners();
  }

  var _allWaves = false;
  FightLog? _topLog;
  var _groups = const <EnemyGroup>[];

  /// The NSRT note for the result: rank 1's pooling, spender and Stormkeeper
  /// timings. Empty when there is no result.
  String get nsrtNote {
    final c = comparison;
    final top = _topLog;
    if (c == null || top == null) return '';
    final reminders = BuildReminders(_repository.spec)(
      reports: c.pooling.isEmpty ? const [] : c.pooling.last,
      casts: top.casts,
      groups: _groups,
      allWaves: _allWaves,
    );
    return formatNsrtNote(
      encounterId: top.fight.encounterId,
      difficulty: switch (top.fight.difficulty) {
        5 => 'Mythic',
        4 => 'Heroic',
        3 => 'Normal',
        _ => 'LFR',
      },
      boss: bossName,
      reminders: reminders,
    );
  }

  /// Puts [nsrtNote] on the clipboard.
  Future<void> copyNsrtNote() =>
      Clipboard.setData(ClipboardData(text: nsrtNote));

  String get resourceLabel => _repository.spec.resourceLabel;

  bool get isSignedIn => _signIn.isSignedIn;

  static const _badLink =
      'That link needs a report, a fight and a player, like '
      'warcraftlogs.com/reports/<code>?fight=18&source=278. Open the fight on '
      'Warcraft Logs, pick yourself in the player list, and copy the address.';

  Future<void> load(String url) async {
    if (status == BossEvaluationStatus.loading || !isSignedIn) return;
    final reference = parseReportUrl(url);
    if (reference == null) return _fail(_badLink);
    status = BossEvaluationStatus.loading;
    comparison = null;
    error = null;
    progress = 'Loading your fight';
    notifyListeners();

    try {
      final mine = _ok(
        await _repository.loadFight(
          reportCode: reference.code,
          fightId: reference.fightId,
          sourceId: reference.sourceId,
        ),
      );
      if (_disposed) return;
      final fight = mine.fight;
      if (fight.encounterId == 0) {
        return _fail('That fight is not a boss encounter.');
      }
      _progress('Loading the rankings');
      final top = _ok(
        await _repository.topLogs(
          encounterId: fight.encounterId,
          difficulty: fight.difficulty,
        ),
      );
      if (_disposed) return;
      if (top.isEmpty) return _fail('No ranked logs for ${fight.name}.');

      final fights = [
        FightToCompare(label: 'You', log: mine, ranked: _rankOf(top, mine)),
      ];
      for (final ranked in const PickComparisonLogs()(top, fight.duration)) {
        _progress('Loading rank ${ranked.rank}');
        final log = _ok(
          await _repository.loadFight(
            reportCode: ranked.reportCode,
            fightId: ranked.fightId,
            playerName: ranked.playerName,
          ),
        );
        if (_disposed) return;
        fights.add(
          FightToCompare(
            label: 'Rank ${ranked.rank}',
            log: log,
            ranked: ranked,
          ),
        );
      }

      _progress('Loading the add waves');
      // Without the adds the stretches fall back to phases.
      final groups = switch (await _repository.loadEnemyGroups(
        reportCode: reference.code,
        fightId: reference.fightId,
      )) {
        Ok<List<EnemyGroup>>(:final value) => value,
        Error<List<EnemyGroup>>() => const <EnemyGroup>[],
      };
      if (_disposed) return;

      comparison = CompareFights(_repository.spec)(fights, groups);
      bossName = fight.name;
      _topLog = fights.last.log;
      _groups = groups;
      status = BossEvaluationStatus.loaded;
      notifyListeners();
    } on Exception catch (e) {
      _fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Your own row in the rankings, if you are in the top logs.
  RankedLog? _rankOf(List<RankedLog> top, FightLog mine) {
    for (final log in top) {
      if (log.reportCode == mine.reportCode && log.fightId == mine.fight.id) {
        return log;
      }
    }
    return null;
  }

  T _ok<T>(Result<T> result) => switch (result) {
    Ok<T>(:final value) => value,
    Error<T>(:final error) => throw error,
  };

  void _progress(String text) {
    progress = text;
    notifyListeners();
  }

  void _fail(String message) {
    status = BossEvaluationStatus.failed;
    error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _signIn.removeListener(notifyListeners);
    super.dispose();
  }
}
