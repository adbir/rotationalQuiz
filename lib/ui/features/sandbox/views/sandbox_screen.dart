import 'package:flutter/material.dart';

import '../../../core/widgets/recommendation_card.dart';
import '../../../core/widgets/trace_list.dart';
import '../view_models/sandbox_view_model.dart';
import 'scenario_editor.dart';

/// Set up any combat situation and see what the APL presses next.
class SandboxScreen extends StatelessWidget {
  const SandboxScreen({super.key, required this.viewModel});

  final SandboxViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: ScenarioEditor(viewModel: viewModel),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _ResultPane(viewModel: viewModel)),
                ],
              );
            }
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Next button'),
                      Tab(text: 'Scenario'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _ResultPane(viewModel: viewModel),
                        ScenarioEditor(viewModel: viewModel),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ResultPane extends StatelessWidget {
  const _ResultPane({required this.viewModel});

  final SandboxViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final recommendation = viewModel.recommendation;
    if (recommendation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RecommendationCard(
          spec: viewModel.spec,
          recommendation: recommendation,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('APL trace', style: theme.textTheme.titleMedium),
            ),
            Text('Show skipped lines', style: theme.textTheme.bodySmall),
            Switch(
              value: viewModel.showSkipped,
              onChanged: viewModel.setShowSkipped,
            ),
          ],
        ),
        Text(
          'Lines are checked top to bottom; the first one whose condition '
          'passes and whose ability is ready wins. Hover a clause to see its '
          'value.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TraceList(
          spec: viewModel.spec,
          trace: recommendation.trace,
          showSkipped: viewModel.showSkipped,
        ),
      ],
    );
  }
}
