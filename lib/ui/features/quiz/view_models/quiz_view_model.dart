import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/apl_repository.dart';
import '../../../../domain/apl/apl_evaluator.dart';
import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/spec_definition.dart';
import '../../../../domain/specs/rotation_spec.dart';
import '../../../../domain/use_cases/generate_scenario.dart';

/// Drives quiz mode: deal a random scenario, take a guess, reveal the APL's
/// answer.
class QuizViewModel extends ChangeNotifier {
  QuizViewModel({required AplRepository repository, Random? random})
    : _repository = repository,
      _evaluator = AplEvaluator(repository.spec),
      _random = random ?? Random(),
      _generate = GenerateScenario(repository.spec, random: random) {
    _loadout = spec.loadouts.first;
    _repository.addListener(_onDocumentChanged);
    if (_repository.document != null) nextQuestion();
  }

  final AplRepository _repository;
  final AplEvaluator _evaluator;
  final Random _random;
  final GenerateScenario _generate;

  RotationSpec get spec => _repository.spec;

  late TalentLoadout _loadout;
  TalentLoadout get loadout => _loadout;

  Set<String> _setBonuses = const {};
  Set<String> get setBonuses => _setBonuses;

  CombatState? _state;

  /// The current scenario; `null` until the APL has loaded.
  CombatState? get state => _state;

  AplRecommendation? _answer;

  /// The APL's answer. Only meaningful once [hasGuessed] is true.
  AplRecommendation? get answer => _answer;

  String? _guess;
  String? get guess => _guess;
  bool get hasGuessed => _guess != null;
  bool get isCorrect => _guess != null && _guess == _answer?.selectedSpellId;

  int _correct = 0;
  int _answered = 0;
  int _streak = 0;
  int get correct => _correct;
  int get answered => _answered;
  int get streak => _streak;

  /// Spells on the quiz action bar for the current talents.
  List<SpellDefinition> get actionBar => [
    if (_state case final state?)
      for (final spell in spec.knownSpells(state))
        if (spell.onActionBar && !spell.offGcd) spell,
  ];

  void selectLoadout(TalentLoadout loadout) {
    _loadout = loadout;
    nextQuestion();
  }

  void setSetBonus(String id, bool enabled) {
    _setBonuses = enabled
        ? {..._setBonuses, id}
        : ({..._setBonuses}..remove(id));
    nextQuestion();
  }

  void guessSpell(String spellId) {
    if (hasGuessed || _answer == null) return;
    _guess = spellId;
    _answered++;
    if (isCorrect) {
      _correct++;
      _streak++;
    } else {
      _streak = 0;
    }
    notifyListeners();
  }

  /// Deals a new scenario. The filler (the last unconditional line) is
  /// down-weighted so that questions are mostly about interesting decisions.
  void nextQuestion() {
    final document = _repository.document;
    if (document == null) return;
    CombatState state;
    AplRecommendation answer;
    var attempts = 0;
    do {
      state = _generate(_loadout, setBonuses: _setBonuses);
      answer = _evaluator.recommend(document, state);
      attempts++;
    } while (attempts < 20 &&
        (answer.selected == null ||
            (answer.selected!.condition == null &&
                _random.nextDouble() < 0.7)));
    _state = state;
    _answer = answer;
    _guess = null;
    notifyListeners();
  }

  void resetScore() {
    _correct = 0;
    _answered = 0;
    _streak = 0;
    notifyListeners();
  }

  void _onDocumentChanged() => nextQuestion();

  @override
  void dispose() {
    _repository.removeListener(_onDocumentChanged);
    super.dispose();
  }
}
