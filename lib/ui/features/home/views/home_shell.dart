import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app.dart';
import '../../../../data/repositories/apl_repository.dart';
import '../../../../data/repositories/keybind_repository.dart';
import '../../../../data/repositories/talent_build_repository.dart';
import '../../../../data/repositories/warcraft_logs_repository.dart';
import '../../../../data/services/pkce_access_token_source.dart';
import '../../apl_viewer/view_models/apl_viewer_view_model.dart';
import '../../apl_viewer/views/apl_viewer_screen.dart';
import '../../boss_evaluation/view_models/boss_evaluation_view_model.dart';
import '../../boss_evaluation/views/boss_evaluation_screen.dart';
import '../../quiz/view_models/quiz_view_model.dart';
import '../../quiz/views/quiz_screen.dart';
import '../../sandbox/view_models/sandbox_view_model.dart';
import '../../sandbox/views/sandbox_screen.dart';
import '../../setup/view_models/setup_view_model.dart';
import '../../setup/views/setup_screen.dart';

/// Top-level navigation between the screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final SandboxViewModel _sandbox;
  late final QuizViewModel _quiz;
  late final AplViewerViewModel _aplViewer;
  late final SetupViewModel _setup;
  late final BossEvaluationViewModel _bossEvaluation;
  var _index = 0;

  static const _quizTab = 1;
  static const _setupTab = 3;

  static const _destinations = [
    (icon: Icons.science_outlined, selected: Icons.science, label: 'Sandbox'),
    (icon: Icons.quiz_outlined, selected: Icons.quiz, label: 'Quiz'),
    (icon: Icons.list_alt_outlined, selected: Icons.list_alt, label: 'APL'),
    (icon: Icons.tune_outlined, selected: Icons.tune, label: 'Setup'),
    (icon: Icons.insights_outlined, selected: Icons.insights, label: 'Boss'),
  ];

  @override
  void initState() {
    super.initState();
    final repository = context.read<AplRepository>();
    final talentBuilds = context.read<TalentBuildRepository>();
    final keybinds = context.read<KeybindRepository>();
    _sandbox = SandboxViewModel(
      repository: repository,
      talentBuilds: talentBuilds,
    );
    _quiz = QuizViewModel(
      aplRepository: repository,
      talentBuilds: talentBuilds,
      keybinds: keybinds,
    );
    _aplViewer = AplViewerViewModel(repository: repository);
    _setup = SetupViewModel(
      talentBuilds: talentBuilds,
      keybinds: keybinds,
      warcraftLogs: context.read<PkceAccessTokenSource>(),
    );
    _bossEvaluation = BossEvaluationViewModel(
      repository: context.read<WarcraftLogsRepository>(),
      signIn: context.read<PkceAccessTokenSource>(),
    );
  }

  @override
  void dispose() {
    _sandbox.dispose();
    _quiz.dispose();
    _aplViewer.dispose();
    _setup.dispose();
    _bossEvaluation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        SandboxScreen(viewModel: _sandbox),
        QuizScreen(
          viewModel: _quiz,
          isActive: _index == _quizTab,
          onOpenInSandbox: (state) {
            _sandbox.loadState(state);
            setState(() => _index = 0);
          },
          onOpenSetup: () => setState(() => _index = _setupTab),
        ),
        AplViewerScreen(viewModel: _aplViewer),
        SetupScreen(viewModel: _setup),
        BossEvaluationScreen(
          viewModel: _bossEvaluation,
          onOpenSetup: () => setState(() => _index = _setupTab),
        ),
      ],
    );

    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(
        title: Text('Rotational Quiz · ${_sandbox.spec.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              appVersion,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}
