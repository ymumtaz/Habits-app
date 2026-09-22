import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications` for the app's two recap
/// reminders: a daily "how did today go" nudge and a weekly summary
/// nudge.
///
/// Local notifications on Android can't query the database at the
/// moment they fire, so their text is fixed at schedule time. To keep
/// it reasonably fresh without a background isolate, the app
/// reschedules both notifications (same time, updated text) whenever
/// the recap settings screen is touched and once each time the app
/// starts — so the body reflects stats as of the last time you opened
/// the app or changed a recap setting, not a live query at fire time.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _dailyId = 1001;
  static const _weeklyId = 1002;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      // The device's short timezone abbreviation isn't always in the
      // tz database — reminders still fire on the device's real clock
      // either way, this only affects the DST-aware scheduling logic.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Requests the Android 13+ runtime notification permission. Safe to
  /// call on older Android versions / other platforms — it's a no-op
  /// there.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> cancelDaily() async => _plugin.cancel(_dailyId);
  Future<void> cancelWeekly() async => _plugin.cancel(_weeklyId);

  /// Schedules (replacing any existing one) the daily recap for
  /// [hour]:[minute] local time, repeating every day, showing [body].
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      _dailyId,
      'Daily recap',
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_recap',
          'Daily recap',
          channelDescription: 'A daily nudge summarizing today\'s habits',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules (replacing any existing one) the weekly recap for
  /// [hour]:[minute] local time on [weekday] (1=Mon..7=Sun), repeating
  /// every week, showing [body].
  Future<void> scheduleWeekly({
    required int weekday,
    required int hour,
    required int minute,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      _weeklyId,
      'Weekly recap',
      body,
      _nextInstanceOfWeekdayTime(weekday, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_recap',
          'Weekly recap',
          channelDescription: 'A weekly summary of your habits',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(
    int weekday,
    int hour,
    int minute,
  ) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
