import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Map invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  BannerAd? _bannerAd;

  bool _isAdLoaded = false;
  bool _isGeneratingPdf = false;

  num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;

    final parsed = num.tryParse(value.toString().replaceAll(',', '').trim());

    return parsed ?? 0;
  }

  num _lineAmount(Map item) {
    final price = _toNum(item['strip_price']);
    final quantity = _toNum(item['strip_quantity']);

    if (quantity <= 0) return price;

    return price * quantity;
  }

  String _expiryText(Map item) {
    final expiry = (item['expiry_date'] ?? '').toString().trim();

    return expiry;
  }

  num _invoiceTotal(List<dynamic> items) {
    final fromInvoice = _toNum(widget.invoice['finalAmount']);

    if (fromInvoice > 0) return fromInvoice;

    return items.fold<num>(0, (sum, item) {
      final safeItem = Map<String, dynamic>.from(item as Map);

      return sum + _lineAmount(safeItem);
    });
  }

  Future<void> _shareInvoicePdf(List<dynamic> items) async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdf = pw.Document();
      final dateText = widget.invoice['date']?.toString() ?? '';
      final invoiceName =
          widget.invoice['invoiceName']?.toString().trim().isNotEmpty == true
          ? widget.invoice['invoiceName'].toString().trim()
          : 'Invoice';
      final total = _invoiceTotal(items);

      pdf.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(
            margin: pw.EdgeInsets.all(24),
            pageFormat: PdfPageFormat.a4,
          ),
          build: (context) => [
            pw.Text(
              'Pharmacy Invoice',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Invoice: $invoiceName'),
            pw.Text(
              'Date: ${dateText.isNotEmpty ? dateText : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey700,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 4,
              ),
              headers: const [
                'Medicine',
                'Expiry',
                'Qty',
                'Unit Price',
                'Amount',
              ],
              data: items.map((rawItem) {
                final item = Map<String, dynamic>.from(rawItem as Map);
                final medicine =
                    item['medicine_name']?.toString().trim().isNotEmpty == true
                    ? item['medicine_name'].toString()
                    : '-';
                final expiry = _expiryText(item);
                final qty = _toNum(item['strip_quantity']);
                final unitPrice = _toNum(item['strip_price']);
                final amount = _lineAmount(item);

                return [
                  medicine,
                  expiry.isNotEmpty ? expiry : '-',
                  qty.toString(),
                  'Rs ${unitPrice.toStringAsFixed(2)}',
                  'Rs ${amount.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Total: Rs ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final safeName = invoiceName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            '${safeName}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to generate PDF: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3588199537991915/8225822020', // Test Ad ID

      request: const AdRequest(),

      size: AdSize.mediumRectangle, // Square Ad

      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          debugPrint('Ad failed to load: $error');
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
    final items = (widget.invoice['items'] as List? ?? []).toList();
    final total = _invoiceTotal(items);
    final theme = Theme.of(context);
    final invoiceName = (widget.invoice['invoiceName'] ?? 'Invoice Detail')
        .toString();
    final invoiceDate = (widget.invoice['date'] ?? 'No date').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(invoiceName),
        actions: [
          IconButton(
            onPressed: items.isEmpty || _isGeneratingPdf
                ? null
                : () => _shareInvoicePdf(items),
            tooltip: 'Share PDF',
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child: Icon(
                          Icons.receipt_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          invoiceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'Rs ${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metaChip(
                        theme,
                        Icons.inventory_2_outlined,
                        '${items.length} medicines',
                      ),
                      _metaChip(theme, Icons.event_outlined, invoiceDate),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 42,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No medicines found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = Map<String, dynamic>.from(
                          items[index] as Map,
                        );
                        final medicine = (item['medicine_name'] ?? '-')
                            .toString();
                        final qty = _toNum(item['strip_quantity']);
                        final price = _toNum(item['strip_price']);
                        final amount = _lineAmount(item);
                        final expiry = _expiryText(item);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _metaChip(
                                          theme,
                                          Icons.confirmation_number_outlined,
                                          'Qty ${qty.toString()}',
                                        ),
                                        _metaChip(
                                          theme,
                                          Icons.currency_rupee,
                                          'Unit ${price.toStringAsFixed(2)}',
                                        ),
                                        if (expiry.isNotEmpty)
                                          _metaChip(
                                            theme,
                                            Icons.schedule,
                                            'Exp $expiry',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rs ${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 6),
            if (_isAdLoaded)
              Center(
                child: SizedBox(
                  width: 300,
                  height: 250,
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(ThemeData theme, IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
