import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/medication_reminder_model.dart';

class MedicationReminderService {
  static final MedicationReminderService _instance = MedicationReminderService._();
  factory MedicationReminderService() => _instance;
  MedicationReminderService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _initialized = false;

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
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
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

  /// Schedule a daily or timed notification for a medication.
  Future<void> scheduleReminder(MedicationReminder reminder) async {
    if (kIsWeb || !_initialized) return;

    for (var i = 0; i < reminder.times.length; i++) {
      final time = reminder.times[i];
      try {
        final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
        final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

        await _plugin.zonedSchedule(
          reminder.id.hashCode + i,
          'Medication Reminder',
          'Time to take ${reminder.medicationName} (${reminder.dosage})',
          tzScheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medication_reminders',
              'Medication Reminders',
              channelDescription: 'Reminders to take your medication on time',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
  }

  /// Cancel all notifications for a medication reminder.
  ///
  /// A reminder schedules one notification per time slot, each using the id
  /// `reminderId.hashCode + i`. This cancels every slot, not just the first.
  Future<void> cancelReminder(String reminderId, {int? slotCount}) async {
    if (kIsWeb || !_initialized) return;

    var count = slotCount;
    if (count == null) {
      try {
        final data = await _supabase
            .from('medication_reminders')
            .select('times')
            .eq('id', reminderId)
            .maybeSingle();
        final times = data != null ? (data['times'] as List?) : null;
        count = times?.length;
      } catch (e) {
        debugPrint('Failed to load reminder for cancel: $e');
      }
    }
    if (count == null || count < 1) count = 1;

    try {
      for (var i = 0; i < count; i++) {
        await _plugin.cancel(reminderId.hashCode + i);
      }
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  /// Cancel all medication notifications.
  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
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
      final data = await _supabase
          .from('medication_reminders')
          .select()
          .eq('patient_id', patientId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((j) => MedicationReminder.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      return [];
    }
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

      // Schedule local notifications
      if (reminder.isActive) {
        await scheduleReminder(reminder);
      }

      return reminder;
    } catch (e) {
      debugPrint('Error saving reminder: $e');
      return null;
    }
  }

  Future<void> toggleReminder(String reminderId, bool isActive) async {
    try {
      await _supabase
          .from('medication_reminders')
          .update({'is_active': isActive})
          .eq('id', reminderId);

      if (!isActive) {
        await cancelReminder(reminderId);
      }
    } catch (e) {
      debugPrint('Error toggling reminder: $e');
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    try {
      await cancelReminder(reminderId);
      await _supabase
          .from('medication_reminders')
          .delete()
          .eq('id', reminderId);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }
}
