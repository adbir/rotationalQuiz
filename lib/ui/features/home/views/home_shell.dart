import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/apl_repository.dart';
import '../../apl_viewer/view_models/apl_viewer_view_model.dart';
import '../../apl_viewer/views/apl_viewer_screen.dart';
import '../../quiz/view_models/quiz_view_model.dart';
import '../../quiz/views/quiz_screen.dart';
import '../../sandbox/view_models/sandbox_view_model.dart';
import '../../sandbox/views/sandbox_screen.dart';

/// Top-level navigation between Sandbox, Quiz and the APL viewer.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final SandboxViewModel _sandbox;
  late final QuizViewModel _quiz;
  late final AplViewerViewModel _aplViewer;
  var _index = 0;

  static const _destinations = [
    (icon: Icons.science_outlined, selected: Icons.science, label: 'Sandbox'),
    (icon: Icons.quiz_outlined, selected: Icons.quiz, label: 'Quiz'),
    (icon: Icons.list_alt_outlined, selected: Icons.list_alt, label: 'APL'),
  ];

  @override
  void initState() {
    super.initState();
    final repository = context.read<AplRepository>();
    _sandbox = SandboxViewModel(repository: repository);
    _quiz = QuizViewModel(repository: repository);
    _aplViewer = AplViewerViewModel(repository: repository);
  }

  @override
  void dispose() {
    _sandbox.dispose();
    _quiz.dispose();
    _aplViewer.dispose();
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
          onOpenInSandbox: (state) {
            _sandbox.loadState(state);
            setState(() => _index = 0);
          },
        ),
        AplViewerScreen(viewModel: _aplViewer),
      ],
    );

    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(title: Text('Rotational Quiz · ${_sandbox.spec.name}')),
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
