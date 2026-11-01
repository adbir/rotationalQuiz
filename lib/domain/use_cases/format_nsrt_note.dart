import 'build_reminders.dart';

/// Writes reminders as an NSRT note: a header line, then one `ph:1` line per
/// reminder in time order. See the NSRT entry in docs/glossary.md.
String formatNsrtNote({
  required int encounterId,
  required String difficulty,
  required String boss,
  required List<Reminder> reminders,
}) {
  final sorted = [...reminders]..sort((a, b) => a.time.compareTo(b.time));
  return [
    'EncounterID:$encounterId;Difficulty:$difficulty;Name:$boss;',
    for (final r in sorted)
      'ph:1;time:${(r.time.inMilliseconds / 1000).toStringAsFixed(1)};tag:${r.label};spellid:${r.spellId};',
  ].join('\n');
}
