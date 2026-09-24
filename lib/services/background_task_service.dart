import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:medinvoiceai/services/expiry_notification_service.dart';
import 'package:medinvoiceai/services/invoice_reminder_service.dart';
import 'package:medinvoiceai/services/local_notification_service.dart';
import 'package:workmanager/workmanager.dart';

const String kDailyExpiryCheckTask = 'daily-expiry-check-task';
const String kInvoiceReminderTask = 'invoice-reminder-task';

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    await Hive.initFlutter();
    await Hive.openBox('billsBox');
    await Hive.openBox('invoice_bills');
    await Hive.openBox('expiry_alert_state');
    await Hive.openBox('settings_box');

    await LocalNotificationService.initialize(requestPermission: false);

    if (task == kDailyExpiryCheckTask) {
      await ExpiryNotificationService.checkAndNotifyExpiringMedicines();
    } else if (task == kInvoiceReminderTask) {
      await InvoiceReminderService.checkAndNotifyInvoiceReminder();
    }

    return Future.value(true);
  });
}

class BackgroundTaskService {
  static Future<void> initializeAndScheduleDailyExpiryCheck() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await Workmanager().initialize(
      backgroundTaskDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      kDailyExpiryCheckTask,
      kDailyExpiryCheckTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      initialDelay: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.not_required),
    );

    await Workmanager().registerPeriodicTask(
      kInvoiceReminderTask,
      kInvoiceReminderTask,
      frequency: InvoiceReminderService.reminderInterval,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      initialDelay: InvoiceReminderService.reminderInterval,
      constraints: Constraints(networkType: NetworkType.not_required),
    );
  }
}
