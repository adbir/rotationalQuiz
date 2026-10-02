import 'package:flutter/material.dart';

import '../../../../domain/apl/apl_document.dart';
import '../view_models/apl_viewer_view_model.dart';

/// Read the APL the sandbox is using, grouped by action list.
class AplViewerScreen extends StatelessWidget {
  const AplViewerScreen({super.key, required this.viewModel});

  final AplViewerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final document = viewModel.document;
        final theme = Theme.of(context);
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final focus = viewModel.spec.focusList;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${viewModel.spec.name} APL',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Source: ${document.origin}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: viewModel.busy ? null : viewModel.refreshFromSimc,
                  icon: viewModel.busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: const Text('Update from SimulationCraft'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showPasteDialog(context),
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste APL'),
                ),
                TextButton(
                  onPressed: viewModel.restoreBundled,
                  child: const Text('Use bundled'),
                ),
              ],
            ),
            if (viewModel.message case final message?) ...[
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            for (final list in document.lists.values)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  initiallyExpanded: list.name == focus,
                  title: Text('actions.${list.name}'),
                  subtitle: Text('${list.actions.length} lines'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final action in list.actions) _ActionLine(action),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showPasteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste a SimC APL'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: 'actions=...\nactions.single_target=...',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (source != null && source.trim().isNotEmpty) {
      viewModel.usePasted(source);
    }
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine(this.action);

  final AplAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = action.options.entries
        .where((e) => e.key != 'if')
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final comment in action.comments)
            Text(
              '# $comment',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${action.index + 1}. ',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
                TextSpan(
                  text: action.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (options.isNotEmpty) TextSpan(text: '  [$options]'),
              ],
            ),
          ),
          if (action.conditionSource != null)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: SelectableText(
                'if ${action.conditionSource}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: action.conditionError == null
                      ? null
                      : theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
