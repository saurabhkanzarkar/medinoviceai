import 'package:flutter/material.dart';
import '../services/medicine_service.dart';

class MedicineSelector extends StatefulWidget {
  final List<String> medicinesDatabase;
  final Function(String) onMedicineSelected;
  final String? selectedMedicine;

  const MedicineSelector({
    Key? key,
    required this.medicinesDatabase,
    required this.onMedicineSelected,
    this.selectedMedicine,
  }) : super(key: key);

  @override
  State<MedicineSelector> createState() => _MedicineSelectorState();
}

class _MedicineSelectorState extends State<MedicineSelector> {
  late TextEditingController searchController;
  List<String> filteredMedicines = [];
  bool showDropdown = false;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredMedicines = widget.medicinesDatabase;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void filterMedicines(String query) {
    setState(() {
      if (query.isEmpty) {
        showDropdown = false;
      } else {
        filteredMedicines = widget.medicinesDatabase
            .where((med) => med.toLowerCase().contains(query.toLowerCase()))
            .toList()
            .take(15)
            .toList();
        showDropdown = filteredMedicines.isNotEmpty;
      }
    });
  }

  void selectMedicine(String name) {
    setState(() {
      searchController.text = name;
      showDropdown = false;
    });
    widget.onMedicineSelected(name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STEP 1: SELECT MEDICINE (2468 Available)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: filterMedicines,
            decoration: InputDecoration(
              hintText: 'Type medicine name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (showDropdown) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigo, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredMedicines.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(filteredMedicines[index]),
                    onTap: () => selectMedicine(filteredMedicines[index]),
                    trailing: const Icon(Icons.arrow_forward, size: 16),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
