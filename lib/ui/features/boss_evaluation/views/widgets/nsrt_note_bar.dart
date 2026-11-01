import 'package:flutter/material.dart';

import '../../view_models/boss_evaluation_view_model.dart';

/// Copies rank 1's timings as an NSRT note.
class NsrtNoteBar extends StatelessWidget {
  const NsrtNoteBar({super.key, required this.viewModel});

  final BossEvaluationViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: [
          FilledButton.tonal(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await viewModel.copyNsrtNote();
              messenger.showSnackBar(
                const SnackBar(content: Text('NSRT note copied')),
              );
            },
            child: const Text('Copy NSRT note'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: viewModel.allWaves,
                onChanged: (v) => viewModel.allWaves = v ?? false,
              ),
              const Text('All add waves'),
            ],
          ),
        ],
      ),
    );
  }
}
