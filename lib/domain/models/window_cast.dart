import 'package:flutter/foundation.dart';

/// One cast made inside a window it belonged before.
@immutable
class WindowCastDetail {
  const WindowCastDetail({
    required this.time,
    required this.remaining,
    required this.lost,
  });

  /// When the cast began, from the pull.
  final Duration time;

  /// How much of the window was left then.
  final Duration remaining;

  /// The window time the cast took: `begincast` to `cast` when both are
  /// logged, else the spell's cast time, which haste shortens.
  final Duration lost;
}

/// Casts of one kind made inside the window they belonged before.
@immutable
class WindowCastMetrics {
  const WindowCastMetrics({required this.name, required this.details});

  final String name;
  final List<WindowCastDetail> details;

  int get count => details.length;

  Duration get timeLost =>
      details.fold(Duration.zero, (sum, d) => sum + d.lost);
}
