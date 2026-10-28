import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/dependent_profile_model.dart';
import '../models/medication_reminder_model.dart';

class MedicationReminderService {
  static final MedicationReminderService _instance = MedicationReminderService._();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  // A getter, so signing out can cancel alarms without Supabase being set up.
  SupabaseClient get _supabase => Supabase.instance.client;
  bool _initialized = false;

  /// Most alarms one reminder can have; notification ids leave room for
  /// this many per reminder.
  static const maxTimesPerReminder = 8;

  /// The notification id for alarm [slot] of reminder [reminderId].
  /// `String.hashCode` isn't promised to stay the same between app runs
  /// (so a reminder could never be cancelled) and Android ids must fit in
  /// 32 bits, so this hashes the id itself (FNV-1a).
  static int notificationId(String reminderId, int slot) {
    var h = 0x811c9dc5;
    for (final c in reminderId.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return (h & 0x0FFFFFFF) * maxTimesPerReminder + slot;
  }

  /// Whether [r] should ring at all: on, at set times, and not ended.
  /// "When needed" medicine has no alarm.
  static bool shouldRing(MedicationReminder r, DateTime now) {
    if (!r.isActive || r.frequency == 'as_needed' || r.times.isEmpty) return false;
    final end = r.endDate;
    if (end == null) return true;
    return !DateTime(end.year, end.month, end.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  /// What the notification says. For a dependant it names them, so a
  /// parent doesn't give their own medicine at their child's time.
  static (String, String) notificationText(MedicationReminder r, {String? personName}) {
    final title = personName == null ? 'Time for your medicine' : "Time for $personName's medicine";
    final dose = r.dosage.trim();
    return (title, dose.isEmpty ? r.medicationName : '${r.medicationName} · $dose');
  }

  bool get isInitialized => _initialized;

  /// Initialize notifications — safe to call on web (no-op).
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to init notifications: $e');
    }
  }

  /// Request notification permissions (Android 13+ and iOS).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Before Android 13 there is nothing to ask; whether notifications
        // are switched on for AfiCare is the answer.
        final granted = await android.requestNotificationsPermission();
        return granted ?? await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true, badge: true, sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
    return false;
  }

  /// Schedules a daily notification at each of [reminder]'s times.
  /// [personName] is the dependant's first name when it's their medicine.
  Future<void> scheduleReminder(MedicationReminder reminder, {String? personName}) async {
    if (kIsWeb || !_initialized) return;
    if (!shouldRing(reminder, DateTime.now())) return;

    final mode = await _scheduleMode();
    final (title, body) = notificationText(reminder, personName: personName);
    final slots = reminder.times.length.clamp(0, maxTimesPerReminder);
    for (var i = 0; i < slots; i++) {
      final time = reminder.times[i];
      try {
        final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
        final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

        await _plugin.zonedSchedule(
          notificationId(reminder.id, i),
          title,
          body,
          tzScheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medication_reminders',
              'Medication Reminders',
              channelDescription: 'Reminders to take your medication on time',
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
  }

  /// On time where the phone allows exact alarms; otherwise Android may
  /// ring a few minutes late, which is better than not at all.
  Future<AndroidScheduleMode> _scheduleMode() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.canScheduleExactNotifications() == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      debugPrint('Could not check exact alarms: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Cancels every alarm of a medication reminder.
  Future<void> cancelReminder(String reminderId) async {
    if (kIsWeb || !_initialized) return;
    try {
      for (var i = 0; i < maxTimesPerReminder; i++) {
        await _plugin.cancel(notificationId(reminderId, i));
      }
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  /// Cancels every medicine alarm on this phone, e.g. on sign-out, so the
  /// next person to use it doesn't get them.
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }

  /// Sets this phone's alarms to match the account's saved reminders: the
  /// account holder's and their dependants'. Run when the app opens, so
  /// alarms come back after a reinstall or on a new phone, and reminders
  /// made on the website ring here too. Nothing changes if loading fails.
  Future<void> syncForAccount(String ownId, List<DependentProfileModel> dependants) async {
    if (kIsWeb) return;
    await init();
    if (!_initialized) return;

    final List<MedicationReminder> reminders;
    try {
      final data = await _supabase
          .from('medication_reminders')
          .select()
          .inFilter('patient_id', [ownId, ...dependants.map((d) => d.id)]);
      reminders = (data as List).map((j) => MedicationReminder.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Could not load reminders to set alarms: $e');
      return;
    }

    final names = {for (final d in dependants) d.id: _firstName(d.fullName)};
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to clear alarms before setting them: $e');
      return;
    }
    for (final r in reminders) {
      await scheduleReminder(r, personName: r.patientId == ownId ? null : names[r.patientId]);
    }
  }

  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? fullName : parts.first;
  }

  DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── Supabase CRUD ──────────────────────────────────────────

  Future<List<MedicationReminder>> loadReminders(String patientId) async {
    try {
      return await fetchReminders(patientId);
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      return [];
    }
  }

  /// Like [loadReminders] but throws on failure, for screens that must
  /// tell "couldn't load" apart from "there are none".
  Future<List<MedicationReminder>> fetchReminders(String patientId) async {
    final data = await _supabase
        .from('medication_reminders')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => MedicationReminder.fromJson(j))
        .toList();
  }

  Future<MedicationReminder?> saveReminder({
    required String patientId,
    required String medicationName,
    required String dosage,
    required String frequency,
    required List<ReminderTime> times,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? prescriptionId,
    String? existingId,
    String? personName,
  }) async {
    try {
      final reminder = MedicationReminder(
        id: existingId ?? const Uuid().v4(),
        patientId: patientId,
        medicationName: medicationName,
        dosage: dosage,
        frequency: frequency,
        times: times,
        isActive: true,
        startDate: startDate ?? DateTime.now(),
        endDate: endDate,
        notes: notes,
        prescriptionId: prescriptionId,
        createdAt: DateTime.now(),
      );

      if (existingId != null) {
        await _supabase
            .from('medication_reminders')
            .update(reminder.toJson())
            .eq('id', existingId);
      } else {
        await _supabase.from('medication_reminders').insert(reminder.toJson());
      }

      // An edit may have changed the times: clear the old alarms first.
      if (existingId != null) await cancelReminder(existingId);
      await scheduleReminder(reminder, personName: personName);

      return reminder;
    } catch (e) {
      debugPrint('Error saving reminder: $e');
      return null;
    }
  }

  /// Returns whether the change was saved. Pass [reminder] when resuming
  /// so its notifications are scheduled again — pausing cancelled them,
  /// and without this a resumed reminder shows as on but never rings.
  Future<bool> toggleReminder(String reminderId, bool isActive,
      {MedicationReminder? reminder, String? personName}) async {
    try {
      await _supabase
          .from('medication_reminders')
          .update({'is_active': isActive})
          .eq('id', reminderId);

      if (!isActive) {
        await cancelReminder(reminderId);
      } else if (reminder != null) {
        await scheduleReminder(reminder.copyWith(isActive: true), personName: personName);
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling reminder: $e');
      return false;
    }
  }

  /// Returns whether the reminder was deleted.
  Future<bool> deleteReminder(String reminderId) async {
    try {
      await cancelReminder(reminderId);
      await _supabase
          .from('medication_reminders')
          .delete()
          .eq('id', reminderId);
      return true;
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      return false;
    }
  }
}
