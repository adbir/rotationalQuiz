import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/apl_repository.dart';
import '../../../../data/repositories/keybind_repository.dart';
import '../../../../data/repositories/talent_build_repository.dart';
import '../../../../domain/apl/apl_evaluator.dart';
import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/keybind.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../../domain/specs/rotation_spec.dart';
import '../../../../domain/use_cases/generate_scenario.dart';
import '../../../../domain/use_cases/pick_answer_options.dart';

enum QuizMode {
  /// Click the right button on your action bar.
  actionBar('Action bar'),

  /// Pick from four options for a snapshot of the fight.
  multipleChoice('Multiple choice'),

  /// Press your real keybind before the timer runs out.
  hotkeys('Hot keys');

  const QuizMode(this.label);

  final String label;
}

/// Why the current question ended.
enum QuizOutcome { correct, wrong, timedOut }

/// Drives quiz mode: deal a random scenario, take a guess, reveal the APL's
/// answer.
class QuizViewModel extends ChangeNotifier {
  QuizViewModel({
    required AplRepository aplRepository,
    required this._talentBuilds,
    required this._keybinds,
    Random? random,
  }) : _aplRepository = aplRepository,
       _evaluator = AplEvaluator(aplRepository.spec),
       _random = random ?? Random(),
       _generate = GenerateScenario(aplRepository.spec, random: random),
       _pickOptions = PickAnswerOptions(random: random) {
    _aplRepository.addListener(nextQuestion);
    _talentBuilds.addListener(_onBuildChanged);
    _keybinds.addListener(notifyListeners);
    _loadoutId = _talentBuilds.active.id;
    if (_aplRepository.document != null) nextQuestion();
  }

  final AplRepository _aplRepository;
  final TalentBuildRepository _talentBuilds;
  final KeybindRepository _keybinds;
  final AplEvaluator _evaluator;
  final Random _random;
  final GenerateScenario _generate;
  final PickAnswerOptions _pickOptions;

  /// How long to show a correct hot-key answer before moving on.
  static const autoAdvanceDelay = Duration(milliseconds: 900);

  RotationSpec get spec => _aplRepository.spec;

  // ---- Settings -----------------------------------------------------------

  QuizMode _mode = QuizMode.actionBar;
  QuizMode get mode => _mode;

  void setMode(QuizMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    nextQuestion();
  }

  Duration _timeLimit = const Duration(seconds: 3);

  /// Time allowed per question in [QuizMode.hotkeys].
  Duration get timeLimit => _timeLimit;

  void setTimeLimit(Duration value) {
    _timeLimit = value;
    notifyListeners();
  }

  bool _showKeybinds = true;

  /// Whether hot-key mode prints binds on the buttons (learning aid).
  bool get showKeybinds => _showKeybinds;

  void setShowKeybinds(bool value) {
    _showKeybinds = value;
    notifyListeners();
  }

  String _loadoutId = '';
  List<TalentLoadout> get loadouts => _talentBuilds.loadouts;
  TalentLoadout get loadout => _talentBuilds.active;

  void selectLoadout(TalentLoadout loadout) => _talentBuilds.setActive(loadout);

  Set<String> _setBonuses = const {};
  Set<String> get setBonuses => _setBonuses;

  void setSetBonus(String id, bool enabled) {
    _setBonuses = enabled
        ? {..._setBonuses, id}
        : ({..._setBonuses}..remove(id));
    nextQuestion();
  }

  // ---- Current question ---------------------------------------------------

  CombatState? _state;

  /// The current scenario; `null` until the APL has loaded.
  CombatState? get state => _state;

  AplRecommendation? _answer;

  /// The APL's answer. Only shown once [isAnswered].
  AplRecommendation? get answer => _answer;

  /// Increments with every new question; views use it to restart timers.
  int get questionNumber => _questionNumber;
  var _questionNumber = 0;

  List<SpellDefinition> _options = const [];

  /// The four choices in [QuizMode.multipleChoice].
  List<SpellDefinition> get options => _options;

  String? _guess;
  String? get guess => _guess;

  QuizOutcome? _outcome;
  QuizOutcome? get outcome => _outcome;
  bool get isAnswered => _outcome != null;
  bool get isCorrect => _outcome == QuizOutcome.correct;

  final Set<String> _offGcdPressed = {};

  /// Off-GCD abilities already pressed for this question (hot keys).
  Set<String> get offGcdPressed => Set.unmodifiable(_offGcdPressed);

  /// Off-GCD abilities the APL wanted pressed before a correct hot-key
  /// answer but that weren't. The answer still counts; the UI reminds the
  /// player.
  List<String> get skippedOffGcd => [
    if (_mode == QuizMode.hotkeys && isCorrect)
      for (final action in _answer?.offGcd ?? const <Never>[])
        if (!_offGcdPressed.contains(action.name)) action.name,
  ];

