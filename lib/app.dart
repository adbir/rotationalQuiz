import 'package:flutter/material.dart';

import 'ui/core/theme.dart';
import 'ui/features/home/views/home_shell.dart';

/// What the deploy built, shown in the title bar so a new build is visible.
/// CI passes `--dart-define=APP_VERSION=...`; local runs show `dev`.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class RotationalQuizApp extends StatelessWidget {
  const RotationalQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rotational Quiz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
