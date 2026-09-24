import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _expiryChannel =
      AndroidNotificationChannel(
        'expiry_alerts',
        'Expiry Alerts',
        description: 'Alerts for medicines nearing expiry',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _reminderChannel =
      AndroidNotificationChannel(
        'invoice_reminders',
        'Invoice Reminders',
        description: 'Reminders to scan invoices on time',
        importance: Importance.high,
      );

  static bool _initialized = false;

  static Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.createNotificationChannel(_expiryChannel);
    await androidImpl?.createNotificationChannel(_reminderChannel);
    if (requestPermission) {
      await androidImpl?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static Future<void> showExpiryAlert({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _expiryChannel.id,
          _expiryChannel.name,
          channelDescription: _expiryChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
        ),
      );

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Local notification failed: $e');
    }
  }

  static Future<void> showInvoiceReminder({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.id,
          _reminderChannel.name,
          channelDescription: _reminderChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
        ),
      );

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Reminder notification failed: $e');
    }
  }
}
