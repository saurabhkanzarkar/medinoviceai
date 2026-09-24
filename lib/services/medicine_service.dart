import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/medicine.dart';

class MedicineService {
  static Future<List<Medicine>> loadMedicines() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/medicines_list.json');
      final jsonData = jsonDecode(jsonString);
      final medicines = jsonData['medicines'] as List;

      // Map your JSON to Medicine model
      return medicines.map((med) {
        return Medicine(
          name: med['medicine_name'] as String,
          type: _getMedicineType(med['medicine_name'] as String),
          strengths: _getStrengthsForMedicine(med['medicine_name'] as String),
        );
      }).toList();
    } catch (e) {
      print('Error loading medicines: $e');
      return [];
    }
  }

  // Determine medicine type based on name patterns
  static String _getMedicineType(String medicineName) {
    final name = medicineName.toLowerCase();

    // Check for syrup/liquid indicators
    if (name.contains('syrup') ||
        name.contains('liquid') ||
        name.contains('solution') ||
        name.contains('suspension')) {
      return 'syrup';
    }

    // Check for injection indicators
    if (name.contains('injection') ||
        name.contains('injectable') ||
        name.contains('intravenous')) {
      return 'injection';
    }

    // Check for capsule indicators
    if (name.contains('capsule')) {
      return 'capsule';
    }

    // Default to tablet
    return 'tablet';
  }

  // Get common strengths based on medicine type
  static List<String> _getStrengthsForMedicine(String medicineName) {
    final name = medicineName.toLowerCase();

    // Return strengths based on medicine type
    if (name.contains('syrup') || name.contains('liquid')) {
      return ['50mg/5ml', '100mg/5ml', '125mg/5ml', '200mg/5ml', '250mg/5ml'];
    } else if (name.contains('capsule')) {
      return ['250mg', '500mg', '750mg', '1000mg'];
    } else if (name.contains('injection')) {
      return ['50mg', '100mg', '250mg', '500mg', '1000mg'];
    } else {
      // Default tablet strengths
      return ['50mg', '100mg', '250mg', '500mg', '1000mg'];
    }
  }

  // Search medicines by name
  static Future<List<Medicine>> searchMedicines(
      String query, List<Medicine> allMedicines) async {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return allMedicines
        .where((med) => med.name.toLowerCase().contains(lowerQuery))
        .toList()
        .take(20)
        .toList();
  }

  // Get medicines by type
  static Future<List<Medicine>> getMedicinesByType(
      String type, List<Medicine> allMedicines) async {
    return allMedicines
        .where((medicine) => medicine.type.toLowerCase() == type.toLowerCase())
        .toList();
  }
}
