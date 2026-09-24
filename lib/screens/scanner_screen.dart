import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medinvoiceai/services/openai_service.dart';

import 'invoice_preview_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final picker = ImagePicker();

  bool loading = false;
  String loadingMessage = '';

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();

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
          debugPrint('Ad failed: $error');
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

  Future<void> _processInvoiceFromCamera() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 72,
    );

    if (pickedFile == null) return;

    await _processPickedImages([pickedFile]);
  }

  Future<void> _processInvoicesFromGallery() async {
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 72,
    );

    if (pickedFiles.isEmpty) return;

    await _processPickedImages(pickedFiles);
  }

  Future<void> _processPickedImages(List<XFile> pickedFiles) async {
    final invoices = <Map<String, dynamic>>[];

    setState(() {
      loading = true;
      loadingMessage = 'Reading invoice with Google Vision...';
    });

    try {
      final openAI = OpenAIService();

      for (var i = 0; i < pickedFiles.length; i++) {
        if (!mounted) return;

        setState(() {
          loadingMessage = 'OCR ${i + 1} of ${pickedFiles.length} with Google Vision...';
        });

        setState(() {
          loadingMessage = 'Extracting text and matching invoice columns...';
        });

        final invoice = await openAI.parseInvoiceFromImage(
          File(pickedFiles[i].path),
        );
        invoices.add(invoice);

        if (i < pickedFiles.length - 1) {
          if (!mounted) return;

          setState(() {
            loadingMessage = 'Waiting 2 seconds before next image...';
          });

          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }

      if (!mounted) return;

      setState(() {
        loading = false;
        loadingMessage = '';
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InvoicePreviewScreen(invoice: _mergeInvoices(invoices)),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        loadingMessage = '';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Map<String, dynamic> _mergeInvoices(List<Map<String, dynamic>> invoices) {
    if (invoices.length == 1) return invoices.first;

    final items = <Map<String, dynamic>>[];
    double finalAmount = 0;

    for (final invoice in invoices) {
      finalAmount += double.tryParse(invoice['finalAmount'].toString()) ?? 0;
      items.addAll(
        (invoice['items'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
    }

    return {
      'invoiceName': 'Combined ${invoices.length} Invoices',
      'date': DateTime.now().toString().split('.')[0],
      'finalAmount': finalAmount,
      'items': items,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Scanner')),

      body: Center(
        child: loading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(loadingMessage),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: ElevatedButton.icon(
                        onPressed: _processInvoiceFromCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture From Camera'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: 260,
                      child: OutlinedButton.icon(
                        onPressed: _processInvoicesFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload From Gallery'),
                      ),
                    ),

                    const SizedBox(height: 30),

                    if (_isAdLoaded)
                      SizedBox(
                        width: 300,
                        height: 250,
                        child: AdWidget(ad: _bannerAd!),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
