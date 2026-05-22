import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_shell.dart';

class ViotMonitorApp extends StatelessWidget {
  const ViotMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppShell(),
    );
  }
}
