import 'package:flutter/material.dart';
import 'theme/industrial_theme.dart';
import 'theme/theme_controller.dart';
import 'router/app_router.dart';

class WorkSyncApp extends StatelessWidget {
  const WorkSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp.router(
          title: 'attendance',
          debugShowCheckedModeBanner: false,
          theme: IndustrialTheme.lightTheme(),
          darkTheme: IndustrialTheme.lightTheme().copyWith(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121C2A),
          ),
          themeMode: themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
