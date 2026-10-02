import 'package:flutter/material.dart';

import 'ui/core/theme.dart';
import 'ui/features/home/views/home_shell.dart';

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
