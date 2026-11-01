import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// A bar that drains over [duration] while [running].
class CountdownBar extends StatefulWidget {
  const CountdownBar({
    super.key,
    required this.duration,
    required this.running,
  });

  final Duration duration;
  final bool running;

  @override
  State<CountdownBar> createState() => CountdownBarBarState();
}

class CountdownBarBarState extends State<CountdownBar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.running) _controller.forward();
  }

  @override
  void didUpdateWidget(CountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.running) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final left = 1 - _controller.value;
        final color = Color.lerp(AppTheme.failColor, AppTheme.passColor, left);
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: left,
            minHeight: 8,
            color: color,
          ),
        );
      },
    );
  }
}
