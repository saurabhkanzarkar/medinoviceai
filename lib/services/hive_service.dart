import 'package:hive/hive.dart';

class HiveService {
  // Calculator bills box
  static Box get billsBox => Hive.box('billsBox');

  // Invoice bills box
  static Box get invoiceBillsBox => Hive.box('invoice_bills');

  // Expiry alert state box
  static Box get expiryAlertStateBox => Hive.box('expiry_alert_state');

  // User settings box
  static Box get settingsBox => Hive.box('settings_box');

  // Stock inventory box
  static Box get stockBox => Hive.box('stock_box');

  static const int defaultAlertWindowDays = 15;
  static const String _usernameKey = 'auth_username';
  static const String _passwordKey = 'auth_password';
  static const String _loggedInKey = 'auth_logged_in';

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static dynamic _findStockKeyByName(String medicineName) {
    final target = medicineName.trim().toLowerCase();
    for (final key in stockBox.keys) {
      final raw = stockBox.get(key);
      if (raw is Map) {
        final name = (raw['medicine_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (name == target) return key;
      }
    }
    return null;
  }

  // =========================
  // CALCULATOR BILLS
  // =========================

  static Future<void> saveBill(Map<String, dynamic> bill) async {
    await billsBox.add(bill);
  }

  static List<Map> getBills() {
    return billsBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // =========================
  // INVOICE BILLS
  // =========================

  static Future<void> saveInvoiceBill(Map<String, dynamic> bill) async {
    await invoiceBillsBox.add(bill);
  }

  static Future<List<Map>> getInvoiceBills() async {
    return invoiceBillsBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static bool isExpiryAlertSent(String alertKey) {
    return expiryAlertStateBox.get(alertKey, defaultValue: false) == true;
  }

  static Future<void> markExpiryAlertSent(String alertKey) async {
    await expiryAlertStateBox.put(alertKey, true);
  }

  static int getExpiryAlertWindowDays() {
    final value = settingsBox.get('expiry_alert_window_days');

    if (value is int && value > 0) return value;

    return defaultAlertWindowDays;
  }

  static Future<void> setExpiryAlertWindowDays(int days) async {
    await settingsBox.put('expiry_alert_window_days', days);
  }

  static bool get hasRegisteredUser {
    final username = settingsBox.get(_usernameKey);
    final password = settingsBox.get(_passwordKey);
    return username is String && username.isNotEmpty &&
        password is String && password.isNotEmpty;
  }

  static bool get isLoggedIn => settingsBox.get(_loggedInKey) == true;

  static Future<void> registerUser(String username, String password) async {
    await settingsBox.put(_usernameKey, username.trim());
    await settingsBox.put(_passwordKey, password);
    await settingsBox.put(_loggedInKey, true);
  }

  static Future<bool> loginUser(String username, String password) async {
    final isValid = username.trim() == settingsBox.get(_usernameKey) &&
        password == settingsBox.get(_passwordKey);

    if (isValid) {
      await settingsBox.put(_loggedInKey, true);
    }

    return isValid;
  }

  static Future<void> logoutUser() async {
    await settingsBox.put(_loggedInKey, false);
  }

  static Future<void> markInvoiceScannedNow() async {
    await settingsBox.put(
      'last_invoice_scanned_at',
      DateTime.now().toIso8601String(),
    );
  }

  static DateTime? getLastInvoiceScannedAt() {
    final value = settingsBox.get('last_invoice_scanned_at');
    if (value is! String || value.trim().isEmpty) return null;

    return DateTime.tryParse(value);
  }

  static bool hasScannedInvoiceToday() {
    final lastScanned = getLastInvoiceScannedAt();
    if (lastScanned == null) return false;

    final now = DateTime.now();
    return lastScanned.year == now.year &&
        lastScanned.month == now.month &&
        lastScanned.day == now.day;
  }

  // =========================
  // STOCK MANAGEMENT
  // =========================

  /// Get all medicines from stock
  static List<Map> getStockInventory() {
    return stockBox.toMap().entries.where((entry) => entry.value is Map).map((
      entry,
    ) {
      final item = Map<String, dynamic>.from(entry.value as Map);
      item['_stock_key'] = entry.key;
      return item;
    }).toList();
  }

  /// Get stock for a specific medicine
  static Map<String, dynamic>? getStockByName(String medicineName) {
    final key = _findStockKeyByName(medicineName);
    if (key == null) return null;

    final raw = stockBox.get(key);
    if (raw is! Map) return null;

    return Map<String, dynamic>.from(raw);
  }

  /// Add or update stock for a medicine
  static Future<void> saveOrUpdateStock(
    String medicineName,
    int quantity,
    int minStockLevel,
  ) async {
    final key = _findStockKeyByName(medicineName);

    if (key == null) {
      // Create new stock entry
      await stockBox.add({
        'medicine_name': medicineName,
        'quantity': quantity,
        'min_stock_level': minStockLevel,
        'created_date': DateTime.now().toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
      });
      return;
    }

    // Update existing stock
    final raw = stockBox.get(key);
    if (raw is! Map) return;

    final updatedStock = Map<String, dynamic>.from(raw);
    final currentQty = _toInt(updatedStock['quantity']);
    updatedStock['quantity'] = currentQty + quantity;
    updatedStock['min_stock_level'] = _toInt(updatedStock['min_stock_level']);
    updatedStock['last_updated'] = DateTime.now().toIso8601String();
    await stockBox.put(key, updatedStock);
  }

  /// Reduce stock when medicine is sold
  static Future<bool> reduceStock(String medicineName, int quantitySold) async {
    final key = _findStockKeyByName(medicineName);
    if (key == null) {
      return false; // Medicine not in stock
    }

    final raw = stockBox.get(key);
    if (raw is! Map) return false;

    final updatedStock = Map<String, dynamic>.from(raw);
    final currentQty = _toInt(updatedStock['quantity']);

    if (currentQty < quantitySold) {
      return false; // Not enough stock
    }

    updatedStock['quantity'] = currentQty - quantitySold;
    updatedStock['last_updated'] = DateTime.now().toIso8601String();
    updatedStock['total_sold'] =
        _toInt(updatedStock['total_sold']) + quantitySold;

    await stockBox.put(key, updatedStock);
    return true;
  }

  /// Reduce stock directly by Hive key
  static Future<bool> reduceStockByKey(
    dynamic stockKey,
    int quantitySold,
  ) async {
    final raw = stockBox.get(stockKey);
    if (raw is! Map) return false;

    final updatedStock = Map<String, dynamic>.from(raw);
    final currentQty = _toInt(updatedStock['quantity']);

    if (currentQty < quantitySold) {
      return false;
    }

    updatedStock['quantity'] = currentQty - quantitySold;
    updatedStock['last_updated'] = DateTime.now().toIso8601String();
    updatedStock['total_sold'] =
        _toInt(updatedStock['total_sold']) + quantitySold;

    await stockBox.put(stockKey, updatedStock);
    return true;
  }

  /// Get low stock medicines
  static List<Map<String, dynamic>> getLowStockMedicines() {
    final inventory = getStockInventory();
    return inventory
        .where(
          (stock) =>
              (stock['quantity'] ?? 0) <= (stock['min_stock_level'] ?? 10),
        )
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Set minimum stock level for a medicine
  static Future<void> setMinStockLevel(
    String medicineName,
    int minLevel,
  ) async {
    final key = _findStockKeyByName(medicineName);
    if (key == null) return;

    final raw = stockBox.get(key);
    if (raw is! Map) return;

    final updatedStock = Map<String, dynamic>.from(raw);
    updatedStock['min_stock_level'] = minLevel;
    updatedStock['last_updated'] = DateTime.now().toIso8601String();
    await stockBox.put(key, updatedStock);
  }

  /// Search medicines by prefix
  static List<Map<String, dynamic>> searchMedicinesByPrefix(String prefix) {
    final inventory = getStockInventory();
    if (prefix.isEmpty) return [];

    return inventory
        .where(
          (stock) => (stock['medicine_name'] ?? '').toLowerCase().startsWith(
            prefix.toLowerCase(),
          ),
        )
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Delete stock entry
  static Future<void> deleteStock(String medicineName) async {
    final key = _findStockKeyByName(medicineName);

    if (key != null) {
      await stockBox.delete(key);
    }
  }
}
