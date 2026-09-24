class Medicine {
  final String name;
  final String type; // 'tablet', 'syrup', 'capsule', 'injection'
  final List<String> strengths; // Predefined strength list

  Medicine({
    required this.name,
    required this.type,
    required this.strengths,
  });
}

class CartItem {
  final String medicineName;
  final String medicineType; // tablet, syrup, capsule, etc.
  final String strength; // 500mg, 100mg/5ml, etc.
  final int tabletsPerStrip;
  final int costPerStrip;
  final int tabletsPerDay;

  CartItem({
    required this.medicineName,
    required this.medicineType,
    required this.strength,
    required this.tabletsPerStrip,
    required this.costPerStrip,
    required this.tabletsPerDay,
  });

  /// Total tablets needed (only tablets per day)
  int get tabletsNeeded => tabletsPerDay;

  /// Number of strips required
  int get stripsNeeded => (tabletsNeeded / tabletsPerStrip).ceil();

  /// Cost per tablet
  double get costPerTablet => costPerStrip / tabletsPerStrip;

  /// Total cost (cost per tablet × tablets needed)
  int get totalCost => (costPerTablet * tabletsNeeded).toInt();

  /// Create a copy with modifications
  CartItem copyWith({
    String? medicineName,
    String? medicineType,
    String? strength,
    int? tabletsPerStrip,
    int? costPerStrip,
    int? tabletsPerDay,
    int? daysSupply,
  }) {
    return CartItem(
      medicineName: medicineName ?? this.medicineName,
      medicineType: medicineType ?? this.medicineType,
      strength: strength ?? this.strength,
      tabletsPerStrip: tabletsPerStrip ?? this.tabletsPerStrip,
      costPerStrip: costPerStrip ?? this.costPerStrip,
      tabletsPerDay: tabletsPerDay ?? this.tabletsPerDay,
    );
  }

  @override
  String toString() {
    return 'CartItem(medicineName: $medicineName, medicineType: $medicineType, strength: $strength, tabletsNeeded: $tabletsNeeded, stripsNeeded: $stripsNeeded, totalCost: ₹$totalCost)';
  }
}
