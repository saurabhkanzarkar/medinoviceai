import 'package:flutter/material.dart';
import 'package:medinvoiceai/screens/bill_history_screen.dart';
import 'package:medinvoiceai/screens/invoice_history_screen.dart';
import 'package:medinvoiceai/services/expiry_notification_service.dart';
import 'package:medinvoiceai/services/hive_service.dart';
import 'package:medinvoiceai/services/stock_service.dart';
import 'package:medinvoiceai/screens/auth_screen.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../widgets/bill_table.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CartItem> cartItems = [];
  List<Medicine> allMedicines = [];
  List<Medicine> filteredMedicines = [];
  Medicine? selectedMedicine;
  String? selectedStrength;
  bool medicinesLoaded = false;

  final TextEditingController medicineController = TextEditingController();
  final TextEditingController tabletsPerStripController = TextEditingController(
    text: '10',
  );
  final TextEditingController costPerStripController = TextEditingController();
  final TextEditingController tabletsPerDayController = TextEditingController(
    text: '2',
  );

  bool showStrengthInput = false;
  FocusNode medicineFocusNode = FocusNode();
  int _alertWindowDays = HiveService.defaultAlertWindowDays;

  // Predefined strength options
  final List<String> tabletStrengths = [
    '100mg',
    '250mg',
    '500mg',
    '1000mg',
    '150mg',
    '200mg',
    '300mg',
    '400mg',
  ];

  final List<String> syrupStrengths = [
    '100mg/5ml',
    '125mg/5ml',
    '200mg/5ml',
    '250mg/5ml',
    '50mg/5ml',
  ];

  final List<String> capsuleStrengths = ['250mg', '500mg', '750mg', '1000mg'];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _loadAlertWindowSetting();
    medicineController.addListener(_filterMedicines);
  }

  Future<void> _loadAlertWindowSetting() async {
    final days = ExpiryNotificationService.getAlertWindowDays();

    if (!mounted) return;

    setState(() {
      _alertWindowDays = days;
    });
  }

  Future<void> _showAlertWindowDialog() async {
    int selectedDays = _alertWindowDays;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Expiry Alert Window'),
              content: DropdownButtonFormField<int>(
                initialValue: selectedDays,
                decoration: const InputDecoration(
                  labelText: 'Notify me before',
                ),
                items: ExpiryNotificationService.supportedAlertWindows
                    .map(
                      (days) => DropdownMenuItem<int>(
                        value: days,
                        child: Text('$days days'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedDays = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);

                    await ExpiryNotificationService.setAlertWindowDays(
                      selectedDays,
                    );

                    if (!mounted) return;

                    setState(() {
                      _alertWindowDays = selectedDays;
                    });

                    navigator.pop();

                    await ExpiryNotificationService.checkAndNotifyExpiringMedicines();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in with the same account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await HiveService.logoutUser();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _loadMedicines() async {
    final medicines = await MedicineService.loadMedicines();
    setState(() {
      allMedicines = medicines;
      medicinesLoaded = true;
    });
  }

  void _filterMedicines() {
    if (medicineController.text.isEmpty) {
      setState(() {
        filteredMedicines = [];
      });
      return;
    }

    final query = medicineController.text.toLowerCase();
    setState(() {
      filteredMedicines = allMedicines
          .where((med) => med.name.toLowerCase().contains(query))
          .toList()
          .take(10)
          .toList();
    });
  }

  @override
  void dispose() {
    medicineController.dispose();
    tabletsPerStripController.dispose();
    costPerStripController.dispose();
    tabletsPerDayController.dispose();
    medicineFocusNode.dispose();
    super.dispose();
  }

  void selectMedicine(Medicine medicine) {
    setState(() {
      selectedMedicine = medicine;
      medicineController.text = medicine.name;
      selectedStrength = null;
      showStrengthInput = true;
      filteredMedicines = [];
      costPerStripController.clear();
      medicineFocusNode.unfocus();
    });
  }

  List<String> getAvailableStrengths() {
    if (selectedMedicine == null) return [];

    if (selectedMedicine!.strengths.isNotEmpty) {
      return selectedMedicine!.strengths;
    }

    switch (selectedMedicine!.type.toLowerCase()) {
      case 'syrup':
        return syrupStrengths;
      case 'capsule':
        return capsuleStrengths;
      default:
        return tabletStrengths;
    }
  }

  int calculateTabletsNeeded() {
    try {
      int tabletsPerDay = int.parse(tabletsPerDayController.text);
      return tabletsPerDay;
    } catch (e) {
      return 0;
    }
  }

  int calculateStripsNeeded() {
    try {
      int tabletsNeeded = calculateTabletsNeeded();
      int tabletsPerStrip = int.parse(tabletsPerStripController.text);
      return (tabletsNeeded / tabletsPerStrip).ceil();
    } catch (e) {
      return 0;
    }
  }

  int calculateTotalCost() {
    try {
      if (tabletsPerStripController.text.isEmpty ||
          costPerStripController.text.isEmpty) {
        return 0;
      }
      int tabletsNeeded = calculateTabletsNeeded();
      int tabletsPerStrip = int.parse(tabletsPerStripController.text);
      int costPerStrip = int.parse(costPerStripController.text);

      double costPerTablet = costPerStrip / tabletsPerStrip;
      return (costPerTablet * tabletsNeeded).toInt();
    } catch (e) {
      return 0;
    }
  }

  void addMedicine() {
    if (selectedMedicine == null || selectedStrength == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select medicine and strength')),
      );
      return;
    }

    if (costPerStripController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cost per strip')),
      );
      return;
    }

    final cartItem = CartItem(
      medicineName: selectedMedicine!.name,
      medicineType: selectedMedicine!.type,
      strength: selectedStrength!,
      tabletsPerStrip: int.parse(tabletsPerStripController.text),
      costPerStrip: int.parse(costPerStripController.text),
      tabletsPerDay: int.parse(tabletsPerDayController.text),
    );

    setState(() {
      cartItems.add(cartItem);
      selectedMedicine = null;
      selectedStrength = null;
      showStrengthInput = false;
      medicineController.clear();
      tabletsPerStripController.text = '10';
      costPerStripController.clear();
      tabletsPerDayController.text = '2';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Added ${cartItem.medicineName} to bill')),
    );
  }

  int getSubtotal() {
    return cartItems.fold(0, (sum, item) => sum + item.totalCost);
  }

  int getGST() {
    return (getSubtotal() * 0.05).toInt();
  }

  int getTotal() {
    return getSubtotal() + getGST();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,

        title: const Column(
          children: [
            Text(
              'PharmaBill',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'Medicine Billing Calculator',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Expiry alerts: $_alertWindowDays days',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _showAlertWindowDialog,
          ),

          // CALCULATOR BILL HISTORY
          IconButton(
            tooltip: 'Calculator Bills',
            icon: const Icon(Icons.receipt_long),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillHistoryScreen()),
              );
            },
          ),

          // INVOICE HISTORY
          IconButton(
            tooltip: 'Scanned Invoices',
            icon: const Icon(Icons.document_scanner),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
              );
            },
          ),

          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: !medicinesLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STEP 1: MEDICINE SEARCH WITH AUTOCOMPLETE
                  Container(
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
                          'STEP 1: SEARCH MEDICINE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: medicineController,
                          focusNode: medicineFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Type medicine name...',
                            prefixIcon: const Icon(Icons.local_pharmacy),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon: medicineController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      medicineController.clear();
                                      setState(() {
                                        filteredMedicines = [];
                                        selectedMedicine = null;
                                        selectedStrength = null;
                                        showStrengthInput = false;
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                        // Autocomplete suggestions
                        if (filteredMedicines.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredMedicines.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: Colors.grey[300]),
                              itemBuilder: (_, index) {
                                final medicine = filteredMedicines[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.medication,
                                    color: Colors.indigo,
                                    size: 20,
                                  ),
                                  title: Text(medicine.name),
                                  subtitle: Text(
                                    medicine.type,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  onTap: () => selectMedicine(medicine),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // STEP 2: STRENGTH SELECTION (CHIPS)
                  if (showStrengthInput && selectedMedicine != null) ...[
                    Container(
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
                            'STEP 2: SELECT STRENGTH',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: getAvailableStrengths()
                                .map(
                                  (strength) => FilterChip(
                                    label: Text(strength),
                                    selected: selectedStrength == strength,
                                    onSelected: (isSelected) {
                                      setState(() {
                                        selectedStrength = isSelected
                                            ? strength
                                            : null;
                                      });
                                    },
                                    backgroundColor: Colors.white,
                                    selectedColor: Colors.indigo[100],
                                    side: BorderSide(
                                      color: selectedStrength == strength
                                          ? Colors.indigo
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // STEP 3: SELECTED MEDICINE DISPLAY
                    if (selectedStrength != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigo, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STEP 3: SELECTED MEDICINE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${selectedMedicine?.name} - ${selectedMedicine?.type} $selectedStrength',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // STEP 4: MEDICINE DETAILS
                    Container(
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
                            'STEP 4: MEDICINE DETAILS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: tabletsPerStripController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Tablets per strip',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: costPerStripController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Cost per strip (₹)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // STEP 5: DOSAGE
                    Container(
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
                            'STEP 5: DOSAGE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: tabletsPerDayController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Tablets per day',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // STEP 6: AUTO-CALCULATION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[50]!, Colors.indigo[50]!],
                        ),
                        border: Border.all(color: Colors.indigo, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'STEP 6: AUTO-CALCULATED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tablets needed:',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '${calculateTabletsNeeded()}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Strips to sell:',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '${calculateStripsNeeded()}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total cost:',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '₹${calculateTotalCost()}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ADD BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                        ),
                        onPressed: addMedicine,
                        child: const Text(
                          'Add to Bill',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // BILL TABLE
                  if (cartItems.isNotEmpty) ...[
                    BillTable(cartItems: cartItems),
                    const SizedBox(height: 16),
                  ],

                  // SUMMARY
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₹${getSubtotal()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'GST (5%)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₹${getGST()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.indigo, Colors.indigo[900]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'FINAL BILL AMOUNT',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${getTotal()}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                ),
                                onPressed: () {},
                                child: const Text(
                                  'Print',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                ),
                                onPressed: () async {
                                  final bill = {
                                    "patientName":
                                        "Patient ${DateTime.now().millisecondsSinceEpoch}",
                                    "date": DateTime.now().toString(),
                                    "subtotal": getSubtotal(),
                                    "gst": getGST(),
                                    "total": getTotal(),
                                    "items": cartItems.map((item) {
                                      return {
                                        "medicineName": item.medicineName,
                                        "strength": item.strength,
                                        "price": item.totalCost,
                                      };
                                    }).toList(),
                                  };

                                  await HiveService.saveBill(bill);

                                  // Reduce stock for each medicine sold
                                  for (final item in cartItems) {
                                    await StockService.sellMedicine(
                                      item.medicineName,
                                      item.stripsNeeded,
                                    );
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Bill Saved'),
                                      ),
                                    );
                                  }
                                },
                                child: const Text(
                                  'Checkout',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
