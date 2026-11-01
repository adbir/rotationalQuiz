import 'package:flutter/material.dart';

import '../../../../domain/models/combat_state.dart';
import '../../../../domain/models/spec_definition.dart';
import '../view_models/sandbox_view_model.dart';
import 'widgets/aura_editor.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/section_header.dart';

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
                key: ValueKey(vm.loadout.id),
                initialValue: vm.loadout,
                decoration: const InputDecoration(
                  labelText: 'Talent loadout',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final loadout in vm.loadouts)
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
        SectionHeader('Resources & situation'),
        LabeledSlider(
          label: spec.resourceLabel,
          value: state.resource,
          max: state.maxResource,
          divisions: (state.maxResource / 5).round(),
          format: (v) => v.round().toString(),
          onChanged: vm.setResource,
        ),
        LabeledSlider(
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
        SectionHeader('Procs, buffs & DoTs'),
        for (final aura in auras)
          AuraEditor(
            aura: aura,
            value: vm.auraState(aura),
            onChanged: (v) => vm.setAura(aura, v),
          ),
        SectionHeader('Cooldowns'),
        for (final cd in cooldowns)
          if (spec.maxCharges(cd, state.talents) case final maxCharges?)
            LabeledSlider(
              label: '${cd.name} charges',
              value: state.cooldown(cd.id).charges ?? maxCharges.toDouble(),
              max: maxCharges.toDouble(),
              divisions: maxCharges * 10,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) =>
                  vm.setCooldown(cd.id, CooldownState(charges: v)),
            )
          else
            LabeledSlider(
              label: cd.name,
              value: state.cooldown(cd.id).remains,
              max: cd.duration,
              divisions: cd.duration.round(),
              format: (v) => v <= 0 ? 'Ready' : '${v.round()}s',
              onChanged: (v) =>
                  vm.setCooldown(cd.id, CooldownState(remains: v)),
            ),
        Row(
          children: [
            Expanded(child: SectionHeader('Talents')),
            if (vm.talentsEdited)
              TextButton.icon(
                onPressed: () => _saveTalents(context),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save as build'),
              ),
          ],
        ),
        Text(
          'Only talents the APL checks are shown. Import your full build in '
          'Setup.',
          style: theme.textTheme.bodySmall,
        ),
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

extension on ScenarioEditor {
  Future<void> _saveTalents(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save talents as a build'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Build name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await viewModel.saveTalentsAs(name);
  }
}
