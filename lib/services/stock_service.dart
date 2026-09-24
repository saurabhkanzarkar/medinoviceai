import 'package:medinvoiceai/services/hive_service.dart';
import 'package:medinvoiceai/services/local_notification_service.dart';

class StockService {
  // Default minimum stock level
  static const int defaultMinStockLevel = 10;

  /// Add medicines to stock from scanned invoice
  static Future<void> addStockFromInvoice(List<dynamic> items) async {
    for (final item in items) {
      if (item is Map) {
        final medicineName = item['medicine_name'] ?? '';
        final quantity = item['strip_quantity'] ?? 0;

        if (medicineName.isNotEmpty && quantity > 0) {
          await HiveService.saveOrUpdateStock(
            medicineName,
            quantity as int,
            defaultMinStockLevel,
          );
        }
      }
    }

    // Check for low stock and notify
    await checkAndNotifyLowStock();
  }

  /// Deduct stock when medicine is sold
  static Future<bool> sellMedicine(
    String medicineName,
    int quantity, {
    dynamic stockKey,
  }) async {
    final success = stockKey != null
        ? await HiveService.reduceStockByKey(stockKey, quantity)
        : await HiveService.reduceStock(medicineName, quantity);

    if (success) {
      // Check for low stock after sale
      await checkAndNotifyLowStock();
    }

    return success;
  }

  /// Check for low stock and send notifications
  static Future<void> checkAndNotifyLowStock() async {
    final lowStockMedicines = HiveService.getLowStockMedicines();

    if (lowStockMedicines.isNotEmpty) {
      final medicineNames = lowStockMedicines
          .map((m) => "${m['medicine_name']} (${m['quantity']} left)")
          .join(', ');

      // Show notification
      await LocalNotificationService.showExpiryAlert(
        title: lowStockMedicines.length == 1
            ? 'Low Stock Alert!'
            : 'Multiple Items Low in Stock!',
        body: 'Reorder needed: $medicineNames',
      );
    }
  }

  /// Search medicines by prefix with smart ranking
  /// Returns medicines ending with highest sales first
  static List<Map<String, dynamic>> searchMedicines(String prefix) {
    final results = HiveService.searchMedicinesByPrefix(prefix);

    // Sort by total_sold (descending) - highest selling medicines first
    results.sort((a, b) {
      final aSold = a['total_sold'] ?? 0;
      final bSold = b['total_sold'] ?? 0;
      return (bSold as int).compareTo(aSold as int);
    });

    return results;
  }

  /// Get stock status for a medicine
  static Map<String, dynamic>? getStockStatus(String medicineName) {
    final stock = HiveService.getStockByName(medicineName);

    if (stock == null) return null;

    final quantity = stock['quantity'] ?? 0;
    final minLevel = stock['min_stock_level'] ?? defaultMinStockLevel;
    final isLow = quantity <= minLevel;

    return {
      'medicine_name': stock['medicine_name'],
      'quantity': quantity,
      'min_stock_level': minLevel,
      'is_low': isLow,
      'status': isLow ? 'Low Stock' : 'In Stock',
      'total_sold': stock['total_sold'] ?? 0,
      'created_date': stock['created_date'],
      'last_updated': stock['last_updated'],
    };
  }

  /// Get all medicines sorted by sales (highest first)
  static List<Map<String, dynamic>> getAllMedicinesSortedBySales() {
    final inventory = HiveService.getStockInventory();

    inventory.sort((a, b) {
      final aSold = a['total_sold'] ?? 0;
      final bSold = b['total_sold'] ?? 0;
      return (bSold as int).compareTo(aSold as int);
    });

    return inventory.cast<Map<String, dynamic>>().toList();
  }

  /// Update minimum stock level for a medicine
  static Future<void> updateMinStockLevel(
    String medicineName,
    int minLevel,
  ) async {
    await HiveService.setMinStockLevel(medicineName, minLevel);
  }

  /// Get medicines that need reordering
  static List<Map<String, dynamic>> getReorderList() {
    return HiveService.getLowStockMedicines();
  }

  /// Check if medicine is available in sufficient quantity
  static bool checkAvailability(String medicineName, int requiredQuantity) {
    final stock = HiveService.getStockByName(medicineName);

    if (stock == null) return false;

    return (stock['quantity'] ?? 0) >= requiredQuantity;
  }
}
