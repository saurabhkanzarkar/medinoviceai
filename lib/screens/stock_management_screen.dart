import 'package:flutter/material.dart';
import 'package:medinvoiceai/services/stock_service.dart';
import 'package:medinvoiceai/services/hive_service.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  late TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allMedicines = [];
  String _activeTab = 'all'; // 'all', 'low_stock', 'reorder'
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadMedicines();
  }

  void _loadMedicines() {
    setState(() {
      _allMedicines = StockService.getAllMedicinesSortedBySales();
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _searchResults = [];
      } else {
        _isSearching = true;
        _searchResults = StockService.searchMedicines(query);
      }
    });
  }

  Future<void> _showReduceStockDialog(Map<String, dynamic> medicine) async {
    final controller = TextEditingController();
    final medicineName = medicine['medicine_name'] ?? '';
    final currentQty = medicine['quantity'] ?? 0;
    final stockKey = medicine['_stock_key'];

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sell $medicineName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: $currentQty strips'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter quantity sold',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.shopping_cart),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text);
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid quantity')),
                );
                return;
              }

              if (qty > currentQty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Not enough stock. Available: $currentQty'),
                  ),
                );
                return;
              }

              final success = await StockService.sellMedicine(
                medicineName,
                qty,
                stockKey: stockKey,
              );

              if (mounted) {
                Navigator.pop(context);
                _loadMedicines();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Stock reduced by $qty'
                          : 'Error reducing stock',
                    ),
                  ),
                );
              }
            },
            child: const Text('Confirm Sale'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMinStockDialog(Map<String, dynamic> medicine) async {
    final controller = TextEditingController(
      text: (medicine['min_stock_level'] ?? 10).toString(),
    );
    final medicineName = medicine['medicine_name'] ?? '';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Min Stock Level - $medicineName'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Minimum quantity',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.warning),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final minLevel = int.tryParse(controller.text);
              if (minLevel == null || minLevel < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid number')),
                );
                return;
              }

              await StockService.updateMinStockLevel(medicineName, minLevel);

              if (mounted) {
                Navigator.pop(context);
                _loadMedicines();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Min stock level set to $minLevel')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine) {
    final name = medicine['medicine_name'] ?? 'Unknown';
    final qty = medicine['quantity'] ?? 0;
    final minLevel = medicine['min_stock_level'] ?? 10;
    final isLow = qty <= minLevel;
    final totalSold = medicine['total_sold'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isLow ? Colors.red.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$qty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isLow ? Colors.red : Colors.green,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            if (isLow)
              Chip(
                label: const Text(
                  'Low Stock',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              )
            else
              Chip(
                label: const Text(
                  'In Stock',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            const SizedBox(width: 8),
            Text(
              'Sold: $totalSold',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'sell') {
              _showReduceStockDialog(medicine);
            } else if (value == 'min') {
              _showMinStockDialog(medicine);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'sell',
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, size: 18),
                  SizedBox(width: 8),
                  Text('Sell'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'min',
              child: Row(
                children: [
                  Icon(Icons.warning, size: 18),
                  SizedBox(width: 8),
                  Text('Min Level'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'No medicines found' : 'No stock yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _isSearching
        ? _searchResults
        : (_activeTab == 'low_stock'
              ? HiveService.getLowStockMedicines()
              : (_activeTab == 'reorder'
                    ? StockService.getReorderList()
                    : _allMedicines));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with gradient background
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stock Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type "CR" for Crocin...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Tab selector
          if (!_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip('All Medicines', 'all'),
                      const SizedBox(width: 8),
                      _buildTabChip('Low Stock', 'low_stock'),
                      const SizedBox(width: 8),
                      _buildTabChip('Reorder List', 'reorder'),
                    ],
                  ),
                ),
              ),
            ),
          // Medicine list
          displayList.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMedicineCard(displayList[index]),
                    childCount: displayList.length,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value) {
    final isSelected = _activeTab == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.indigo,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _activeTab = value;
        });
      },
      backgroundColor: Colors.transparent,
      selectedColor: Colors.indigo,
      side: BorderSide(
        color: isSelected ? Colors.indigo : Colors.indigo.shade200,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
