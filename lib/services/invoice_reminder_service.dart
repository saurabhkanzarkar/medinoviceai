import 'package:intl/intl.dart';
import 'package:medinvoiceai/services/hive_service.dart';
import 'package:medinvoiceai/services/local_notification_service.dart';

class InvoiceReminderService {
  static const Duration reminderInterval = Duration(hours: 4);

  static Future<void> checkAndNotifyInvoiceReminder() async {
    if (HiveService.hasScannedInvoiceToday()) {
      return;
    }

    final lastScanned = HiveService.getLastInvoiceScannedAt();
    final lastScannedText = lastScanned == null
        ? 'You have not scanned any invoice today.'
        : 'Last scan: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastScanned.toLocal())}.';

    await LocalNotificationService.showInvoiceReminder(
      title: 'Stay ahead of medicine expiry',
      body:
          'No invoice scanned today. Scan now to keep your medicine expiry alerts up to date. $lastScannedText',
    );
  }
}
