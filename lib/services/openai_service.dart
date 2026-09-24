import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:medinvoiceai/services/google_vision_service.dart';

/// Invoice pipeline:
///
/// Image
///   ↓
/// Google Vision OCR
///   ↓
/// Gemini
///   ↓
/// Hive-compatible JSON
///
class OpenAIService {
  OpenAIService({
    GoogleVisionService? visionService,
    http.Client? client,
    String? geminiApiKey,
  })  : _visionService =
            visionService ?? GoogleVisionService(),
        _client = client ?? http.Client(),
        _geminiApiKey =
            geminiApiKey ?? 'AIzaSyCBvCR700n5rUc-4MJZGSbH0fzWOnzbM8Y';

  final GoogleVisionService _visionService;
  final http.Client _client;
  final String _geminiApiKey;

  static const String _model = 'gemini-2.5-flash';

  static const Duration _requestTimeout =
      Duration(seconds: 35);

  /// Small Gemini configuration.
  static const Map<String, dynamic> _jsonGenerationConfig = {
    'temperature': 0,
    'maxOutputTokens': 1024,
    'responseMimeType': 'application/json',
    'thinkingConfig': {
      'thinkingBudget': 0,
    },
  };

  /// Keep this prompt intentionally small.
  ///
  /// The field names must match the existing Hive structure.
  static const String _invoicePrompt = '''
Extract the pharmacy invoice into JSON.

Return ONLY this JSON structure:

{
  "invoiceName": "",
  "date": "",
  "finalAmount": 0,
  "items": [
    {
      "medicine_name": "",
      "strip_price": 0,
      "strip_quantity": 0,
      "expiry_date": ""
    }
  ]
}

The field names must match the Hive database exactly.

For each item:
- medicine_name = medicine/product name
- strip_price = price/rate for that medicine
- strip_quantity = Qty/Quantity for that medicine
- expiry_date = expiry date

Match values from the same invoice row.
Do not invent or calculate values.
Use 0 or "" when unavailable.

OCR:
''';

  /// Image -> Google Vision OCR -> Gemini.
  Future<Map<String, dynamic>> parseInvoiceFromImage(
    File imageFile,
  ) async {
    final totalStopwatch = Stopwatch()..start();

    print('Invoice processing started');

    // ---------------------------------------------------------
    // STEP 1: Google Vision
    // ---------------------------------------------------------
    final ocrText =
        await _visionService.extractTextFromImage(imageFile);

    if (ocrText.trim().isEmpty) {
      throw Exception(
        'Google Vision did not extract any text.',
      );
    }

    print(
      'OCR completed: ${ocrText.length} characters',
    );

    // ---------------------------------------------------------
    // STEP 2: Gemini
    // ---------------------------------------------------------
    final result = await parseInvoice(ocrText);

    totalStopwatch.stop();

    print(
      'Total invoice processing time: '
      '${totalStopwatch.elapsedMilliseconds} ms',
    );

    return result;
  }

  /// Sends OCR text to Gemini.
  ///
  /// Returns the exact fields expected by Hive.
  Future<Map<String, dynamic>> parseInvoice(
    String text,
  ) async {
    if (_geminiApiKey.trim().isEmpty ||
        _geminiApiKey == 'YOUR_NEW_GEMINI_API_KEY') {
      throw Exception(
        'Gemini API key is missing.',
      );
    }

    final cleanedOCRText = _cleanOCRText(text);

    if (cleanedOCRText.isEmpty) {
      throw Exception(
        'OCR text is empty.',
      );
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_model:generateContent?key=$_geminiApiKey';

    final promptWithOCR = '''
$_invoicePrompt

$cleanedOCRText
''';

    final stopwatch = Stopwatch()..start();

    print('Gemini request started');
    print(
      'Gemini input characters: ${promptWithOCR.length}',
    );

    final response = await _postGeminiWithRetry(
      url,
      {
        'generationConfig':
            _jsonGenerationConfig,
        'contents': [
          {
            'parts': [
              {
                'text': promptWithOCR,
              },
            ],
          },
        ],
      },
    );

    stopwatch.stop();

    print(
      'Gemini processing time: '
      '${stopwatch.elapsedMilliseconds} ms',
    );

    return _parseInvoiceResponse(response);
  }

  String _cleanOCRText(String text) {
    final normalized = text
        .replaceAll('\u0000', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    // Keep enough invoice data but avoid unnecessarily
    // large Gemini requests.
    const maxChars = 8000;

    if (normalized.length <= maxChars) {
      return normalized;
    }

    return normalized.substring(0, maxChars);
  }

  Future<http.Response> _postGeminiWithRetry(
    String url,
    Map<String, dynamic> payload,
  ) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .post(
              Uri.parse(url),
              headers: const {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 429 ||
            response.statusCode >= 500) {
          lastError =
              Exception(
            'Gemini HTTP ${response.statusCode}',
          );

          if (attempt == 0) {
            await Future<void>.delayed(
              const Duration(seconds: 1),
            );

            continue;
          }
        }

        return response;
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      }

      if (attempt == 0) {
        await Future<void>.delayed(
          const Duration(seconds: 1),
        );
      }
    }

    if (lastError is TimeoutException) {
      throw Exception(
        'Gemini request timed out.',
      );
    }

    if (lastError is SocketException) {
      throw Exception(
        'No internet connection available.',
      );
    }

    throw Exception(
      'Gemini could not process the invoice.',
    );
  }

