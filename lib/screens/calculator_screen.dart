import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class CalculatorScreen extends StatefulWidget {
  final List medicines;

  const CalculatorScreen({super.key, required this.medicines});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final qtyController = TextEditingController();

  double total = 0;

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3588199537991915/8225822020', // Test Banner Ad ID
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
          debugPrint('Banner failed to load: $error');
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    qtyController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void calculate(Map medicine) {
    final qty = int.tryParse(qtyController.text) ?? 0;

    final stripPrice = medicine['strip_price'].toDouble();

    final stripQty = medicine['strip_quantity'];

    setState(() {
      total = (stripPrice / stripQty) * qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Calculator')),

      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 70),
        itemCount: widget.medicines.length,
        itemBuilder: (context, index) {
          final medicine = widget.medicines[index];

          return Card(
            margin: const EdgeInsets.all(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine['medicine_name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text('Strip Price: ₹${medicine['strip_price']}'),

                  Text('Strip Quantity: ${medicine['strip_quantity']}'),

                  const SizedBox(height: 10),

                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Required Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: () => calculate(medicine),
                    child: const Text('Calculate'),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Final Amount: ₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      bottomNavigationBar: _isBannerLoaded
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }
}
