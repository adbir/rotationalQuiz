import 'package:flutter/material.dart';

import '../../view_models/setup_view_model.dart';

/// Pick the active talent build, or import one from an export string.
class TalentBuildSection extends StatefulWidget {
  const TalentBuildSection({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  @override
  State<TalentBuildSection> createState() => _TalentBuildSectionState();
}

class _TalentBuildSectionState extends State<TalentBuildSection> {
  final _name = TextEditingController();
  final _exportString = TextEditingController();

  SetupViewModel get vm => widget.viewModel;

  @override
  void dispose() {
    _name.dispose();
    _exportString.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final saved = await vm.importBuild(
      name: _name.text,
      exportString: _exportString.text,
    );
    if (saved) {
      _name.clear();
      _exportString.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = vm.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your talent build', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'The sandbox and quiz use the active build: it decides which '
          'buttons you have and which APL lines apply.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: RadioGroup<String>(
            groupValue: vm.active.id,
            onChanged: (id) {
              final loadout = vm.loadouts.where((l) => l.id == id).firstOrNull;
              if (loadout != null) vm.setActive(loadout);
            },
            child: Column(
              children: [
                for (final loadout in vm.loadouts)
                  RadioListTile<String>(
                    value: loadout.id,
                    title: Text(loadout.name),
                    subtitle: Text(loadout.description ?? ''),
                    secondary: loadout.isCustom
                        ? IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => vm.delete(loadout),
                          )
                        : const Icon(Icons.verified_outlined),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Import from the game', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'In game, open your talents (N), open the loadout menu and choose '
          'Share, then Copy to clipboard. Strings from Wowhead, Raidbots and '
          'SimC "talents=" work too.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Build name',
            hintText: 'e.g. Raid ST',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _exportString,
          minLines: 2,
          maxLines: 4,
          onChanged: vm.updatePreview,
          decoration: const InputDecoration(
            labelText: 'Talent export string',
            hintText: 'CYQAAAAAAAAAAAAAAAAAAAAAAAAAAA…',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        if (preview != null) ...[
          const SizedBox(height: 8),
          _BuildPreviewView(preview: preview),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: preview?.isValid ?? false ? _import : null,
            icon: const Icon(Icons.upload),
            label: const Text('Save build'),
          ),
        ),
      ],
    );
  }
}

class _BuildPreviewView extends StatelessWidget {
  const _BuildPreviewView({required this.preview});

  final BuildPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!preview.isValid) {
      return Text(
        preview.error!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${preview.heroTree ?? 'No hero tree'} · '
          '${preview.totalTalents} talents',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in preview.aplTalents)
              Chip(label: Text(name), visualDensity: VisualDensity.compact),
          ],
        ),
      ],
    );
  }
}
