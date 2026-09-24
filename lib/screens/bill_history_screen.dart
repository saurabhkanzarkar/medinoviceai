import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:medinvoiceai/screens/bill_details_screen.dart';

import '../services/hive_service.dart';

class BillHistoryScreen extends StatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  State<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends State<BillHistoryScreen> {
  InterstitialAd? _interstitialAd;

  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();

    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId:
          'ca-app-pub-3588199537991915/4324894016', // Test Interstitial ID

      request: const AdRequest(),

      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;

          _isInterstitialReady = true;

          debugPrint('Interstitial loaded');
        },

        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');

          _isInterstitialReady = false;
        },
      ),
    );
  }

  void _showInterstitialAd(Map bill) {
    if (_interstitialAd != null && _isInterstitialReady) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();

          _loadInterstitialAd();

          _navigateToDetail(bill);
        },

        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();

          _loadInterstitialAd();

          _navigateToDetail(bill);
        },
      );

      _interstitialAd!.show();

      _interstitialAd = null;
    } else {
      _navigateToDetail(bill);
    }
  }

  void _navigateToDetail(Map bill) {
    Navigator.push(
      context,

      MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill)),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bills = HiveService.getBills();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bill History')),

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
        child: bills.isEmpty
            ? Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No bills found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saved calculator bills will appear here.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  final patientName = (bill['patientName'] ?? 'Unknown Patient')
                      .toString();
                  final total = (bill['total'] ?? 0).toString();
                  final date = (bill['date'] ?? '').toString();
                  final items = (bill['items'] as List?)?.length ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showInterstitialAd(bill),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
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
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.12),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      patientName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹$total',
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
                                    Icons.medication_outlined,
                                    '$items medicines',
                                  ),
                                  if (date.isNotEmpty)
                                    _metaChip(
                                      theme,
                                      Icons.event_outlined,
                                      date,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _metaChip(ThemeData theme, IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