  Map<String, dynamic> _parseInvoiceResponse(
    http.Response response,
  ) {
    if (response.statusCode != 200) {
      if (response.statusCode == 400) {
        throw Exception(
          'Gemini rejected the invoice request.',
        );
      }

      if (response.statusCode == 401 ||
          response.statusCode == 403) {
        throw Exception(
          'Gemini API access was denied. '
          'Check the Gemini API key.',
        );
      }

      if (response.statusCode == 429) {
        throw Exception(
          'Gemini quota is temporarily exhausted.',
        );
      }

      if (response.statusCode >= 500) {
        throw Exception(
          'Gemini server error. Please try again.',
        );
      }

      throw Exception(
        'Invoice processing failed '
        '(${response.statusCode}).',
      );
    }

    final dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Gemini returned invalid API response.',
      );
    }

    final content =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'];

    if (content == null ||
        content.toString().trim().isEmpty) {
      throw Exception(
        'Gemini returned no invoice data.',
      );
    }

    final cleaned = content
        .toString()
        .replaceFirst(
          RegExp(r'^```json\s*'),
          '',
        )
        .replaceFirst(
          RegExp(r'^```\s*'),
          '',
        )
        .replaceFirst(
          RegExp(r'\s*```$'),
          '',
        )
        .trim();

    dynamic decoded;

    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      throw Exception(
        'Gemini returned invalid invoice JSON.',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Gemini returned an invalid invoice structure.',
      );
    }

    return _normalizeForHive(
      Map<String, dynamic>.from(decoded),
    );
  }

  /// Only Hive-compatible fields leave this service.
  Map<String, dynamic> _normalizeForHive(
    Map<String, dynamic> raw,
  ) {
    final rawItems = raw['items'];

    final normalizedItems =
        <Map<String, dynamic>>[];

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }

        final item = <String, dynamic>{
          'medicine_name':
              _cleanString(
            rawItem['medicine_name'],
          ),
          'strip_price':
              _toDouble(
            rawItem['strip_price'],
          ),
          'strip_quantity':
              _toInt(
            rawItem['strip_quantity'],
          ),
          'expiry_date':
              _normalizeExpiry(
            rawItem['expiry_date'],
          ),
        };

        final hasUsefulData =
            item['medicine_name']
                    .toString()
                    .trim()
                    .isNotEmpty ||
                item['strip_price'] != 0 ||
                item['strip_quantity'] != 0 ||
                item['expiry_date']
                    .toString()
                    .trim()
                    .isNotEmpty;

        if (hasUsefulData) {
          normalizedItems.add(item);
        }
      }
    }

    return <String, dynamic>{
      'invoiceName':
          _cleanString(
        raw['invoiceName'],
      ),
      'date':
          _cleanString(
        raw['date'],
      ),
      'finalAmount':
          _toDouble(
        raw['finalAmount'],
      ),
      'items':
          normalizedItems,
    };
  }

  String _cleanString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    final cleaned = value
        .toString()
        .replaceAll(',', '')
        .replaceAll(
          RegExp(r'[^0-9.\-]'),
          '',
        );

    return double.tryParse(cleaned) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    final match =
        RegExp(r'-?\d+').firstMatch(
      value.toString(),
    );

    if (match == null) {
      return 0;
    }

    return int.tryParse(
          match.group(0) ?? '',
        ) ??
        0;
  }

  String _normalizeExpiry(dynamic value) {
    if (value == null) {
      return '';
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return '';
    }

    return raw
        .replaceFirst(
          RegExp(
            r'^(exp|expiry)[:\-\s]*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  void dispose() {
    _visionService.dispose();
    _client.close();
  }
}