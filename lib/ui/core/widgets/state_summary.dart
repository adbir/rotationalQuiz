import 'package:flutter/material.dart';

import '../../../domain/models/combat_state.dart';
import '../../../domain/models/spec_definition.dart';
import '../../../domain/specs/rotation_spec.dart';

/// A compact, read-only description of a [CombatState], as a player would
/// glance at it in game.
class StateSummary extends StatelessWidget {
  const StateSummary({super.key, required this.spec, required this.state});

  final RotationSpec spec;
  final CombatState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auras = [
      for (final aura in spec.auras)
        if (aura.kind == AuraKind.buff &&
            aura.quizChance != null &&
            state.buff(aura.id).isUp)
          (aura, state.buff(aura.id)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(spec.resourceLabel, style: theme.textTheme.labelLarge),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.resource / state.maxResource,
                  minHeight: 14,
                  color: const Color(0xFF0070DD),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${state.resource.round()} / ${state.maxResource.round()}',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Target',
          chips: [
            for (final dot in spec.auras)
              if (dot.kind == AuraKind.dot)
                state.dot(dot.id).isUp
                    ? '${dot.name} ${_seconds(state.dot(dot.id).remains)}'
                    : 'No ${dot.name}',
            if (state.targetCasting) 'Casting!',
            if (state.moving) 'You must move',
            'Fight ends in ${_seconds(state.fightRemains)}',
          ],
        ),
        _Section(
          title: 'Buffs',
          chips: [
            for (final (definition, aura) in auras)
              definition.maxStacks > 1
                  ? '${definition.name} ×${aura.stacks}'
                  : definition.name,
            if (auras.isEmpty) 'None',
          ],
        ),
        _Section(
          title: 'Cooldowns',
          chips: [
            for (final cooldown in spec.cooldowns)
              if (cooldown.requiredTalent == null ||
                  state.hasTalent(cooldown.requiredTalent!))
                _cooldownLabel(cooldown, state.cooldown(cooldown.id)),
          ],
        ),
      ],
    );
  }

  static String _cooldownLabel(
    CooldownDefinition definition,
    CooldownState cd,
  ) {
    if (definition.maxCharges != null) {
      final charges = cd.charges ?? definition.maxCharges!.toDouble();
      return '${definition.name}: ${charges.toStringAsFixed(1)} charges';
    }
    return cd.remains <= 0
        ? '${definition.name}: ready'
        : '${definition.name}: ${_seconds(cd.remains)}';
  }

  static String _seconds(double s) => '${s.toStringAsFixed(s < 10 ? 1 : 0)}s';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.chips});

  final String title;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in chips)
                Chip(
                  label: Text(chip),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
