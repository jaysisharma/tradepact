import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Top-level handler for FCM background messages (required by firebase_messaging).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op for now — the local notification is already visible via FCM.
}

class NotificationService {
  static const _channelIdDaily = 'tradepact_daily';
  static const _channelIdWeekly = 'tradepact_weekly';
  static const int _dailyNotifId = 100;
  static const int _weeklyNotifId = 101;

  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> initialize({
    required void Function(String route) onNotificationTap,
  }) async {
    // Set up timezone data.
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fall back to UTC silently.
    }

    // Android channel + icon.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifs.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload ?? '/trades';
        onNotificationTap(payload);
      },
    );

    // Register Android notification channels.
    final androidPlugin = _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelIdDaily,
      'Daily Reminders',
      description: 'Daily trade logging reminders at 8 PM',
      importance: Importance.high,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelIdWeekly,
      'Weekly Reports',
      description: 'Weekly trading insight notifications on Sunday',
      importance: Importance.defaultImportance,
    ));

    // Register FCM background handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle FCM messages when app is in the foreground.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifs.show(
          message.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelIdDaily,
              'Daily Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // Handle notification tap when app was terminated.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        onNotificationTap(message.data['route'] as String? ?? '/trades');
      }
    });

    // Handle notification tap when app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationTap(message.data['route'] as String? ?? '/trades');
    });
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<bool> requestPermission() async {
    // FCM permission (iOS / Android 13+).
    final fcmSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final fcmGranted =
        fcmSettings.authorizationStatus == AuthorizationStatus.authorized ||
            fcmSettings.authorizationStatus == AuthorizationStatus.provisional;

    // Local notifications permission (Android 13+).
    bool localGranted = true;
    if (!kIsWeb) {
      final androidPlugin = _localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final result = await androidPlugin?.requestNotificationsPermission();
      localGranted = result ?? true;
    }

    return fcmGranted && localGranted;
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  /// Schedules a daily reminder every day at 20:00 (8 PM) local time.
  Future<void> scheduleDailyReminder() async {
    await _localNotifs.zonedSchedule(
      _dailyNotifId,
      'TradePact',
      'Log your trades for today 📊',
      _nextDailyTime(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdDaily,
          'Daily Reminders',
          channelDescription: 'Daily trade logging reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/trades',
    );
  }

  /// Schedules a weekly insight reminder every Sunday at 10:00 AM local time.
  Future<void> scheduleWeeklyInsightReminder() async {
    await _localNotifs.zonedSchedule(
      _weeklyNotifId,
      'TradePact',
      'Your weekly trading report is ready 📈',
      _nextSundayTime(10, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdWeekly,
          'Weekly Reports',
          channelDescription: 'Weekly trading insight notifications',
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: '/insights',
    );
  }

  Future<void> cancelAll() async {
    await _localNotifs.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextSundayTime(int hour, int minute) {
    var candidate = _nextDailyTime(hour, minute);
    // Advance until we hit Sunday (weekday == 7).
    while (candidate.weekday != DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
