import 'package:flutter/material.dart';

import '../../../../../domain/models/combat_state.dart';
import '../../../../../domain/models/spec_definition.dart';
import '../../../../core/widgets/spell_icon.dart';
import 'labeled_slider.dart';

/// Checkbox, stack picker and remaining-time slider for one aura.
class AuraEditor extends StatelessWidget {
  const AuraEditor({
    super.key,
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
            SpellIcon(
              spellId: aura.spellId,
              size: 24,
              borderRadius: BorderRadius.circular(4),
              fallback: const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
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
            child: LabeledSlider(
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
