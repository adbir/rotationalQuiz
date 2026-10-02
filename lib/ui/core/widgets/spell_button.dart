import 'package:flutter/material.dart';

import '../../../domain/models/spec_definition.dart';
import '../theme.dart';

/// Visual state of a [SpellButton].
enum SpellButtonMark { none, recommended, correct, wrong, unavailable }

/// A square action-bar style button for a spell.
class SpellButton extends StatelessWidget {
  const SpellButton({
    super.key,
    required this.spell,
    this.onPressed,
    this.mark = SpellButtonMark.none,
    this.size = 56,
    this.showName = true,
    this.tooltip,
  });

  final SpellDefinition spell;
  final VoidCallback? onPressed;
  final SpellButtonMark mark;
  final double size;
  final bool showName;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = AppTheme.schoolColor(spell.school);
    final dimmed = mark == SpellButtonMark.unavailable;
    final borderColor = switch (mark) {
      SpellButtonMark.recommended ||
      SpellButtonMark.correct => AppTheme.passColor,
      SpellButtonMark.wrong => AppTheme.failColor,
      _ => base.withValues(alpha: 0.6),
    };
    final borderWidth = switch (mark) {
      SpellButtonMark.none || SpellButtonMark.unavailable => 1.5,
      _ => 4.0,
    };

    final button = Material(
      color: dimmed ? base.withValues(alpha: 0.25) : base,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.18),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      elevation: mark == SpellButtonMark.recommended ? 6 : 1,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Text(
              spell.abbreviation,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: dimmed ? 0.5 : 1),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.3,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: onPressed != null,
      label: spell.name,
      child: Tooltip(
        message: tooltip ?? spell.name,
        child: showName
            ? SizedBox(
                width: size + 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    button,
                    const SizedBox(height: 4),
                    Text(
                      spell.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              )
            : button,
      ),
    );
  }
}
