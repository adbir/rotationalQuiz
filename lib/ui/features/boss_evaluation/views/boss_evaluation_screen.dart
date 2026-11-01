import 'package:flutter/material.dart';

import '../view_models/boss_evaluation_view_model.dart';
import 'widgets/evaluation_result.dart';

/// Paste a Warcraft Logs fight to see it beside a similar top log and rank 1.
class BossEvaluationScreen extends StatefulWidget {
  const BossEvaluationScreen({
    super.key,
    required this.viewModel,
    required this.onOpenSetup,
  });

  final BossEvaluationViewModel viewModel;

  /// Takes the user to Setup, where they sign in.
  final VoidCallback onOpenSetup;

  @override
  State<BossEvaluationScreen> createState() => _BossEvaluationScreenState();
}

class _BossEvaluationScreenState extends State<BossEvaluationScreen> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final comparison = vm.comparison;
        final loading = vm.status == BossEvaluationStatus.loading;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Boss evaluation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paste a link to your fight, with your player picked: '
                  'warcraftlogs.com/reports/<code>?fight=18&source=278.',
                ),
                const SizedBox(height: 12),
                if (!vm.isSignedIn)
                  _SignInNotice(onOpenSetup: widget.onOpenSetup)
                else ...[
                  TextField(
                    controller: _url,
                    enabled: !loading,
                    decoration: const InputDecoration(
                      labelText: 'Warcraft Logs link',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: vm.load,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: loading ? null : () => vm.load(_url.text),
                      child: const Text('Load'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (loading)
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text('${vm.progress}...'),
                    ],
                  ),
                if (vm.status == BossEvaluationStatus.failed)
                  Text(
                    vm.error ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (comparison != null) EvaluationResult(viewModel: vm),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignInNotice extends StatelessWidget {
  const _SignInNotice({required this.onOpenSetup});

  final VoidCallback onOpenSetup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Text('Sign in to Warcraft Logs on Setup to load a fight.'),
            ),
            TextButton(onPressed: onOpenSetup, child: const Text('Open Setup')),
          ],
        ),
      ),
    );
  }
}
