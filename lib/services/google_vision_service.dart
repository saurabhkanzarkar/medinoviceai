import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Extracts invoice text using Google Cloud Vision REST API.
class GoogleVisionService {
  GoogleVisionService({
    String? apiKey,
    http.Client? client,
  })  : _apiKey = apiKey ?? 'AIzaSyDTzZDNEWu6VNt_ERmccG0xgkOEoh2u6R8',
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 30);

  // Correct Google Cloud Vision REST endpoint.
  static const String _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  Future<String> extractTextFromImage(File imageFile) async {
    // Validate API key.
    if (_apiKey.trim().isEmpty ||
        _apiKey == 'YOUR_NEW_GOOGLE_VISION_API_KEY') {
      throw Exception(
        'Google Vision API key is missing.',
      );
    }

    final stopwatch = Stopwatch()..start();

    // Read image.
    final bytes = await imageFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception(
        'The selected image is empty.',
      );
    }

    print('Google Vision image bytes: ${bytes.length}');

    print(
      'Google Vision image size: '
      '${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    // Convert image to Base64.
    final base64Image = base64Encode(bytes);

    // Google Vision request.
    final payload = {
      'requests': [
        {
          'image': {
            'content': base64Image,
          },
          'features': [
            {
              'type': 'DOCUMENT_TEXT_DETECTION',
            },
          ],
        },
      ],
    };

    http.Response response;

    try {
      response = await _client
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'Google Vision OCR timed out.',
      );
    } on SocketException {
      throw Exception(
        'No internet connection available.',
      );
    } catch (e) {
      throw Exception(
        'Google Vision request failed: $e',
      );
    }

    stopwatch.stop();

    print(
      'Google Vision OCR request time: '
      '${stopwatch.elapsedMilliseconds} ms',
    );

    print(
      'Google Vision HTTP status: '
      '${response.statusCode}',
    );

    // Handle Google Vision errors.
    if (response.statusCode != 200) {
      print(
        'Google Vision error response:',
      );

      print(response.body);

      if (response.statusCode == 400) {
        throw Exception(
          'Google Vision rejected the request (400): '
          '${response.body}',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          'Google Vision access denied (403). '
          'Check the API key, Cloud Vision API, '
          'and API restrictions.\n'
          'Response: ${response.body}',
        );
      }

      if (response.statusCode == 429) {
        throw Exception(
          'Google Vision quota is temporarily exhausted (429).\n'
          'Response: ${response.body}',
        );
      }

      if (response.statusCode >= 500) {
        throw Exception(
          'Google Vision server error '
          '(${response.statusCode}).\n'
          'Response: ${response.body}',
        );
      }

      throw Exception(
        'Google Vision failed '
        '(${response.statusCode}).\n'
        'Response: ${response.body}',
      );
    }

    // Parse JSON response.
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw Exception(
        'Google Vision returned invalid JSON: $e',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Google Vision returned an invalid response structure.',
      );
    }

    final responses = decoded['responses'];

    if (responses is! List || responses.isEmpty) {
      throw Exception(
        'Google Vision returned no OCR result.',
      );
    }

    final first = responses.first;

    if (first is! Map) {
      throw Exception(
        'Google Vision returned an invalid OCR response.',
      );
    }

    // Check for an OCR-level error.
    if (first['error'] != null) {
      final error = first['error'];

      final message = error is Map
          ? error['message']?.toString()
          : null;

      throw Exception(
        message == null || message.isEmpty
            ? 'Google Vision returned an OCR error.'
            : 'Google Vision OCR error: $message',
      );
    }

    // Extract full OCR text.
    final fullTextAnnotation =
        first['fullTextAnnotation'];

    final text = fullTextAnnotation is Map
        ? fullTextAnnotation['text']?.toString().trim() ?? ''
        : '';

    if (text.isEmpty) {
      throw Exception(
        'No readable text was found in the invoice image.',
      );
    }

    print(
      'Google Vision OCR characters: '
      '${text.length}',
    );

    print(
      'Google Vision OCR text:\n$text',
    );

    return text;
  }

  void dispose() {
    _client.close();
  }
}