import 'package:intl/intl.dart';
import 'package:medinvoiceai/services/hive_service.dart';
import 'package:medinvoiceai/services/local_notification_service.dart';

class ExpiryNotificationService {
  static const List<int> supportedAlertWindows = [7, 15, 30, 60];

  static int getAlertWindowDays() {
    final saved = HiveService.getExpiryAlertWindowDays();

    if (supportedAlertWindows.contains(saved)) {
      return saved;
    }

    return HiveService.defaultAlertWindowDays;
  }

  static Future<void> setAlertWindowDays(int days) async {
    if (!supportedAlertWindows.contains(days)) {
      return;
    }

    await HiveService.setExpiryAlertWindowDays(days);
  }

  static Future<void> checkAndNotifyExpiringMedicines({
    List<Map>? invoices,
  }) async {
    final sourceInvoices = invoices ?? await HiveService.getInvoiceBills();
    final alertWindowDays = getAlertWindowDays();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final nearAlertKeysToMark = <String>[];
    final expiredAlertKeysToMark = <String>[];
    final nearAlertLines = <String>[];
    final expiredAlertLines = <String>[];

    for (final invoice in sourceInvoices) {
      final invoiceName = (invoice['invoiceName'] ?? 'Invoice').toString();
      final items = (invoice['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      for (final item in items) {
        final medicineName = (item['medicine_name'] ?? '').toString().trim();
        final expiryText = (item['expiry_date'] ?? '').toString().trim();

        if (medicineName.isEmpty || expiryText.isEmpty) {
          continue;
        }

        final expiryDate = _parseExpiryDate(expiryText);
        if (expiryDate == null) {
          continue;
        }

        final diffDays = expiryDate.difference(todayDate).inDays;
        final normalizedDate = DateFormat('yyyy-MM-dd').format(expiryDate);

        if (diffDays < 0) {
          final expiredKey =
              'expired|${invoiceName.toLowerCase()}|${medicineName.toLowerCase()}|$normalizedDate';

          if (HiveService.isExpiryAlertSent(expiredKey)) {
            continue;
          }

          expiredAlertKeysToMark.add(expiredKey);
          expiredAlertLines.add(
            '$medicineName (${DateFormat('dd MMM yyyy').format(expiryDate)})',
          );
          continue;
        }

        if (diffDays > alertWindowDays) {
          continue;
        }

        final nearKey =
            'near|${invoiceName.toLowerCase()}|${medicineName.toLowerCase()}|$normalizedDate|$alertWindowDays';

        if (HiveService.isExpiryAlertSent(nearKey)) {
          continue;
        }

        nearAlertKeysToMark.add(nearKey);
        nearAlertLines.add(
          '$medicineName (${DateFormat('dd MMM yyyy').format(expiryDate)} - $diffDays days)',
        );
      }
    }

    if (expiredAlertLines.isNotEmpty) {
      if (expiredAlertLines.length == 1) {
        await LocalNotificationService.showExpiryAlert(
          title: 'Medicine Already Expired',
          body: '${expiredAlertLines.first} is already expired.',
        );
      } else {
        final preview = expiredAlertLines.take(2).join(', ');
        await LocalNotificationService.showExpiryAlert(
          title: 'Medicines Already Expired',
          body: '${expiredAlertLines.length} medicines are expired. $preview',
        );
      }
    }

    if (nearAlertLines.isNotEmpty) {
      if (nearAlertLines.length == 1) {
        await LocalNotificationService.showExpiryAlert(
          title: 'Medicine Expiry Alert',
          body: '${nearAlertLines.first} is near expiry.',
        );
      } else {
        final preview = nearAlertLines.take(2).join(', ');

        await LocalNotificationService.showExpiryAlert(
          title: 'Medicine Expiry Alert',
          body:
              '${nearAlertLines.length} medicines expire within $alertWindowDays days. $preview',
        );
      }
    }

    for (final key in expiredAlertKeysToMark) {
      await HiveService.markExpiryAlertSent(key);
    }

    for (final key in nearAlertKeysToMark) {
      await HiveService.markExpiryAlertSent(key);
    }
  }

  static Future<void> checkAndNotifySoonExpiringMedicines({
    List<Map>? invoices,
  }) async {
    await checkAndNotifyExpiringMedicines(invoices: invoices);
  }

  static DateTime? _parseExpiryDate(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final cleaned = raw
        .replaceAll(RegExp(r'exp|expiry|date|dt|:', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final directFormats = <DateFormat>[
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/yyyy'),
      DateFormat('MM-yyyy'),
      DateFormat('MM/yy'),
      DateFormat('MM-yy'),
      DateFormat('M/yyyy'),
      DateFormat('M/yy'),
    ];

    for (final format in directFormats) {
      try {
        final parsed = format.parseStrict(cleaned);
        return _normalizeExpiryDate(parsed, format.pattern ?? '');
      } catch (_) {}
    }

    final monthYear = RegExp(
      r'\b(0?[1-9]|1[0-2])[\/-](\d{2}|\d{4})\b',
    ).firstMatch(cleaned);

    if (monthYear != null) {
      final month = int.tryParse(monthYear.group(1) ?? '');
      final yearRaw = monthYear.group(2) ?? '';
      final year = _normalizeYear(yearRaw);

      if (month != null && year != null) {
        return _lastDayOfMonth(year, month);
      }
    }

    final yearMonth = RegExp(
      r'\b(\d{4})[\/-](0?[1-9]|1[0-2])\b',
    ).firstMatch(cleaned);

    if (yearMonth != null) {
      final year = int.tryParse(yearMonth.group(1) ?? '');
      final month = int.tryParse(yearMonth.group(2) ?? '');

      if (year != null && month != null) {
        return _lastDayOfMonth(year, month);
      }
    }

    return null;
  }

  static DateTime _normalizeExpiryDate(DateTime parsed, String pattern) {
    if (pattern.contains('MM/yy') ||
        pattern.contains('MM-yyyy') ||
        pattern.contains('MM/yyyy') ||
        pattern.contains('M/yy') ||
        pattern.contains('M/yyyy')) {
      return _lastDayOfMonth(parsed.year, parsed.month);
    }

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static int? _normalizeYear(String yearRaw) {
    final yearInt = int.tryParse(yearRaw);
    if (yearInt == null) return null;

    if (yearRaw.length == 2) {
      return 2000 + yearInt;
    }

    return yearInt;
  }

  static DateTime _lastDayOfMonth(int year, int month) {
    final firstNextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    return firstNextMonth.subtract(const Duration(days: 1));
  }
}
