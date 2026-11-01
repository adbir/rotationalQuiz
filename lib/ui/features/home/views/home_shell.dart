import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app.dart';
import '../../../../data/repositories/apl_repository.dart';
import '../../../../data/repositories/keybind_repository.dart';
import '../../../../data/repositories/talent_build_repository.dart';
import '../../../../data/repositories/warcraft_logs_repository.dart';
import '../../../../data/services/local_store.dart';
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
  // The sandbox, quiz and APL viewer exist only for a spec with an APL.
  SandboxViewModel? _sandbox;
  QuizViewModel? _quiz;
  AplViewerViewModel? _aplViewer;
  late final SetupViewModel _setup;
  late final BossEvaluationViewModel _bossEvaluation;
  late final String _specName;
  var _index = 0;
  var _labels = const <String>[];

  @override
  void initState() {
    super.initState();
    final repository = context.read<AplRepository>();
    final talentBuilds = context.read<TalentBuildRepository>();
    final keybinds = context.read<KeybindRepository>();
    _specName = talentBuilds.spec.name;
    if (talentBuilds.spec.hasApl) {
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
    }
    _setup = SetupViewModel(
      talentBuilds: talentBuilds,
      keybinds: keybinds,
      warcraftLogs: context.read<PkceAccessTokenSource>(),
    );
    _bossEvaluation = BossEvaluationViewModel(
      repository: context.read<WarcraftLogsRepository>(),
      signIn: context.read<PkceAccessTokenSource>(),
      store: context.read<LocalStore>(),
    );
  }

  @override
  void dispose() {
    _sandbox?.dispose();
    _quiz?.dispose();
    _aplViewer?.dispose();
    _setup.dispose();
    _bossEvaluation.dispose();
    super.dispose();
  }

  bool _tabIs(String label) => _labels.indexOf(label) == _index;

  void _open(String label) => setState(() => _index = _labels.indexOf(label));

  @override
  Widget build(BuildContext context) {
    final sandbox = _sandbox;
    final quiz = _quiz;
    final aplViewer = _aplViewer;
    final tabs = [
      if (sandbox != null && quiz != null && aplViewer != null) ...[
        (
          icon: Icons.science_outlined,
          selected: Icons.science,
          label: 'Sandbox',
          screen: SandboxScreen(viewModel: sandbox),
        ),
        (
          icon: Icons.quiz_outlined,
          selected: Icons.quiz,
          label: 'Quiz',
          screen: QuizScreen(
            viewModel: quiz,
            isActive: _tabIs('Quiz'),
            onOpenInSandbox: (state) {
              sandbox.loadState(state);
              _open('Sandbox');
            },
            onOpenSetup: () => _open('Setup'),
          ),
        ),
        (
          icon: Icons.list_alt_outlined,
          selected: Icons.list_alt,
          label: 'APL',
          screen: AplViewerScreen(viewModel: aplViewer),
        ),
      ],
      (
        icon: Icons.tune_outlined,
        selected: Icons.tune,
        label: 'Setup',
        screen: SetupScreen(viewModel: _setup),
      ),
      (
        icon: Icons.insights_outlined,
        selected: Icons.insights,
        label: 'Boss',
        screen: BossEvaluationScreen(
          viewModel: _bossEvaluation,
          onOpenSetup: () => _open('Setup'),
        ),
      ),
    ];
    _labels = [for (final t in tabs) t.label];
    final body = IndexedStack(
      index: _index,
      children: [for (final t in tabs) t.screen],
    );
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(
        title: Text('Rotational Quiz · $_specName'),
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
                    for (final d in tabs)
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
                for (final d in tabs)
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
