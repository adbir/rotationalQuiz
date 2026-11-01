import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../data/repositories/active_spec_repository.dart';

/// Chooses which spec the whole app shows.
class SpecPicker extends StatelessWidget {
  const SpecPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveSpecRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Specialization', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final spec in active.specs)
              ButtonSegment(value: spec.id, label: Text(spec.name)),
          ],
          selected: {active.spec.id},
          onSelectionChanged: (ids) =>
              active.select(active.specs.firstWhere((s) => s.id == ids.single)),
        ),
      ],
    );
  }
}
