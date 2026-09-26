// A small widget test — checks that HabitCard renders the right text
// and responds to taps, without needing a real device or database.
//
// Run with: flutter test test/habit_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_app/l10n/app_localizations.dart';
import 'package:habits_app/models/habit.dart';
import 'package:habits_app/services/streak_calculator.dart';
import 'package:habits_app/widgets/habit_card.dart';

void main() {
  testWidgets('HabitCard shows the habit name and current streak',
      (tester) async {
    final habit = Habit(
      id: 1,
      name: 'Drink water',
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2024, 1, 1),
    );
    const streak = StreakResult(
      currentStreak: 4,
      bestStreak: 6,
      completionsThisPeriod: 4,
      completedToday: true,
    );

    var tapped = false;
    var toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        // HabitCard reads context.l10n (AppLocalizations) since Turkish
        // localization — without these delegates that lookup finds
        // nothing and throws before the widget ever renders.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HabitCard(
            habit: habit,
            streak: streak,
            onToggleToday: () => toggled = true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Drink water'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // streak badge count

    await tester.tap(find.byKey(const Key('habitCardInkWell')));
    expect(tapped, true);

    await tester.tap(find.byIcon(Icons.check_circle));
    expect(toggled, true);
  });
}
