import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountStore {
  static const _usernameKey = 'hidden_username';
  static const _hostKey = 'api_host';
  static const _dataSaverKey = 'data_saver';
  static const _ledgerKey = 'ledger_cache';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> readUsername() {
    return _storage.read(key: _usernameKey);
  }

  static Future<void> saveUsername(String username) {
    return _storage.write(key: _usernameKey, value: username);
  }

  static Future<String?> readApiHost() => _storage.read(key: _hostKey);

  static Future<void> saveApiHost(String host) {
    return _storage.write(key: _hostKey, value: host);
  }

  /// Missing value means Data Saver stays on.
  static Future<bool> readDataSaver() async {
    final value = await _storage.read(key: _dataSaverKey);
    if (value == null) return true;
    return value == '1';
  }

  static Future<void> saveDataSaver(bool enabled) {
    return _storage.write(key: _dataSaverKey, value: enabled ? '1' : '0');
  }

  static Future<String?> readLedger() => _storage.read(key: _ledgerKey);

  static Future<void> saveLedger(String json) {
    return _storage.write(key: _ledgerKey, value: json);
  }

  static Future<void> clearSessionCache() {
    return _storage.delete(key: _ledgerKey);
  }
}
