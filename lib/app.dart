import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/habit_provider.dart';
import 'data/project_provider.dart';
import 'data/settings_provider.dart';
import 'screens/root_nav_screen.dart';
import 'theme/theme_provider.dart';

class HabitsApp extends StatelessWidget {
  const HabitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HabitProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, _) {
          return MaterialApp(
            title: 'Habits',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            // Applies the 12h/24h time preference to every time picker
            // and TimeOfDay.format() call app-wide, not just the
            // screens that explicitly check the setting.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: settingsProvider.use24HourTime,
              ),
              child: child!,
            ),
            home: const RootNavScreen(),
          );
        },
      ),
    );
  }
}
