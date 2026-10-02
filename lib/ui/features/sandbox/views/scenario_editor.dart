import 'package:flutter/material.dart';

import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/spec_definition.dart';
import '../view_models/sandbox_view_model.dart';

/// Controls for every piece of state the APL reads.
class ScenarioEditor extends StatelessWidget {
  const ScenarioEditor({super.key, required this.viewModel});

  final SandboxViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final spec = vm.spec;
    final state = vm.state;
    final theme = Theme.of(context);

    bool visible(String? talent, [String? setBonus]) =>
        (talent == null || state.hasTalent(talent)) &&
        (setBonus == null || state.setBonuses.contains(setBonus));

    final auras = [
      for (final aura in spec.auras)
        if (visible(aura.requiredTalent, aura.requiredSetBonus)) aura,
    ];
    final cooldowns = [
      for (final cd in spec.cooldowns)
        if (visible(cd.requiredTalent)) cd,
    ];
    final talentGroups = <String, List<TalentDefinition>>{};
    for (final talent in spec.talents) {
      talentGroups.putIfAbsent(talent.group, () => []).add(talent);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<TalentLoadout>(
                initialValue: vm.loadout,
                decoration: const InputDecoration(
                  labelText: 'Talent loadout',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final loadout in spec.loadouts)
                    DropdownMenuItem(value: loadout, child: Text(loadout.name)),
                ],
                onChanged: (loadout) {
                  if (loadout != null) vm.selectLoadout(loadout);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Reset scenario',
              onPressed: vm.reset,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Header('Resources & situation'),
        _LabeledSlider(
          label: spec.resourceLabel,
          value: state.resource,
          max: state.maxResource,
          divisions: (state.maxResource / 5).round(),
          format: (v) => v.round().toString(),
          onChanged: vm.setResource,
        ),
        _LabeledSlider(
          label: 'Fight remaining',
          value: state.fightRemains,
          max: 600,
          divisions: 120,
          format: (v) => '${v.round()}s',
          onChanged: vm.setFightRemains,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Moving'),
          value: state.moving,
          onChanged: vm.setMoving,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Target is casting'),
          value: state.targetCasting,
          onChanged: vm.setTargetCasting,
        ),
        for (final bonus in spec.setBonuses)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(bonus.name),
            value: state.setBonuses.contains(bonus.id),
            onChanged: (v) => vm.setSetBonus(bonus.id, v),
          ),
        _Header('Procs, buffs & DoTs'),
        for (final aura in auras)
          _AuraEditor(
            aura: aura,
            value: vm.auraState(aura),
            onChanged: (v) => vm.setAura(aura, v),
          ),
        _Header('Cooldowns'),
        for (final cd in cooldowns)
          cd.maxCharges != null
              ? _LabeledSlider(
                  label: '${cd.name} charges',
                  value:
                      state.cooldown(cd.id).charges ??
                      cd.maxCharges!.toDouble(),
                  max: cd.maxCharges!.toDouble(),
                  divisions: cd.maxCharges! * 10,
                  format: (v) => v.toStringAsFixed(1),
                  onChanged: (v) =>
                      vm.setCooldown(cd.id, CooldownState(charges: v)),
                )
              : _LabeledSlider(
                  label: cd.name,
                  value: state.cooldown(cd.id).remains,
                  max: cd.duration,
                  divisions: cd.duration.round(),
                  format: (v) => v <= 0 ? 'Ready' : '${v.round()}s',
                  onChanged: (v) =>
                      vm.setCooldown(cd.id, CooldownState(remains: v)),
                ),
        _Header('Talents'),
        for (final MapEntry(key: group, value: talents)
            in talentGroups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(group, style: theme.textTheme.labelMedium),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final talent in talents)
                FilterChip(
                  label: Text(talent.name),
                  tooltip: talent.description,
                  selected: state.hasTalent(talent.id),
                  onSelected: (v) => vm.setTalent(talent, v),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            format(value),
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _AuraEditor extends StatelessWidget {
  const _AuraEditor({
    required this.aura,
    required this.value,
    required this.onChanged,
  });

  final AuraDefinition aura;
  final AuraState value;
  final ValueChanged<AuraState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = value.isUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: up,
              onChanged: (v) => onChanged(
                v ?? false
                    ? AuraState(
                        stacks: aura.maxStacks,
                        remains: aura.kind == AuraKind.dot
                            ? aura.duration
                            : aura.duration.clamp(0, 30),
                      )
                    : AuraState.down,
              ),
            ),
            Expanded(
              child: Tooltip(
                message: aura.description ?? '',
                child: Text(aura.name, style: theme.textTheme.bodyMedium),
              ),
            ),
            if (up && aura.maxStacks > 1)
              SegmentedButton<int>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  for (var i = 1; i <= aura.maxStacks; i++)
                    ButtonSegment(value: i, label: Text('$i')),
                ],
                selected: {value.stacks.clamp(1, aura.maxStacks)},
                onSelectionChanged: (s) =>
                    onChanged(value.copyWith(stacks: s.first)),
              ),
          ],
        ),
        if (up)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: _LabeledSlider(
              label: 'remaining',
              value: value.remains,
              max: aura.duration,
              divisions: (aura.duration * 2).round(),
              format: (v) => '${v.toStringAsFixed(1)}s',
              onChanged: (v) =>
                  onChanged(value.copyWith(remains: v < 0.5 ? 0.5 : v)),
            ),
          ),
      ],
    );
  }
}
