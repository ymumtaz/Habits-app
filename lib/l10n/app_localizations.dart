import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

/// Hand-written app localization — no code generation. One
/// getter/method per user-facing string, each choosing between the
/// English and Turkish copy based on the active [locale]. Access via
/// `context.l10n` (the [L10n] extension below).
///
/// Organized by the screen or widget each string belongs to, roughly
/// in the order those files appear under `lib/`, so a given string is
/// easy to find again. A `// ---- common ----` section up top holds
/// strings reused across several places (Cancel/Save/Delete and the
/// like) instead of duplicating them per screen.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('tr')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get _tr => locale.languageCode == 'tr';

  /// Picks [en] or [tr] depending on the active locale — every getter
  /// and method below is just this, called once.
  String _s(String en, String tr) => _tr ? tr : en;

  // ==== Common ==========================================================

  String get cancel => _s('Cancel', 'İptal');
  String get save => _s('Save', 'Kaydet');
  String get saveChanges => _s('Save changes', 'Değişiklikleri kaydet');
  String get delete => _s('Delete', 'Sil');
  String get add => _s('Add', 'Ekle');
  String get edit => _s('Edit', 'Düzenle');
  String get rename => _s('Rename', 'Yeniden adlandır');
  String get name => _s('Name', 'İsim');
  String get none => _s('None', 'Yok');
  String get undo => _s('Undo', 'Geri al');
  String get optional => _s('optional', 'isteğe bağlı');
  String get record => _s('Record', 'Kaydet');
  String get clear => _s('Clear', 'Temizle');
  String targetLabel(String value) => _s('Target: $value', 'Hedef: $value');
  String get today => _s('Today', 'Bugün');
  /// Lowercase "today", for mid-sentence use like "Habit — today" — a
  /// dedicated string rather than `today.toLowerCase()` to avoid
  /// Dart's non-Turkish-aware case conversion.
  String get todayLowercase => _s('today', 'bugün');
  String get thisWeek => _s('This week', 'Bu hafta');
  String get thisMonth => _s('This month', 'Bu ay');
  String get last7Days => _s('Last 7 days', 'Son 7 gün');
  String get all => _s('All', 'Tümü');
  String get expand => _s('Expand', 'Genişlet');
  String get collapse => _s('Collapse', 'Daralt');
  String get navHabits => _s('Habits', 'Alışkanlıklar');
  String get navProjects => _s('Projects', 'Projeler');
  String get navInsights => _s('Insights', 'İçgörüler');

  // ==== Enum labels (models/project.dart, theme/app_theme.dart) =======

  String get statusOngoing => _s('Ongoing', 'Devam ediyor');
  String get statusOnHold => _s('On hold', 'Beklemede');
  String get statusCompleted => _s('Completed', 'Tamamlandı');
  String get noOngoingProjects =>
      _s('No ongoing projects.', 'Devam eden proje yok.');
  String get noOnHoldProjects =>
      _s('No on-hold projects.', 'Beklemedeki proje yok.');
  String get noCompletedProjects =>
      _s('No completed projects.', 'Tamamlanmış proje yok.');

  String get themeSystemDefault => _s('System default', 'Sistem varsayılanı');
  String get themeLight => _s('Light', 'Açık');
  String get themeDark => _s('Dark', 'Koyu');
  String get themeNavyTeal => _s('Navy & Teal', 'Lacivert & Deniz Mavisi');
  String get themeLightPink => _s('Light Pink', 'Açık Pembe');
  String get themeGreen => _s('Green', 'Yeşil');

  // ==== Weekdays =========================================================

  String weekdayName(int weekday) => switch (weekday) {
        DateTime.monday => _s('Monday', 'Pazartesi'),
        DateTime.tuesday => _s('Tuesday', 'Salı'),
        DateTime.wednesday => _s('Wednesday', 'Çarşamba'),
        DateTime.thursday => _s('Thursday', 'Perşembe'),
        DateTime.friday => _s('Friday', 'Cuma'),
        DateTime.saturday => _s('Saturday', 'Cumartesi'),
        _ => _s('Sunday', 'Pazar'),
      };

  // ==== Project cards (widgets/project_card.dart) =======================

  String sessionActiveTimeLabel(String duration) =>
      _s('Session active · $duration total', 'Seans aktif · toplam $duration');
  String totalTimeLabel(String duration) =>
      _s('$duration total', 'toplam $duration');
  // The parent row's own total already includes every sub-project's
  // time (see ProjectProvider.totalDurationFor), so the collapsed
  // summary only needs to say how many are folded in underneath.
  String subProjectsCollapsedSummary(int count) => _s(
        '$count sub-project${count == 1 ? '' : 's'}',
        '$count alt proje',
      );
  String get cancelSessionTooltip => _s('Cancel session', 'Seansı iptal et');
  String get cancelSessionTitle => _s('Cancel this session?', 'Bu seans iptal edilsin mi?');
  String cancelSessionMessage(String duration) => _s(
        'Discards the $duration tracked so far — nothing gets recorded.',
        'Şimdiye kadar kaydedilen $duration silinir — hiçbir şey kaydedilmez.',
      );
  String get sessionCancelled => _s('Session cancelled', 'Seans iptal edildi');
  String get deleteSessionTitle => _s('Delete this session?', 'Bu seans silinsin mi?');
  String deleteSessionMessage(String duration, String date) => _s(
        'This removes the $duration session logged on $date. This can\'t be undone.',
        '$date tarihinde kaydedilen $duration\'lık seansı kaldırır. Bu işlem geri alınamaz.',
      );
  String get sessionRemoved => _s('Session removed', 'Seans kaldırıldı');
  String get stillWorkingTitle => _s('Still working?', 'Hâlâ çalışıyor musunuz?');
  String idleDialogMessage(String projectName, String awayLabel) => _s(
        'The "$projectName" timer kept running while the app was in the '
            'background for about $awayLabel. Trim that time from the '
            'recorded session, or keep it as is?',
        '"$projectName" zamanlayıcısı, uygulama yaklaşık $awayLabel süreyle '
            'arka plandayken çalışmaya devam etti. Bu süre kaydedilen '
            'seanstan kırpılsın mı, yoksa olduğu gibi mi kalsın?',
      );
  String get keepIt => _s('Keep it', 'Olduğu gibi bırak');
  String trimLabel(String duration) => _s('Trim $duration', '$duration kırp');

  // ==== Duration formatting (utils/duration_format.dart) ================

  String get hourAbbrev => _s('h', 'sa');
  String get minuteAbbrevShort => _s('m', 'dk');
  String get secondAbbrev => _s('s', 'sn');

  // ==== Habit widgets (widgets/habit_card.dart, log_amount_dialog.dart,
  //      screens/insights_screen.dart, habit_detail_screen.dart) =========

  /// "3/8 pages today" style progress line. [fraction] is already
  /// formatted as "done/target"; [unit] is [Habit.unitLabel]. Turkish
  /// puts "today" (Bugün) first rather than appending it, so this is a
  /// full sentence template rather than string concatenation.
  String habitProgressToday(String fraction, String unit) =>
      _s('$fraction $unit today', 'Bugün $fraction $unit');

  String logTodaysAmountLabel(String unit) =>
      _s('Log today\'s $unit', 'Bugünkü $unit değerini kaydet');
  String loggedTodayAmount(String amount, String unit, String targetSuffix) =>
      _s(
        '$amount $unit logged today$targetSuffix',
        'Bugün $amount$targetSuffix $unit kaydedildi',
      );
  String averageLoggedPerWeekday(String unit) => _s(
        'Average $unit logged on each weekday.',
        'Her hafta içi günü için ortalama kaydedilen $unit.',
      );

  // ==== Home screen (screens/home_screen.dart) ===========================

  String get homeTitle => _s('Habits', 'Alışkanlıklar');
  String get tasksTooltip => _s('Tasks', 'Görevler');
  String get settingsTooltip => _s('Settings', 'Ayarlar');
  String get removedTodaysLog => _s('Removed today\'s log', 'Bugünkü kayıt kaldırıldı');
  String get noHabitsYet => _s('No habits yet', 'Henüz alışkanlık yok');
  String get noHabitsYetSubtitle => _s(
        'Add your first habit — going to the gym, drinking enough water, '
            'cutting screen time — and start a streak.',
        'İlk alışkanlığınızı ekleyin — spor salonuna gitmek, yeterince su '
            'içmek, ekran süresini azaltmak — ve bir seri başlatın.',
      );
  String get addAHabit => _s('Add a habit', 'Alışkanlık ekle');
  String get widgetAddHabitToGetStarted =>
      _s('Add a habit to get started', 'Başlamak için bir alışkanlık ekleyin');
  String widgetDoneToday(int done, int total) =>
      _s('$done/$total done today', 'bugün $done/$total tamamlandı');
  String get addATask => _s('Add a task', 'Görev ekle');
  String tasksForLater(int count) => _s('Tasks for later ($count)', 'Sonraki görevler ($count)');
  String percentThisMonth(int percent) => _s('$percent% this month', 'Bu ay %$percent');
  String overallCompletionAcross(int count) => _s(
        'Overall completion across $count habit${count == 1 ? '' : 's'}',
        '$count alışkanlık genelinde tamamlanma oranı',
      );
  String streakReachedTooltip(int threshold) =>
      _s('$threshold-day streak reached', '$threshold günlük seri tamamlandı');
  String streakNotReachedTooltip(int threshold) => _s(
        '$threshold-day streak — not reached yet',
        '$threshold günlük seri — henüz ulaşılmadı',
      );
  String get dayStreak => _s('day streak', 'günlük seri');
  String get bestStreak => _s('Best streak', 'En iyi seri');
  String get consistencyScoreLabel => _s('Consistency', 'Tutarlılık');
  String shareStreakText(String habitName, int days) =>
      _s('My "$habitName" streak: $days days.', '"$habitName" serim: $days gün.');
  String couldntShareStreak(Object error) =>
      _s('Couldn\'t share streak: $error', 'Seri paylaşılamadı: $error');

  // ==== Recap notifications (utils/recap_text.dart) =====================

  String get openHabitsCheckInToday =>
      _s('Open Habits to check in on today.', 'Bugüne göz atmak için Alışkanlıklar\'ı açın.');
  String dailyRecapBody(int done, int total) =>
      _s('You completed $done/$total habits today.', 'Bugün $done/$total alışkanlığı tamamladınız.');
  String get openHabitsCheckInWeek =>
      _s('Open Habits to check in on your week.', 'Haftanıza göz atmak için Alışkanlıklar\'ı açın.');
  String weeklyRecapBody(int totalDone, int habitCount) => _s(
        'This past week you logged $totalDone completions across $habitCount habits.',
        'Geçen hafta $habitCount alışkanlık boyunca $totalDone tamamlama kaydettiniz.',
      );

  /// Three-letter weekday abbreviation, Mon..Sun by [index] (0-based,
  /// Monday first) — used for compact chart axis labels.
  String weekdayAbbrev(int index) => switch (index) {
        0 => _s('Mon', 'Pzt'),
        1 => _s('Tue', 'Sal'),
        2 => _s('Wed', 'Çar'),
        3 => _s('Thu', 'Per'),
        4 => _s('Fri', 'Cum'),
        5 => _s('Sat', 'Cmt'),
        _ => _s('Sun', 'Paz'),
      };

  /// Single-letter weekday initial, Mon..Sun by [index] (0-based) — the
  /// compact calendar header row (M T W T F S S).
  String weekdayInitial(int index) => switch (index) {
        0 => _s('M', 'P'),
        1 => _s('T', 'S'),
        2 => _s('W', 'Ç'),
        3 => _s('T', 'P'),
        4 => _s('F', 'C'),
        5 => _s('S', 'C'),
        _ => _s('S', 'P'),
      };
  String daysCompleted(int count) => _s(
        '$count day${count == 1 ? '' : 's'} completed',
        '$count gün tamamlandı',
      );
  String get logAFewDaysPattern => _s(
        'Log a few days to see the pattern by day of the week.',
        'Haftanın günlerine göre örüntüyü görmek için birkaç gün kaydedin.',
      );

  // ==== Add/edit habit (screens/add_edit_habit_screen.dart) =============

  String get editHabitTitle => _s('Edit habit', 'Alışkanlığı düzenle');
  String get newHabitTitle => _s('New habit', 'Yeni alışkanlık');
  String get habitNameHintBoolean => _s('e.g. Go to the gym', 'ör. Spor salonuna git');
  String get habitNameHintCount => _s('e.g. Pages of book read', 'ör. Okunan sayfa sayısı');
  String get habitNameHintDuration => _s('e.g. Meditate', 'ör. Meditasyon yap');
  String get titleLabel => _s('Title', 'Başlık');
  String get giveItATitle => _s('Give it a title', 'Bir başlık girin');
  String get notesOptionalLabel => _s('Notes (optional)', 'Notlar (isteğe bağlı)');
  String get typeLabel => _s('Type', 'Tür');
  String get typeDoneNot => _s('Done/not', 'Yapıldı/yapılmadı');
  String get typeCount => _s('Count', 'Sayım');
  String get typeDuration => _s('Duration', 'Süre');
  String get dailyTargetCountLabel => _s('Daily target (e.g. pages)', 'Günlük hedef (ör. sayfa)');
  String get dailyTargetMinutesLabel => _s('Daily target (minutes)', 'Günlük hedef (dakika)');
  String get dailyLimitCountLabel => _s('Daily limit (e.g. pages)', 'Günlük sınır (ör. sayfa)');
  String get dailyLimitMinutesLabel => _s('Daily limit (minutes)', 'Günlük sınır (dakika)');
  String get targetModeAtLeast => _s('At least', 'En az');
  String get targetModeAtMost => _s('At most', 'En fazla');
  String get targetModeAtLeastHelper => _s(
        'Counts as done once you reach this amount.',
        'Bu miktara ulaştığınızda tamamlanmış sayılır.',
      );
  String get targetModeAtMostHelper => _s(
        'Counts as done as long as you stay at or under this amount — '
            'handy for something you want to limit, like screen time.',
        'Bu miktarın altında kaldığınız sürece tamamlanmış sayılır — '
            'ekran süresi gibi sınırlamak istediğiniz şeyler için kullanışlıdır.',
      );
  String get enterNumberGreaterThanZero => _s('Enter a number > 0', '0\'dan büyük bir sayı girin');
  String get unitOptionalLabel => _s('Unit (optional)', 'Birim (isteğe bağlı)');
  String get unitHint => _s('e.g. pages, glasses, reps', 'ör. sayfa, bardak, tekrar');
  String get frequencyLabel => _s('Frequency', 'Sıklık');
  String get targetPerWeekLabel => _s('Target per week', 'Haftalık hedef');
  String toleranceLabel(int count) => _s(
        'Tolerance: allow $count missed day${count == 1 ? '' : 's'}/month',
        'Tolerans: ayda $count kaçırılan güne izin ver',
      );
  String get toleranceDailyExplainer => _s(
        'A tolerated miss doesn\'t break your streak — like a built-in '
            'streak freeze that resets each calendar month.',
        'Tolere edilen bir kaçırma serinizi bozmaz — her takvim ayında '
            'sıfırlanan yerleşik bir seri dondurma gibi.',
      );
  String get toleranceWeeklyExplainer => _s(
        'If a week falls short of target, the shortfall (days short of '
            'target) is covered by this budget instead of breaking your '
            'streak — resets each calendar month.',
        'Bir hafta hedefin altında kalırsa, eksik kalan gün sayısı '
            'serinizi bozmak yerine bu bütçeden karşılanır — her takvim '
            'ayında sıfırlanır.',
      );
  String get iconLabel => _s('Icon', 'Simge');
  String get colorLabel => _s('Color', 'Renk');
  String get createHabit => _s('Create habit', 'Alışkanlık oluştur');

  // ==== Year heatmap (screens/year_heatmap_screen.dart) ==================

  String yearlyOverviewTitle(String habitName) =>
      _s('$habitName — yearly overview', '$habitName — yıllık genel bakış');
  String get last53Weeks => _s('Last 53 weeks', 'Son 53 hafta');
  String daysCompletedInWindow(int count) => _s(
        '$count day${count == 1 ? '' : 's'} completed in this window',
        'Bu pencerede $count gün tamamlandı',
      );
  String get legendNotDone => _s('Not done', 'Yapılmadı');
  String get legendDone => _s('Done', 'Yapıldı');

  // ==== Habit detail (screens/habit_detail_screen.dart) ==================

  String get removeLogTitle => _s('Remove this log?', 'Bu kayıt kaldırılsın mı?');
  String removeLogMessage(String habitName, String date) => _s(
        'This removes $habitName\'s completion for $date. This can\'t be undone.',
        '$date tarihindeki $habitName tamamlaması kaldırılır. Bu işlem geri alınamaz.',
      );
  String removedOnDate(String date) => _s('Removed $date', '$date kaldırıldı');
  String get shareStreakTooltip => _s('Share streak', 'Seriyi paylaş');
  String deleteHabitTitle(String habitName) =>
      _s('Delete "$habitName"?', '"$habitName" silinsin mi?');
  String get deleteHabitMessage => _s(
        'This permanently deletes the habit and its entire completion '
            'history. This can\'t be undone.',
        'Bu, alışkanlığı ve tüm tamamlama geçmişini kalıcı olarak siler. '
            'Bu işlem geri alınamaz.',
      );
  String get archiveMenuItem => _s('Archive', 'Arşivle');
  String get deleteMenuItem => _s('Delete', 'Sil');
  String get currentStreak => _s('Current streak', 'Mevcut seri');
  String toleratesMissedDays(int count) => _s(
        'Tolerates $count missed day${count == 1 ? '' : 's'}/month',
        'Ayda $count kaçırılan güne izin verir',
      );
  String get completedToday => _s('Completed today', 'Bugün tamamlandı');
  String get markDoneToday => _s('Mark done today', 'Bugün için işaretle');
  String get doneLabel => _s('Done', 'Tamamlandı');
  String get byDayOfWeek => _s('By day of the week', 'Haftanın gününe göre');
  String get monthlyOverview => _s('Monthly overview', 'Aylık genel bakış');
  String get tapPastDayBoolean => _s(
        'Tap any past day to log or undo it — handy for backfilling or '
            'testing the streak without waiting for real days to pass.',
        'Kaydetmek veya geri almak için geçmişteki herhangi bir güne '
            'dokunun — gerçek günlerin geçmesini beklemeden geriye dönük '
            'kayıt eklemek veya seriyi test etmek için kullanışlıdır.',
      );
  String get tapDayToLogAmount =>
      _s('Tap any day to log or edit its amount.', 'Miktarını kaydetmek veya düzenlemek için herhangi bir güne dokunun.');
  String get viewYearlyHeatmap => _s('View yearly heatmap', 'Yıllık ısı haritasını görüntüle');
  String get recentHistory => _s('Recent history', 'Son geçmiş');
  String get noCompletionsLoggedYet => _s('No completions logged yet.', 'Henüz tamamlama kaydedilmedi.');
  String get removeThisDayTooltip => _s('Remove this day', 'Bu günü kaldır');

  // ==== Projects screen (screens/projects_screen.dart) ===================

  String get projectsTitle => _s('Projects', 'Projeler');
  String get startASession => _s('Start a session', 'Bir seans başlat');
  String get pausedLabel => _s('Paused', 'Duraklatıldı');
  String get runningLabel => _s('Running', 'Çalışıyor');
  String get pauseTooltip => _s('Pause', 'Duraklat');
  String get resumeTooltip => _s('Resume', 'Devam ettir');
  String get endAndRecordTooltip => _s('End & record', 'Bitir ve kaydet');
  String get timeOverSuffix => _s('over', 'geçti');
  String get timeLeftSuffix => _s('left', 'kaldı');
  String get noProjectsYet => _s('No projects yet', 'Henüz proje yok');
  String get noProjectsYetSubtitle => _s(
        'Add a project and begin a session whenever you work on it — '
            'this becomes your archive of time spent over the years.',
        'Bir proje ekleyin ve üzerinde çalıştığınızda bir seans başlatın '
            '— bu, yıllar içinde harcadığınız zamanın arşivi haline gelir.',
      );
  String get addAProject => _s('Add a project', 'Proje ekle');

  // ==== Project detail (screens/project_detail_screen.dart) =============

  String deleteProjectTitle(String name) => _s('Delete "$name"?', '"$name" silinsin mi?');
  String get deleteProjectMessage => _s(
        'This permanently deletes the project and all of its tracked '
            'time sessions. This can\'t be undone.',
        'Bu, projeyi ve tüm kaydedilmiş zaman seanslarını kalıcı olarak '
            'siler. Bu işlem geri alınamaz.',
      );
  String get totalTimeTracked => _s('Total time tracked', 'Toplam kaydedilen süre');
  String get sessionRunning => _s('Session running', 'Seans çalışıyor');
  String get sessionPaused => _s('Session paused', 'Seans duraklatıldı');
  String partOf(String parentName) => _s('Part of $parentName', '$parentName parçası');
  String get beginSession => _s('Begin session', 'Seansı başlat');
  String get sessionCancelTooltip => _s('Cancel session', 'Seansı iptal et');
  String get beginningEndsOtherSession => _s(
        'Beginning this will end the session running on another project.',
        'Bunu başlatmak, başka bir projede çalışan seansı sonlandırır.',
      );
  String get addAPastSession => _s('Add a past session', 'Geçmiş bir seans ekle');
  String get timeOverview => _s('Time overview', 'Zaman özeti');
  String get subProjects => _s('Sub-projects', 'Alt projeler');
  String get sessions => _s('Sessions', 'Seanslar');
  String get noSessionsLoggedYet => _s('No sessions logged yet.', 'Henüz seans kaydedilmedi.');
  String get deleteSessionTooltip => _s('Delete session', 'Seansı sil');
  String doneOfGoalThisWeek(String done, String goal) =>
      _s('$done of $goal this week', 'Bu hafta $goal hedefinden $done');

  // ==== Add/edit project (screens/add_edit_project_screen.dart) =========

  String get editProjectTitle => _s('Edit project', 'Projeyi düzenle');
  String get newProjectTitle => _s('New project', 'Yeni proje');
  String get projectNameLabel => _s('Name', 'İsim');
  String get projectNameHint => _s('e.g. Master\'s thesis', 'ör. Yüksek lisans tezi');
  String get giveItAName => _s('Give it a name', 'Bir isim girin');
  String get typeDropdownLabel => _s('Type', 'Tür');
  String get manageCategoriesTooltip => _s('Manage categories', 'Kategorileri yönet');
  String get statusLabel => _s('Status', 'Durum');
  String get parentProjectOptionalLabel => _s('Parent project (optional)', 'Üst proje (isteğe bağlı)');
  String get parentProjectHelper => _s(
        'Nest this under another project, e.g. a chapter under a thesis',
        'Bunu başka bir projenin altına yerleştirin, ör. bir tez altında bölüm',
      );
  String get moveToParentTooltip => _s('Move to parent', 'Üst projeye taşı');
  String moveToParentTitle(String name) => _s(
        'Move "$name" to...',
        '"$name" projesini taşı...',
      );
  String get topLevelProjectOption =>
      _s('No parent (top-level)', 'Üst proje yok (en üst düzey)');
  String get weeklyTimeGoal => _s('Weekly time goal', 'Haftalık zaman hedefi');
  String get weeklyTimeGoalSubtitle => _s(
        'Track progress toward hours per week',
        'Haftalık saat hedefine yönelik ilerlemeyi takip edin',
      );
  String get hoursPerWeek => _s('Hours per week', 'Haftalık saat');
  String get enterNumberGreaterThanZeroDecimal => _s('Enter a number > 0', '0\'dan büyük bir sayı girin');
  String get suggestedFromParent => _s('Suggested from parent', 'Üst projeden önerildi');
  String get createProject => _s('Create project', 'Proje oluştur');

  // ==== Manage categories (screens/manage_categories_screen.dart) =======

  String get newCategoryTitle => _s('New category', 'Yeni kategori');
  String get editCategoryTitle => _s('Edit category', 'Kategoriyi düzenle');
  String get projectCategoriesTitle => _s('Project categories', 'Proje kategorileri');
  String get noCategoriesYet => _s('No categories yet — add one below.', 'Henüz kategori yok — aşağıdan bir tane ekleyin.');
  String get addCategory => _s('Add category', 'Kategori ekle');
  String deleteCategoryTitle(String name) => _s('Delete "$name"?', '"$name" silinsin mi?');
  // ==== Task checklist (widgets/task_checklist.dart) =====================

  String get dueToday => _s('Today', 'Bugün');
  String get dueTomorrow => _s('Tomorrow', 'Yarın');
  String get dueYesterday => _s('Yesterday', 'Dün');
  String overdueLabel(String date) => _s('Overdue · $date', 'Gecikmiş · $date');
  String get changeDateTooltip => _s('Change date (long-press to clear)', 'Tarihi değiştir (temizlemek için uzun basın)');
  String get setDateTooltip => _s('Set a date', 'Bir tarih belirle');
  String get addTaskTooltip => _s('Add task', 'Görev ekle');

  // ==== Start session dialog (widgets/start_session_dialog.dart) ========

  String get startASessionTitle => _s('Start a session', 'Bir seans başlat');
  String get projectDropdownLabel => _s('Project', 'Proje');
  String get countdownOption => _s('Countdown', 'Geri sayım');
  String get openTimerOption => _s('Open timer', 'Açık zamanlayıcı');
  String minutesValue(int minutes) => _s('$minutes min', '$minutes dk');
  String get openTimerExplainer => _s(
        'Counts up until you end it — like the timer this app used to '
            'always use.',
        'Siz bitirene kadar sayar — bu uygulamanın eskiden hep '
            'kullandığı zamanlayıcı gibi.',
      );
  String get start => _s('Start', 'Başlat');

  // ==== End session dialog (widgets/end_session_dialog.dart) ============

  String get durationMustBeMoreThanZero => _s('Duration has to be more than 0.', 'Süre 0\'dan fazla olmalıdır.');
  String get endSessionTitle => _s('End session', 'Seansı bitir');
  String get hoursLabel => _s('Hours', 'Saat');
  String get minutesLabel => _s('Minutes', 'Dakika');
  String get wasVeryShortWarning => _s(
        'That was only a few seconds — adjust the duration above if '
            'that\'s not right.',
        'Bu yalnızca birkaç saniyeydi — doğru değilse yukarıdaki süreyi '
            'düzeltin.',
      );
  String get forgotToEndWarning => _s(
        'Forgot to end it earlier? Adjust the duration above before '
            'recording.',
        'Daha önce bitirmeyi mi unuttunuz? Kaydetmeden önce yukarıdaki '
            'süreyi düzeltin.',
      );
  String get editSessionTitle => _s('Edit session', 'Seansı düzenle');
  String get addAPastSessionTitle => _s('Add a past session', 'Geçmiş bir seans ekle');
  String startedAtLabel(String time) => _s('Started at $time', '$time saatinde başladı');

  // ==== Tag picker / manage tags (widgets/tag_picker.dart,
  //      screens/manage_session_tags_screen.dart) =======================

  String get tagsLabel => _s('Tags', 'Etiketler');
  String get newTagHint => _s('New tag', 'Yeni etiket');
  String get addTagTooltip => _s('Add tag', 'Etiket ekle');
  String get renameTagTitle => _s('Rename tag', 'Etiketi yeniden adlandır');
  String get sessionTagsTitle => _s('Session tags', 'Seans etiketleri');
  String get noTagsYet => _s('No tags yet — add one below.', 'Henüz etiket yok — aşağıdan bir tane ekleyin.');
  String get renameTooltip => _s('Rename', 'Yeniden adlandır');
  String get newTagExampleHint => _s('New tag, e.g. Literature review', 'Yeni etiket, ör. Literatür taraması');
  String deleteTagTitle(String name) => _s('Delete "$name"?', '"$name" silinsin mi?');
  String get weeklyTotals => _s('Weekly totals', 'Haftalık toplamlar');

  // ==== Insights (screens/insights_screen.dart) ==========================

  String get insightsTabTitle => _s('Insights', 'İçgörüler');
  String get habitsTab => _s('Habits', 'Alışkanlıklar');
  String get projectsTab => _s('Projects', 'Projeler');
  String get addHabitToSeeStats => _s('Add a habit to see stats here.', 'İstatistikleri görmek için bir alışkanlık ekleyin.');
  String get habitDropdownLabel => _s('Habit', 'Alışkanlık');
  String monthCompletion(int percent, int doneDays, int daysSoFar) => _s(
        '$percent% completion · $doneDays/$daysSoFar days',
        '%$percent tamamlanma · $doneDays/$daysSoFar gün',
      );
  String get openFullHabitPage => _s('Open full habit page', 'Tam alışkanlık sayfasını aç');
  String get addProjectToSeeStats => _s('Add a project to see stats here.', 'İstatistikleri görmek için bir proje ekleyin.');
  String get projectDropdownLabelInsights => _s('Project', 'Proje');
  String get periodWeek => _s('Week', 'Hafta');
  String get periodMonth => _s('Month', 'Ay');
  String get periodYear => _s('Year', 'Yıl');
  String get totalTracked => _s('Total tracked', 'Toplam kaydedilen');
  String get openFullProjectPage => _s('Open full project page', 'Tam proje sayfasını aç');

  // ==== Archived screen (screens/archived_screen.dart) ===================

  String get archivedTitle => _s('Archived', 'Arşivlenmiş');
  String get noArchivedHabits => _s('No archived habits.', 'Arşivlenmiş alışkanlık yok.');
  String get unarchive => _s('Unarchive', 'Arşivden çıkar');
  String get deletePermanentlyTooltip => _s('Delete permanently', 'Kalıcı olarak sil');
  String deleteHabitForeverTitle(String name) => _s('Delete "$name" forever?', '"$name" kalıcı olarak silinsin mi?');
  String get deleteHabitForeverMessage => _s(
        'This permanently deletes the habit and its entire completion '
            'history. This can\'t be undone.',
        'Bu, alışkanlığı ve tüm tamamlama geçmişini kalıcı olarak siler. '
            'Bu işlem geri alınamaz.',
      );
  String get noArchivedProjects => _s('No archived projects.', 'Arşivlenmiş proje yok.');
  String deleteProjectForeverTitle(String name) => _s('Delete "$name" forever?', '"$name" kalıcı olarak silinsin mi?');
  // ==== Backup screen (screens/backup_screen.dart) =======================

  String get backupCreatedStatus => _s('Backup created — choose where to save it.', 'Yedek oluşturuldu — kaydedilecek yeri seçin.');
  String exportFailedStatus(Object error) => _s('Export failed: $error', 'Dışa aktarma başarısız: $error');
  String get notAValidBackupStatus => _s(
        'That file doesn\'t look like a habits app backup — nothing was changed.',
        'Bu dosya bir alışkanlıklar uygulaması yedeği gibi görünmüyor — hiçbir şey değişmedi.',
      );
  String get restoreBackupTitle => _s('Restore this backup?', 'Bu yedek geri yüklensin mi?');
  String get restoreBackupMessage => _s(
        'This replaces ALL current habits, logs, projects, and tracked '
            'time with what\'s in this backup file. Anything you\'ve done '
            'since that backup was made will be lost. This can\'t be undone.',
        'Bu, TÜM mevcut alışkanlıkları, kayıtları, projeleri ve kaydedilen '
            'zamanı bu yedek dosyasındakilerle değiştirir. Bu yedek '
            'alındıktan sonra yaptığınız her şey kaybolur. Bu işlem geri '
            'alınamaz.',
      );
  String get restore => _s('Restore', 'Geri yükle');
  String get restoredStatus => _s(
        'Restored. Your habits and projects are back to that backup\'s state.',
        'Geri yüklendi. Alışkanlıklarınız ve projeleriniz o yedeğin '
            'durumuna döndü.',
      );
  String restoreFailedStatus(Object error) => _s('Restore failed: $error', 'Geri yükleme başarısız: $error');
  String get backupRestoreExplainer => _s(
        'Everything lives only on this phone — habits, logs, projects, '
            'and every tracked minute. Export a backup now and then so a '
            'lost or wiped phone can\'t take years of history with it.',
        'Her şey yalnızca bu telefonda saklanır — alışkanlıklar, kayıtlar, '
            'projeler ve kaydedilen her dakika. Kaybolan veya sıfırlanan '
            'bir telefonun yılların geçmişini de götürmemesi için ara '
            'sıra bir yedek dışa aktarın.',
      );
  String get exportBackup => _s('Export backup', 'Yedeği dışa aktar');
  String get restoreFromBackup => _s('Restore from backup', 'Yedekten geri yükle');

  String get deleteProjectForeverMessage => _s(
        'This permanently deletes the project and its entire tracked '
            'time history. This can\'t be undone.',
        'Bu, projeyi ve tüm kaydedilmiş zaman geçmişini kalıcı olarak '
            'siler. Bu işlem geri alınamaz.',
      );

  String deleteTagMessage(String name) => _s(
        'Any session tagged "$name" will just lose that tag — nothing '
            'else about it changes.',
        '"$name" etiketli her seans yalnızca bu etiketi kaybeder — '
            'başka hiçbir şey değişmez.',
      );
  String get sessionNoteHint => _s(
        'How did it go? What did you do? What\'s next?',
        'Nasıl geçti? Ne yaptınız? Sırada ne var?',
      );
  String get sessionTitleLabel => _s('Title', 'Başlık');
  String get sessionTitleHint => _s(
        'What was this session about?',
        'Bu seans neyle ilgiliydi?',
      );

  String deleteCategoryMessage(String name) => _s(
        'Any project tagged "$name" will just lose that tag — nothing '
            'else about them changes.',
        '"$name" etiketli her proje yalnızca bu etiketi kaybeder — '
            'başka hiçbir şey değişmez.',
      );

  // ==== Settings (screens/appearance_screen.dart) =======================

  String get settingsTitle => _s('Settings', 'Ayarlar');
  String get sectionAppearance => _s('Appearance', 'Görünüm');
  String get sectionTimeFormat => _s('Time format', 'Saat biçimi');
  String get use24HourTime => _s('Use 24-hour time', '24 saat biçimini kullan');
  String get sectionWeek => _s('Week', 'Hafta');
  String get firstDayOfWeek => _s('First day of the week', 'Haftanın ilk günü');
  String get firstDayOfWeekSubtitle => _s(
        'Sets the week boundary used for weekly habit streaks, weekly '
            'time goals, and "this week" figures in Insights.',
        'Haftalık alışkanlık serilerinde, haftalık zaman hedeflerinde ve '
            'İçgörüler\'deki "bu hafta" rakamlarında kullanılan hafta '
            'sınırını belirler.',
      );
  String get sectionSessions => _s('Sessions', 'Seanslar');
  String get defaultSessionLength =>
      _s('Default session length', 'Varsayılan seans süresi');
  String get defaultSessionLengthSubtitle => _s(
        'Pre-fills the countdown when starting a new project session',
        'Yeni bir proje seansı başlatırken geri sayımı önceden doldurur',
      );
  String get minutesAbbrev => _s('min', 'dk');
  String get countUnitFallback => _s('x', 'x');
  String get sessionTags => _s('Session tags', 'Seans etiketleri');
  String get sessionTagsSubtitle => _s(
        'Add, rename, or delete the tags used when ending or logging a '
            'session',
        'Bir seansı bitirirken veya kaydederken kullanılan etiketleri '
            'ekleyin, yeniden adlandırın veya silin',
      );
  String get sectionLanguage => _s('Language', 'Dil');
  String get languageEnglish => _s('English', 'İngilizce');
  String get languageTurkish => _s('Turkish', 'Türkçe');
  String get sectionNotifications => _s('Notifications', 'Bildirimler');
  String get dailyRecap => _s('Daily recap', 'Günlük özet');
  String dailyRecapEnabledSubtitle(String time) =>
      _s('Reminds you at $time', 'Size $time saatinde hatırlatır');
  String get dailyRecapDisabledSubtitle => _s(
        'A nightly nudge with how many habits you completed today',
        'Bugün kaç alışkanlığı tamamladığınızı bildiren akşam hatırlatması',
      );
  String get time => _s('Time', 'Saat');
  String get am => _s('AM', 'ÖÖ');
  String get pm => _s('PM', 'ÖS');
  String get weeklyRecap => _s('Weekly recap', 'Haftalık özet');
  String weeklyRecapEnabledSubtitle(String weekday, String time) => _s(
        'Reminds you $weekday at $time',
        'Size $weekday günü $time saatinde hatırlatır',
      );
  String get weeklyRecapDisabledSubtitle => _s(
        'A weekly nudge summarizing the past 7 days',
        'Son 7 günü özetleyen haftalık hatırlatma',
      );
  String get dailyRecapChannelDescription => _s(
        'A daily nudge summarizing today\'s habits',
        'Bugünün alışkanlıklarını özetleyen günlük hatırlatma',
      );
  String get weeklyRecapChannelDescription => _s(
        'A weekly summary of your habits',
        'Alışkanlıklarınızın haftalık özeti',
      );
  String get sessionInProgressNotifTitle =>
      _s('Session in progress', 'Seans devam ediyor');
  String get sessionPausedNotifTitle =>
      _s('Session paused', 'Seans duraklatıldı');
  String get sessionProgressChannelDescription => _s(
        'Shows the timer while a project session is running',
        'Bir proje seansı çalışırken sayacı gösterir',
      );
  String get day => _s('Day', 'Gün');
  String get sectionNewHabits => _s('New habits', 'Yeni alışkanlıklar');
  String get defaultFrequency =>
      _s('Default frequency', 'Varsayılan sıklık');
  String get defaultFrequencySubtitle => _s(
        'Used to pre-fill the "Add habit" screen',
        '"Alışkanlık ekle" ekranını önceden doldurmak için kullanılır',
      );
  String get frequencyDaily => _s('Daily', 'Günlük');
  String get frequencyWeekly => _s('Weekly', 'Haftalık');
  String completionsThisWeek(int done, int total) =>
      _s('$done/$total this week', 'bu hafta $done/$total');
  String get sectionData => _s('Data', 'Veri');
  String get archived => _s('Archived', 'Arşivlenmiş');
  String get archivedSubtitle => _s(
        'View, restore, or permanently delete archived habits and '
            'projects',
        'Arşivlenmiş alışkanlıkları ve projeleri görüntüleyin, geri '
            'yükleyin veya kalıcı olarak silin',
      );
  String get backupRestore => _s('Backup & restore', 'Yedekle ve geri yükle');
  String get backupRestoreSubtitle => _s(
        'Export everything to a file, or restore from a previous export',
        'Her şeyi bir dosyaya aktarın veya önceki bir yedekten geri yükleyin',
      );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      // SynchronousFuture, not `async =>`: AppLocalizations doesn't
      // actually need to await anything to build (no asset file to
      // read), so resolving synchronously means it's ready in the very
      // first frame — no flash of missing text, and no extra pump
      // needed in widget tests for it to become available.
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// `context.l10n.xxx` — the one way every screen/widget reaches
/// localized strings.
extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
