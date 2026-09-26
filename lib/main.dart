import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads date/time symbol data (month names, weekday names, ...) for
  // every locale the app ships — needed before any `DateFormat` call
  // that passes an explicit locale (e.g. 'tr'), including from the
  // very first frame.
  await initializeDateFormatting();
  runApp(const HabitsApp());
}
