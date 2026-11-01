import 'package:flutter/material.dart';

import '../../../data/repositories/spell_icon_repository.dart';

/// Makes a [SpellIconRepository] available to [SpellIcon]s below it.
///
/// Optional: without a scope (e.g. in widget tests) icons fall back to their
/// text placeholder.
class SpellIconScope extends InheritedNotifier<SpellIconRepository> {
  const SpellIconScope({
    super.key,
    required SpellIconRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static SpellIconRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpellIconScope>()?.notifier;
}

/// The in-game icon for [spellId], or [fallback] while it loads, when it
/// can't be found, or when there is no [SpellIconScope].
class SpellIcon extends StatelessWidget {
  const SpellIcon({
    super.key,
    required this.spellId,
    required this.size,
    required this.fallback,
    this.borderRadius = BorderRadius.zero,
  });

  final int? spellId;
  final double size;
  final Widget fallback;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final id = spellId;
    final url = id == null
        ? null
        : SpellIconScope.maybeOf(context)?.iconUrl(id);
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Falls back to an <img> element on the web if the CDN doesn't
        // allow cross-origin reads.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded ? fallback : child,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
