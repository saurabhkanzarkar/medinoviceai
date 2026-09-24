import 'package:flutter/material.dart';
import '../models/medicine.dart';

class BillTable extends StatelessWidget {
  final List<CartItem> cartItems;

  const BillTable({Key? key, required this.cartItems}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                      flex: 2, child: Text('Medicine', style: _headerStyle())),
                  Expanded(child: Text('Tablets', style: _headerStyle())),
                  Expanded(child: Text('Strips', style: _headerStyle())),
                  Expanded(child: Text('Price/Strip', style: _headerStyle())),
                ],
              ),
            ),
            // Rows
            ...cartItems.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == cartItems.length - 1;
              return Container(
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.medicineName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${item.medicineType} - ${item.strength}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Expanded(child: Text('${item.tabletsNeeded}')),
                    Expanded(child: Text('${item.stripsNeeded}')),
                    Expanded(child: Text('₹${item.costPerStrip}')),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() => const TextStyle(
      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey);
}
