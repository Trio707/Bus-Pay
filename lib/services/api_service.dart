import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../auth/account_store.dart';
import '../core/constants/app_config.dart';

/// Stable id for one financial attempt. Retries must reuse it.
String newIdempotencyKey() {
  final random = Random.secure();
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'bp${List.generate(24, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
}

String _capitalName(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  static const _discoverTimeout = Duration(milliseconds: 900);
  static const _requestTimeout = Duration(milliseconds: 4500);
  static final _client = http.Client();
  static String _baseUrl = AppConfig.apiHosts.first;
  static bool _ready = false;

  static Future<void> warmup() async {
    try {
      await _discover();
    } catch (_) {}
  }

  static Future<bool> _probe(String host) async {
    try {
      final response = await _client
          .get(Uri.parse('$host/health'))
          .timeout(_discoverTimeout);
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _discover({bool force = false}) async {
    if (_ready && !force) return;
    _ready = false;
    if (!force) {
      final saved = await AccountStore.readApiHost();
      if (saved != null && saved.isNotEmpty && await _probe(saved)) {
        _baseUrl = saved;
        _ready = true;
        return;
      }
    }
    final hits = await Future.wait(
      AppConfig.apiHosts.map((host) async {
        if (await _probe(host)) return host;
        return null;
      }),
    );
    for (final host in AppConfig.apiHosts) {
      if (hits.contains(host)) {
        _baseUrl = host;
        _ready = true;
        await AccountStore.saveApiHost(host);
        return;
      }
    }
    throw ApiException('Server did not respond');
  }

  static Future<Map<String, dynamic>> login({
    required String pin,
    String? username,
    String? phone,
  }) {
    final body = <String, dynamic>{'pin': pin};
    final u = username?.trim() ?? '';
    final p = phone?.trim() ?? '';
    if (u.isNotEmpty) body['username'] = u;
    if (p.isNotEmpty) body['phone'] = p;
    return _post('/auth/login', body);
  }

  static Future<Map<String, dynamic>> agentLogin({
    required String email,
    required String password,
  }) {
    return _post('/auth/agent/login', {
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> forgotAgentPassword({
    required String email,
  }) {
    return _post('/auth/agent/forgot-password', {
      'email': email,
    });
  }

  static Future<Map<String, dynamic>> resetAgentPassword({
    required String email,
    required String code,
    required String password,
    required String confirmPassword,
  }) {
    return _post('/auth/agent/reset-password', {
      'email': email,
      'code': code,
      'password': password,
      'confirmPassword': confirmPassword,
    });
  }

  static Future<Map<String, dynamic>> checkAvailability({
    String? phone,
    String? nida,
  }) {
    final q = <String, String>{};
    if (phone != null && phone.trim().isNotEmpty) q['phone'] = phone.trim();
    if (nida != null && nida.trim().isNotEmpty) q['nida'] = nida.trim();
    final query = q.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _get('/auth/check?$query');
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String nida,
    required String pin,
    required String confirmPin,
  }) {
    return _post('/auth/register/conductor', {
      'firstName': _capitalName(firstName),
      'lastName': _capitalName(lastName),
      'phone': phone.trim(),
      'nida': nida.trim(),
      'pin': pin,
      'confirmPin': confirmPin,
    });
  }

  static Future<Map<String, dynamic>> changePin({
    required String token,
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) {
    return _post(
      '/auth/change-pin',
      {
        'currentPin': currentPin,
        'newPin': newPin,
        'confirmPin': confirmPin,
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> changeAgentPassword({
    required String token,
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) {
    return _post(
      '/auth/agent/change-password',
      {
        'currentPassword': currentPassword,
        'password': password,
        'confirmPassword': confirmPassword,
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> forgotPin({
    required String phone,
    required String nida,
  }) {
    return _post('/auth/forgot-pin', {
      'phone': phone.trim(),
      'nida': nida.trim(),
    });
  }

  static Future<Map<String, dynamic>> resetPin({
    required String phone,
    required String nida,
    required String code,
    required String pin,
    required String confirmPin,
  }) {
    return _post('/auth/reset-pin', {
      'phone': phone.trim(),
      'nida': nida.trim(),
      'code': code.trim(),
      'pin': pin,
      'confirmPin': confirmPin,
    });
  }

  static Future<Map<String, dynamic>> scanCard({
    required String token,
    required String nfcUid,
  }) {
    return _post(
      '/platform/cards/scan',
      {'nfcUid': nfcUid.trim()},
      token: token,
    );
  }

  static Future<Map<String, dynamic>> activateCard({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    required String cardNumber,
    required String nfcUid,
    String? nida,
  }) {
    return _post(
      '/platform/cards/activate',
      {
        'firstName': _capitalName(firstName),
        'lastName': _capitalName(lastName),
        'phone': phone.trim(),
        'cardNumber': cardNumber.trim(),
        'nfcUid': nfcUid.trim(),
        if (nida != null && nida.trim().isNotEmpty) 'nida': nida.trim(),
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> issueCard({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    String? nida,
    String? serialNumber,
    String? nfcUid,
    int initialLoad = 0,
  }) {
    return _post(
      '/platform/cards',
      {
        'firstName': _capitalName(firstName),
        'lastName': _capitalName(lastName),
        'phone': phone.trim(),
        if (nida != null && nida.trim().isNotEmpty) 'nida': nida.trim(),
        if (serialNumber != null && serialNumber.trim().isNotEmpty)
          'serialNumber': serialNumber.trim(),
        if (serialNumber != null && serialNumber.trim().isNotEmpty)
          'cardNumber': serialNumber.trim(),
        if (nfcUid != null && nfcUid.trim().isNotEmpty) 'nfcUid': nfcUid.trim(),
        'initialLoad': initialLoad,
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> previewTopUpScan({
    required String token,
    required String nfcUid,
  }) {
    return _post(
      '/platform/wallets/topup/scan',
      {'nfcUid': nfcUid.trim()},
      token: token,
    );
  }

  static Future<Map<String, dynamic>> getTransactions({
    required String token,
    int limit = 20,
    String? cursor,
    String? since,
    bool summary = false,
  }) {
    final query = <String, String>{
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (since != null && since.isNotEmpty) 'since': since,
      if (summary) 'summary': '1',
    };
    final path = query.entries
        .map((entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    return _get('/platform/transactions?$path', token: token);
  }

  static Future<Map<String, dynamic>> getAgentFloat({
    required String token,
  }) {
    return _get('/platform/float', token: token);
  }

  static Future<Map<String, dynamic>> getAgentFloatTransactions({
    required String token,
    int page = 1,
    int limit = 20,
  }) {
    return _get(
      '/platform/float/transactions?page=$page&limit=$limit',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> tapPay({
    required String token,
    required int amount,
    required String idempotencyKey,
    String? serialNumber,
    String? nfcUid,
    String serviceType = 'TRANSPORT',
    String merchantCode = 'DLD-PLATFORM',
  }) {
    return _post(
      '/platform/payments/tap',
      {
        'amount': amount,
        'serviceType': serviceType,
        'merchantCode': merchantCode,
        'idempotencyKey': idempotencyKey,
        if (serialNumber != null && serialNumber.trim().isNotEmpty)
          'serialNumber': serialNumber.trim(),
        if (nfcUid != null && nfcUid.trim().isNotEmpty) 'nfcUid': nfcUid.trim(),
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> lookupCard({
    required String token,
    String? serialNumber,
    String? nfcUid,
  }) {
    if (nfcUid != null && nfcUid.trim().isNotEmpty) {
      return _get(
        '/platform/cards/uid/${Uri.encodeComponent(nfcUid.trim())}',
        token: token,
      );
    }
    if (serialNumber == null || serialNumber.trim().isEmpty) {
      throw ApiException('serialNumber or nfcUid is required');
    }
    return _get(
      '/platform/cards/${Uri.encodeComponent(serialNumber.trim())}',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> renewCard({
    required String token,
    required String serialNumber,
    String? nfcUid,
    String? firstName,
    String? lastName,
    String? phone,
    int amount = 0,
    String? idempotencyKey,
  }) {
    return _post(
      '/platform/cards/${Uri.encodeComponent(serialNumber.trim())}/renew',
      {
        if (nfcUid != null && nfcUid.trim().isNotEmpty) 'nfcUid': nfcUid.trim(),
        if (firstName != null && firstName.trim().isNotEmpty)
          'firstName': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'lastName': lastName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'amount': amount,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'idempotencyKey': idempotencyKey,
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> freezeCard({
    required String token,
    required String serialNumber,
  }) {
    return _post(
      '/platform/cards/${Uri.encodeComponent(serialNumber.trim())}/freeze',
      const {},
      token: token,
    );
  }

  static Future<Map<String, dynamic>> topUpWallet({
    required String token,
    required int amount,
    String? serialNumber,
    String? nfcUid,
    String? phone,
    String? walletAccountNumber,
    String? idempotencyKey,
  }) {
    return _post(
      '/platform/wallets/topup',
      {
        'amount': amount,
        if (serialNumber != null && serialNumber.trim().isNotEmpty)
          'serialNumber': serialNumber.trim(),
        if (nfcUid != null && nfcUid.trim().isNotEmpty) 'nfcUid': nfcUid.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (walletAccountNumber != null &&
            walletAccountNumber.trim().isNotEmpty)
          'walletAccountNumber': walletAccountNumber.trim(),
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'idempotencyKey': idempotencyKey,
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> lookupWakalaTill({
    required String token,
    required String tillNumber,
  }) {
    return _post(
      '/platform/agents/till/lookup',
      {'tillNumber': tillNumber.trim()},
      token: token,
    );
  }

  static Future<Map<String, dynamic>> withdrawToWakala({
    required String token,
    required String tillNumber,
    required int amount,
    String? idempotencyKey,
  }) {
    return _post(
      '/platform/withdrawals',
      {
        'tillNumber': tillNumber.trim(),
        'amount': amount,
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'idempotencyKey': idempotencyKey,
      },
      token: token,
    );
  }

  static Future<Map<String, dynamic>> quoteConductorPayout({
    required String token,
    required int amount,
  }) {
    return _get(
      '/platform/conductor/payouts/quote?amount=$amount',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> requestConductorPayout({
    required String token,
    required String method,
    required String provider,
    required int amount,
    required String idempotencyKey,
    String? mobileNumber,
    String? accountNumber,
    String? accountName,
  }) {
    return _post(
      '/platform/conductor/payouts',
      {
        'method': method,
        'provider': provider.trim(),
        'amount': amount,
        'idempotencyKey': idempotencyKey,
        if (mobileNumber != null && mobileNumber.trim().isNotEmpty)
          'mobileNumber': mobileNumber.trim(),
        if (accountNumber != null && accountNumber.trim().isNotEmpty)
          'accountNumber': accountNumber.trim(),
        if (accountName != null && accountName.trim().isNotEmpty)
          'accountName': accountName.trim(),
      },
      token: token,
    );
  }

  /// Retries transient failures with backoff. Financial posts retry only when
  /// [canRetry] is set, and they resend the same body and idempotency key.
  static Future<http.Response> _send(
    Future<http.Response> Function(String base) run, {
    bool canRetry = true,
  }) async {
    await _discover();
    final attempts = canRetry ? 3 : 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 400 * (1 << (attempt - 1))),
        );
        _ready = false;
        await _discover(force: true);
      }
      try {
        final response = await run(_baseUrl).timeout(_requestTimeout);
        final code = response.statusCode;
        if (code == 400 || code == 401 || code == 403) return response;
        if (code >= 500 && attempt + 1 < attempts) continue;
        return response;
      } on TimeoutException {
        _ready = false;
      } on SocketException {
        _ready = false;
      } on HttpException {
        _ready = false;
      } on http.ClientException {
        _ready = false;
      }
    }
    throw ApiException('Server did not respond', statusCode: 408);
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto({
    required String token,
    required List<int> bytes,
  }) async {
    await _discover();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/auth/profile/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: 'photo.jpg',
      ),
    );
    final streamed = await _client.send(request).timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    return _decode(response, authorized: true);
  }

  static Future<Map<String, dynamic>> deleteProfilePhoto({
    required String token,
  }) async {
    await _discover();
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/auth/profile/photo'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response, authorized: true);
  }

  static Future<List<int>?> downloadProfilePhoto({
    required String token,
  }) async {
    await _discover();
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/auth/profile/photo'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'image/jpeg',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 304 || response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Photo was not uploaded. Try again.', statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    String? token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await _send(
      (base) => _client.get(Uri.parse('$base$path'), headers: headers),
    );
    return _decode(response, authorized: token != null && token.isNotEmpty);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await _send(
      (base) => _client.post(
        Uri.parse('$base$path'),
        headers: headers,
        body: jsonEncode(body),
      ),
      canRetry: body.containsKey('idempotencyKey'),
    );
    return _decode(response, authorized: token != null && token.isNotEmpty);
  }

  /// Called when an authenticated request gets 401 (e.g. signed in elsewhere).
  static void Function()? onSessionExpired;

  static Map<String, dynamic> _decode(
    http.Response response, {
    bool authorized = false,
  }) {
    Map<String, dynamic> data = {};
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      }
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (authorized && response.statusCode == 401) {
      onSessionExpired?.call();
    }

    final message = data['message'];
    throw ApiException(
      message is List
          ? message.join(', ')
          : (message?.toString() ?? 'Request failed'),
      statusCode: response.statusCode,
    );
  }
}