  DateTime? _startedAt;
  Duration? _reactionTime;

  /// How long the last correct hot-key answer took.
  Duration? get reactionTime => _reactionTime;

  Timer? _timer;

  // ---- Score --------------------------------------------------------------

  int _correct = 0;
  int _answered = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final List<Duration> _reactionTimes = [];
  int get correct => _correct;
  int get answered => _answered;
  int get streak => _streak;
  int get bestStreak => _bestStreak;

  Duration? get averageReactionTime => _reactionTimes.isEmpty
      ? null
      : _reactionTimes.reduce((a, b) => a + b) ~/ _reactionTimes.length;

  void resetScore() {
    _correct = 0;
    _answered = 0;
    _streak = 0;
    _bestStreak = 0;
    _reactionTimes.clear();
    notifyListeners();
  }

  // ---- Action bar ---------------------------------------------------------

  /// GCD abilities you can pick from.
  List<SpellDefinition> get actionBar => [
    if (_state case final state?)
      for (final spell in spec.knownSpells(state))
        if (spell.onActionBar && !spell.offGcd) spell,
  ];

  /// Off-GCD abilities shown on the hot-key bar, since pressing them is part
  /// of the answer there.
  List<SpellDefinition> get offGcdBar => [
    if (_state case final state?)
      for (final spell in spec.knownSpells(state))
        if (spell.offGcd) spell,
  ];

  Keybind? keybindFor(String spellId) => _keybinds.bindFor(spellId);

  /// Action bar spells without a keybind.
  List<SpellDefinition> get unboundSpells => [
    for (final spell in actionBar)
      if (_keybinds.bindFor(spell.id) == null) spell,
  ];

  // ---- Input --------------------------------------------------------------

  void guessSpell(String spellId) {
    if (isAnswered || _answer == null) return;
    final correctId = _answer!.selectedSpellId;
    if (_mode == QuizMode.hotkeys && spellId != correctId) {
      final isOffGcd = _answer!.offGcd.any((a) => a.name == spellId);
      if (isOffGcd) {
        // Weaving the off-GCD button first is right; keep waiting for the
        // GCD ability.
        _offGcdPressed.add(spellId);
        notifyListeners();
        return;
      }
    }
    _finish(
      spellId == correctId ? QuizOutcome.correct : QuizOutcome.wrong,
      spellId,
    );
  }

  /// Handles a key press in hot-key mode. Returns whether the key is bound.
  bool pressKeybind(Keybind keybind) {
    final spellId = _keybinds.spellFor(keybind);
    if (spellId == null) return false;
    guessSpell(spellId);
    return true;
  }

  void _finish(QuizOutcome outcome, String? guess) {
    _timer?.cancel();
    _guess = guess;
    _outcome = outcome;
    _answered++;
    if (outcome == QuizOutcome.correct) {
      _correct++;
      _streak++;
      _bestStreak = max(_bestStreak, _streak);
      if (_mode == QuizMode.hotkeys && _startedAt != null) {
        _reactionTime = DateTime.now().difference(_startedAt!);
        _reactionTimes.add(_reactionTime!);
        _timer = Timer(autoAdvanceDelay, nextQuestion);
      }
    } else {
      _streak = 0;
    }
    notifyListeners();
  }

  /// Deals a new scenario. The filler (the last unconditional line) is
  /// down-weighted so that questions are mostly about interesting decisions.
  void nextQuestion() {
    final document = _aplRepository.document;
    if (document == null) return;
    _timer?.cancel();
    CombatState state;
    AplRecommendation answer;
    var attempts = 0;
    do {
      state = _generate(_talentBuilds.active, setBonuses: _setBonuses);
      answer = _evaluator.recommend(document, state);
      attempts++;
    } while (attempts < 20 &&
        (answer.selected == null ||
            (answer.selected!.condition == null &&
                _random.nextDouble() < 0.7)));
    _state = state;
    _answer = answer;
    _guess = null;
    _outcome = null;
    _reactionTime = null;
    _offGcdPressed.clear();
    _questionNumber++;
    _options = _mode == QuizMode.multipleChoice
        ? _pickOptions(answer, actionBar)
        : const [];
    if (_mode == QuizMode.hotkeys) {
      _startedAt = DateTime.now();
      _timer = Timer(_timeLimit, () => _finish(QuizOutcome.timedOut, null));
    }
    notifyListeners();
  }

  void _onBuildChanged() {
    if (_talentBuilds.active.id == _loadoutId) {
      notifyListeners(); // The list of builds may have changed.
      return;
    }
    _loadoutId = _talentBuilds.active.id;
    nextQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aplRepository.removeListener(nextQuestion);
    _talentBuilds.removeListener(_onBuildChanged);
    _keybinds.removeListener(notifyListeners);
    super.dispose();
  }
}
