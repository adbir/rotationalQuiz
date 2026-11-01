import 'package:flutter/material.dart';

import '../view_models/setup_view_model.dart';
import 'widgets/keybind_section.dart';
import 'widgets/talent_build_section.dart';
import 'widgets/warcraft_logs_section.dart';

/// Your talent build and keybinds.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final message = viewModel.consumeMessage();
        if (message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.maybeOf(context)
                ?.showSnackBar(SnackBar(content: Text(message)));
          });
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final talents = TalentBuildSection(viewModel: viewModel);
            final keybinds = KeybindSection(viewModel: viewModel);
            final logs = WarcraftLogsSection(viewModel: viewModel);
            if (constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [talents, const SizedBox(height: 24), logs],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [keybinds],
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                talents,
                const SizedBox(height: 24),
                logs,
                const SizedBox(height: 24),
                keybinds,
              ],
            );
          },
        );
      },
    );
  }
}
