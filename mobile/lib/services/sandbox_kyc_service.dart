import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SandboxPanResult {
  final bool isValid;
  final String pan;
  final String? category;
  final String? status;
  final String? remarks;
  final bool nameMatched;
  final bool dobMatched;
  final String? aadhaarSeedingStatus;
  final String message;

  const SandboxPanResult({
    required this.isValid,
    required this.pan,
    this.category,
    this.status,
    this.remarks,
    this.nameMatched = false,
    this.dobMatched = false,
    this.aadhaarSeedingStatus,
    required this.message,
  });
}

class SandboxKycService {
  SandboxKycService._();
  static final SandboxKycService instance = SandboxKycService._();

  static const String _baseUrl = 'https://api.sandbox.co.in';
  static const String _apiKey = 'key_live_8fbc43bb9b0749268b5a7689de31a900';
  static const String _apiSecret = 'secret_live_248b826ed4df49eaab5fbe33e555f9ec';
  static const String _apiVersion = '1.0.0';

  String? _cachedToken;
  DateTime? _tokenExpiry;

  /// Retrieves a valid Sandbox JWT access token.
  Future<String?> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/authenticate'),
        headers: {
          'x-api-key': _apiKey,
          'x-api-secret': _apiSecret,
          'x-api-version': _apiVersion,
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final token = data?['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          // Tokens valid for 24 hours — cache for 23 hours safely
          _tokenExpiry = DateTime.now().add(const Duration(hours: 23));
          return _cachedToken;
        }
      }
      debugPrint('Sandbox auth error: status ${res.statusCode}, body: ${res.body}');
    } catch (e) {
      debugPrint('Sandbox auth exception: $e');
    }
    return null;
  }

  /// Verifies PAN Number against Sandbox Live KYC API.
  Future<SandboxPanResult> verifyPan({
    required String pan,
    required String nameAsPerPan,
    required String dateOfBirth, // format DD/MM/YYYY
  }) async {
    final cleanPan = pan.trim().toUpperCase();
    final cleanName = nameAsPerPan.trim();
    final cleanDob = dateOfBirth.trim();

    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(cleanPan)) {
      return SandboxPanResult(
        isValid: false,
        pan: cleanPan,
        message: 'Invalid PAN format. Must be 10 alphanumeric characters (e.g., ABCDE1234F).',
      );
    }

    final token = await _getAccessToken();
    if (token == null) {
      return SandboxPanResult(
        isValid: false,
        pan: cleanPan,
        message: 'Could not connect to verification server. Please retry in a moment.',
      );
    }

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/kyc/pan/verify'),
        headers: {
          'Authorization': token,
          'x-api-key': _apiKey,
          'x-api-version': _apiVersion,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          '@entity': 'in.co.sandbox.kyc.pan_verification.request',
          'pan': cleanPan,
          'name_as_per_pan': cleanName.isNotEmpty ? cleanName : 'Organiser Name',
          'date_of_birth': cleanDob.isNotEmpty ? cleanDob : '01/01/2000',
          'consent': 'Y',
          'reason': 'For onboarding event organizer on JHOOMO',
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['code'] == 200) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? '').toString();
        final isValid = status.toLowerCase() == 'valid';
        final category = data['category']?.toString();
        final remarks = data['remarks']?.toString();
        final nameMatch = data['name_as_per_pan_match'] == true;
        final dobMatch = data['date_of_birth_match'] == true;
        final aadhaarStatus = data['aadhaar_seeding_status']?.toString();

        return SandboxPanResult(
          isValid: isValid,
          pan: cleanPan,
          category: category,
          status: status,
          remarks: remarks,
          nameMatched: nameMatch,
          dobMatched: dobMatch,
          aadhaarSeedingStatus: aadhaarStatus,
          message: isValid
              ? 'PAN successfully verified with NSDL/Govt records!'
              : (remarks ?? 'PAN is invalid or inactive according to official records.'),
        );
      } else {
        final message = body['message']?.toString() ?? 'PAN verification failed (Code: ${body['code']}).';
        return SandboxPanResult(
          isValid: false,
          pan: cleanPan,
          message: message,
        );
      }
    } catch (e) {
      debugPrint('Sandbox PAN verification exception: $e');
      return SandboxPanResult(
        isValid: false,
        pan: cleanPan,
        message: 'Verification request failed: $e',
      );
    }
  }
}
