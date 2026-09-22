import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../utils/week_config.dart';

/// Small standalone user preferences that aren't tied to a specific
/// habit/project: default frequency for new habits, 12h/24h time
/// format, first day of the week, and the daily/weekly recap
/// notification schedule. Persisted locally, same pattern as
/// [ThemeProvider].
class SettingsProvider extends ChangeNotifier {
  static const _frequencyKey = 'default_habit_frequency';
  static const _use24HourKey = 'use_24_hour_time';
  static const _firstDayOfWeekKey = 'first_day_of_week';
  static const _dailyRecapEnabledKey = 'daily_recap_enabled';
  static const _dailyRecapHourKey = 'daily_recap_hour';
  static const _dailyRecapMinuteKey = 'daily_recap_minute';
  static const _weeklyRecapEnabledKey = 'weekly_recap_enabled';
  static const _weeklyRecapWeekdayKey = 'weekly_recap_weekday';
  static const _weeklyRecapHourKey = 'weekly_recap_hour';
  static const _weeklyRecapMinuteKey = 'weekly_recap_minute';

  HabitFrequency _defaultHabitFrequency = HabitFrequency.daily;
  bool _use24HourTime = false;
  int _firstDayOfWeek = DateTime.monday;

  bool _dailyRecapEnabled = false;
  int _dailyRecapHour = 20;
  int _dailyRecapMinute = 0;

  bool _weeklyRecapEnabled = false;
  int _weeklyRecapWeekday = DateTime.sunday;
  int _weeklyRecapHour = 19;
  int _weeklyRecapMinute = 0;

  bool _loaded = false;

  HabitFrequency get defaultHabitFrequency => _defaultHabitFrequency;
  bool get use24HourTime => _use24HourTime;
  int get firstDayOfWeek => _firstDayOfWeek;

  bool get dailyRecapEnabled => _dailyRecapEnabled;
  int get dailyRecapHour => _dailyRecapHour;
  int get dailyRecapMinute => _dailyRecapMinute;

  bool get weeklyRecapEnabled => _weeklyRecapEnabled;
  int get weeklyRecapWeekday => _weeklyRecapWeekday;
  int get weeklyRecapHour => _weeklyRecapHour;
  int get weeklyRecapMinute => _weeklyRecapMinute;

  bool get isLoaded => _loaded;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final freq = prefs.getString(_frequencyKey);
      if (freq != null) {
        _defaultHabitFrequency = habitFrequencyFromString(freq);
      }
      _use24HourTime = prefs.getBool(_use24HourKey) ?? false;
      _firstDayOfWeek = prefs.getInt(_firstDayOfWeekKey) ?? DateTime.monday;
      WeekConfig.firstWeekday = _firstDayOfWeek;

      _dailyRecapEnabled = prefs.getBool(_dailyRecapEnabledKey) ?? false;
      _dailyRecapHour = prefs.getInt(_dailyRecapHourKey) ?? 20;
      _dailyRecapMinute = prefs.getInt(_dailyRecapMinuteKey) ?? 0;

      _weeklyRecapEnabled = prefs.getBool(_weeklyRecapEnabledKey) ?? false;
      _weeklyRecapWeekday =
          prefs.getInt(_weeklyRecapWeekdayKey) ?? DateTime.sunday;
      _weeklyRecapHour = prefs.getInt(_weeklyRecapHourKey) ?? 19;
      _weeklyRecapMinute = prefs.getInt(_weeklyRecapMinuteKey) ?? 0;
    } catch (_) {
      // Fall back to defaults if prefs aren't available.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDefaultHabitFrequency(HabitFrequency frequency) async {
    if (frequency == _defaultHabitFrequency) return;
    _defaultHabitFrequency = frequency;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_frequencyKey, frequency.name);
    } catch (_) {}
  }

  Future<void> setUse24HourTime(bool value) async {
    if (value == _use24HourTime) return;
    _use24HourTime = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_use24HourKey, value);
    } catch (_) {}
  }

  /// [weekday] is `DateTime.monday` or `DateTime.sunday`. Updates
  /// [WeekConfig] immediately so streak/weekly-goal math picks it up
  /// right away, without waiting for a provider rebuild.
  Future<void> setFirstDayOfWeek(int weekday) async {
    if (weekday == _firstDayOfWeek) return;
    _firstDayOfWeek = weekday;
    WeekConfig.firstWeekday = weekday;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_firstDayOfWeekKey, weekday);
    } catch (_) {}
  }

  Future<void> setDailyRecapEnabled(bool value) async {
    if (value == _dailyRecapEnabled) return;
    _dailyRecapEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dailyRecapEnabledKey, value);
    } catch (_) {}
  }

  Future<void> setDailyRecapTime(int hour, int minute) async {
    _dailyRecapHour = hour;
    _dailyRecapMinute = minute;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dailyRecapHourKey, hour);
      await prefs.setInt(_dailyRecapMinuteKey, minute);
    } catch (_) {}
  }

  Future<void> setWeeklyRecapEnabled(bool value) async {
    if (value == _weeklyRecapEnabled) return;
    _weeklyRecapEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_weeklyRecapEnabledKey, value);
    } catch (_) {}
  }

  Future<void> setWeeklyRecapTime(int weekday, int hour, int minute) async {
    _weeklyRecapWeekday = weekday;
    _weeklyRecapHour = hour;
    _weeklyRecapMinute = minute;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_weeklyRecapWeekdayKey, weekday);
      await prefs.setInt(_weeklyRecapHourKey, hour);
      await prefs.setInt(_weeklyRecapMinuteKey, minute);
    } catch (_) {}
  }
}
