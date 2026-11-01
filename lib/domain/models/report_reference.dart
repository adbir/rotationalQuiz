import 'package:flutter/foundation.dart';

/// Which player in which fight of a Warcraft Logs report a link points at.
@immutable
class ReportReference {
  const ReportReference({
    required this.code,
    required this.fightId,
    required this.sourceId,
  });

  final String code;
  final int fightId;

  /// The player's id within the report.
  final int sourceId;
}

final _reportCode = RegExp(r'^[A-Za-z0-9:]+$');

/// Reads `.../reports/<code>?fight=<n>&source=<n>` (the values may also sit
/// after a `#`). Returns `null` when the link names no report, or no numeric
/// fight and source, since both are needed to find one player.
ReportReference? parseReportUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null) return null;
  final segments = uri.pathSegments;
  final at = segments.indexOf('reports');
  if (at < 0 || at + 1 >= segments.length) return null;
  final code = segments[at + 1];
  if (!_reportCode.hasMatch(code)) return null;

  final values = {...uri.queryParameters};
  if (uri.fragment.isNotEmpty) {
    try {
      values.addAll(Uri.splitQueryString(uri.fragment));
    } on FormatException {
      // A fragment that isn't key=value carries no fight or source.
    }
  }
  final fight = int.tryParse(values['fight'] ?? '');
  final source = int.tryParse(values['source'] ?? '');
  if (fight == null || source == null) return null;
  return ReportReference(code: code, fightId: fight, sourceId: source);
}
