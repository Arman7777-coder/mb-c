import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  final String baseUrl = AppConstants.apiBaseUrl;
  String? _deviceId;
  String? _adminPassword;

  void setDeviceId(String deviceId) => _deviceId = deviceId;
  void setAdminPassword(String password) => _adminPassword = password;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_deviceId != null) 'X-Device-ID': _deviceId!,
      };

  Map<String, String> get _adminHeaders => {
        ..._headers,
        if (_adminPassword != null) 'X-Admin-Password': _adminPassword!,
      };

  // Wall-clock cap so an unreachable / slow BE doesn't hang the UI
  // for the dart `http` package's default ~75 s on iOS / 30 s on
  // Android. Surfacing `TimeoutException` lets the UI show a real
  // error + Retry instead of a perpetual spinner.
  static const _httpTimeout = Duration(seconds: 12);

  // Validates the status before decoding. Calls that skip this can decode
  // an error body (e.g. a 422 {"detail":[...]} object) into the wrong type
  // and surface a confusing cast error far downstream in a provider.
  dynamic _decodeOrThrow(http.Response res, String op) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$op failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> register(String deviceId) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(_httpTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('register failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateConsent(bool consent, bool age) async {
    // Defensive — `_deviceId` must be set before consent. The BE rejects
    // the request without `X-Device-ID`; surface that as a clear error
    // rather than waiting for the round-trip rejection.
    if (_deviceId == null || _deviceId!.isEmpty) {
      throw StateError('Device not registered yet — call register() first.');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/auth/consent'),
          headers: _headers,
          body: jsonEncode({'consent_given': consent, 'age_confirmed': age}),
        )
        .timeout(_httpTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('consent failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getSurveys() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/surveys'), headers: _headers)
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'getSurveys') as List<dynamic>;
  }

  Future<Map<String, dynamic>> getSurveyDetail(String surveyId) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/surveys/$surveyId'), headers: _headers)
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'getSurveyDetail') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeSurvey(
    String surveyId,
    List<Map<String, dynamic>> answers,
    int startedAtMs,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/surveys/$surveyId/complete'),
      headers: _headers,
      body: jsonEncode({
        'answers': answers,
        'started_at_ms': startedAtMs,
      }),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Failed to complete survey');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getWallet() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/wallet'), headers: _headers)
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'getWallet') as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTransactions({int limit = 50, int offset = 0, String? type}) async {
    var url = '$baseUrl/api/wallet/transactions?limit=$limit&offset=$offset';
    if (type != null) url += '&type=$type';
    final res = await http.get(Uri.parse(url), headers: _headers).timeout(_httpTimeout);
    return _decodeOrThrow(res, 'getTransactions') as List<dynamic>;
  }

  Future<Map<String, dynamic>> requestRedemption(
    int amount,
    String method,
    Map<String, dynamic>? details,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/wallet/redeem'),
      headers: _headers,
      body: jsonEncode({
        'amount': amount,
        'payout_method': method,
        'payout_details': details,
      }),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Redemption failed');
    }
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getRedemptions() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/wallet/redemptions'), headers: _headers)
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'getRedemptions') as List<dynamic>;
  }

  Future<Map<String, dynamic>> applyAdReward(String completionId) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/ads/reward'),
          headers: _headers,
          body: jsonEncode({'completion_id': completionId}),
        )
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'applyAdReward') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> activatePremium(String plan) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/premium/activate'),
          headers: _headers,
          body: jsonEncode({'plan': plan}),
        )
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'activatePremium') as Map<String, dynamic>;
  }

  // Server-side receipt validation. The app forwards the store receipt;
  // the backend verifies it with Apple/Google (using the app-specific
  // shared secret / Play service account), grants premium, and returns
  // the updated user JSON (same shape as register). Anything other than
  // 200 means "not unlocked" — the caller must NOT complete the store
  // transaction so it stays pending for retry.
  Future<Map<String, dynamic>> verifyPremiumPurchase({
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    if (_deviceId == null || _deviceId!.isEmpty) {
      throw StateError('Device not registered yet — call register() first.');
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/premium/verify'),
          headers: _headers,
          body: jsonEncode({
            'platform': platform,
            'product_id': productId,
            'receipt': receipt,
          }),
        )
        .timeout(_httpTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('premium verify failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getPremiumStatus() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/premium/status'), headers: _headers)
        .timeout(_httpTimeout);
    return _decodeOrThrow(res, 'getPremiumStatus') as Map<String, dynamic>;
  }

  // Admin endpoints
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/dashboard'),
      headers: _adminHeaders,
    );
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getAdminUsers({String? query, bool flaggedOnly = false}) async {
    var url = '$baseUrl/api/admin/users?flagged_only=$flaggedOnly';
    if (query != null && query.isNotEmpty) url += '&q=$query';
    final res = await http.get(Uri.parse(url), headers: _adminHeaders);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getAdminSurveys() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/surveys'),
      headers: _adminHeaders,
    );
    return jsonDecode(res.body);
  }

  Future<void> toggleSurvey(String surveyId) async {
    await http.patch(
      Uri.parse('$baseUrl/api/admin/surveys/$surveyId'),
      headers: _adminHeaders,
    );
  }

  Future<List<dynamic>> getAdminRedemptions({String? status}) async {
    var url = '$baseUrl/api/admin/redemptions';
    if (status != null) url += '?status=$status';
    final res = await http.get(Uri.parse(url), headers: _adminHeaders);
    return jsonDecode(res.body);
  }

  Future<void> reviewRedemption(String id, String status, {String? notes, String? reason}) async {
    await http.patch(
      Uri.parse('$baseUrl/api/admin/redemptions/$id'),
      headers: _adminHeaders,
      body: jsonEncode({
        'status': status,
        'admin_notes': notes,
        'rejection_reason': reason,
      }),
    );
  }

  Future<List<dynamic>> getAdminFraud() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/fraud'),
      headers: _adminHeaders,
    );
    return jsonDecode(res.body);
  }
}
