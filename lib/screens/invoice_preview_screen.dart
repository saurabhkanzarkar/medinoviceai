import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:medinvoiceai/services/expiry_notification_service.dart';
import 'package:medinvoiceai/services/hive_service.dart';
import 'package:medinvoiceai/services/invoice_reminder_service.dart';
import 'package:medinvoiceai/services/stock_service.dart';

import 'invoice_history_screen.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool saving = false;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3588199537991915/8225822020', // Test Banner ID
      request: const AdRequest(),
      size: AdSize.banner,

      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed: $error');
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.invoice['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Preview')),

      body: Column(
        children: [
          ListTile(
            title: Text(widget.invoice['invoiceName']?.toString() ?? 'Invoice'),
            subtitle: Text(widget.invoice['date']?.toString() ?? ''),
            trailing: Text('₹${widget.invoice['finalAmount'] ?? 0}'),
          ),

          const Divider(height: 1),

          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No medicines found'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return ListTile(
                        title: Text(item['medicine_name']?.toString() ?? ''),
                        subtitle: Text(
                          'Price: ${item['strip_price'] ?? 0}  '
                          'Qty: ${item['strip_quantity'] ?? 0}'
                          '${(item['expiry_date'] ?? '').toString().isNotEmpty ? '  Exp: ${item['expiry_date']}' : ''}',
                        ),
                      );
                    },
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setState(() => saving = true);

                            await HiveService.saveInvoiceBill(widget.invoice);
                            await HiveService.markInvoiceScannedNow();
                            await ExpiryNotificationService.checkAndNotifyExpiringMedicines(
                              invoices: [widget.invoice],
                            );
                            await InvoiceReminderService.checkAndNotifyInvoiceReminder();

                            // Add medicines to stock from invoice
                            final items = widget.invoice['items'] ?? [];
                            await StockService.addStockFromInvoice(items);

                            setState(() => saving = false);

                            if (!context.mounted) return;

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InvoiceHistoryScreen(),
                              ),
                              (route) => false,
                            );
                          },
                    child: Text(saving ? 'Saving...' : 'Save Invoice'),
                  ),
                ),

                const SizedBox(height: 10),

                if (_isBannerLoaded)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
