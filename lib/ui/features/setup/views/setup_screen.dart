import 'package:flutter/material.dart';

import '../../../../domain/models/spec_definition.dart';
import '../../../core/widgets/spell_button.dart';
import '../view_models/setup_view_model.dart';
import 'keybind_capture_dialog.dart';

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
            final talents = _TalentSection(viewModel: viewModel);
            final keybinds = _KeybindSection(viewModel: viewModel);
            if (constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [talents],
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
              children: [talents, const SizedBox(height: 24), keybinds],
            );
          },
        );
      },
    );
  }
}

class _TalentSection extends StatefulWidget {
  const _TalentSection({required this.viewModel});

  final SetupViewModel viewModel;

  @override
  State<_TalentSection> createState() => _TalentSectionState();
}

class _TalentSectionState extends State<_TalentSection> {
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

class _KeybindSection extends StatelessWidget {
  const _KeybindSection({required this.viewModel});

  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = viewModel;
    final spells = vm.bindableSpells;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Keybinds', style: theme.textTheme.titleLarge),
            ),
            Text(
              '${vm.boundCount}/${spells.length} bound',
              style: theme.textTheme.bodySmall,
            ),
            TextButton(
              onPressed: vm.boundCount == 0 ? null : vm.clearKeybinds,
              child: const Text('Clear all'),
            ),
          ],
        ),
        Text(
          'Use the same keys as in game; the Hot keys quiz uses them. Saved '
          'on this device.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final spell in spells)
                _KeybindRow(
                  spell: spell,
                  label: vm.bindFor(spell.id)?.label,
                  onBind: () async {
                    final keybind = await showKeybindCaptureDialog(
                      context,
                      spell,
                    );
                    if (keybind != null) await vm.bind(spell, keybind);
                  },
                  onClear: () => vm.unbind(spell),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeybindRow extends StatelessWidget {
  const _KeybindRow({
    required this.spell,
    required this.label,
    required this.onBind,
    required this.onClear,
  });

  final SpellDefinition spell;
  final String? label;
  final VoidCallback onBind;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SpellButton(spell: spell, size: 36, showName: false),
      title: Text(spell.name),
      subtitle: spell.offGcd ? const Text('Off the GCD') : null,
      onTap: onBind,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: onBind,
            child: Text(
              label ?? 'Set key',
              style: label == null
                  ? null
                  : theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: label == null ? null : onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
