import 'package:flutter/material.dart';
import 'package:medinvoiceai/services/expiry_notification_service.dart';

import 'home_screen.dart';
import 'scanner_screen.dart';
import 'stock_management_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const HomeScreen(),
    const ScannerScreen(),
    const StockManagementScreen(),
  ];

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ExpiryNotificationService.checkAndNotifyExpiringMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,

        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: 'Calculator',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: 'Scanner',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
        ],
      ),
    );
  }
}
