import 'dart:io';

import 'package:medinvoiceai/services/google_vision_service.dart';

/// Backward-compatible OCR facade.
/// OCR is now performed by Google Cloud Vision instead of on-device ML Kit.
class OCRService {
  OCRService({GoogleVisionService? visionService})
      : _visionService = visionService ?? GoogleVisionService();

  final GoogleVisionService _visionService;

  Future<String> extractText(String imagePath) {
    return _visionService.extractTextFromImage(File(imagePath));
  }

  void dispose() => _visionService.dispose();
}
