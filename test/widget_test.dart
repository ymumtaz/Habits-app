// `flutter create .` generates a default counter-app test here that
// references a `MyApp` widget — this project's root widget is
// `HabitsApp` (see lib/app.dart), so that default test doesn't apply
// and was replaced with this placeholder.
//
// The real tests live in:
//   test/streak_calculator_test.dart  (streak math — pure logic)
//   test/habit_card_test.dart         (HabitCard widget)
//
// A full app-level widget test isn't included yet because HabitsApp
// talks to sqflite on startup, which needs platform-channel mocking
// (or the integration_test package) to run outside a real device —
// a good next addition once there's more app to smoke-test.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — see streak_calculator_test.dart and habit_card_test.dart', () {
    expect(true, isTrue);
  });
}
