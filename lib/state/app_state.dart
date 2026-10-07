import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/account_store.dart';
import '../auth/login_id.dart';
import '../services/api_service.dart';

class Transaction {
  Transaction({
    required this.passengerName,
    required this.amount,
    required this.time,
    this.type = TransactionType.nauli,
    this.detail = '',
    this.reference = '',
    this.fee,
    this.totalDebit,
  });

  final String passengerName;
  final int amount;
  final DateTime time;
  final TransactionType type;
  final String detail;
  final String reference;
  final int? fee;
  final int? totalDebit;
}

enum TransactionType { nauli, toaPesa, tumaPesa }

enum AppLanguage { sw, en }

enum DisplaySize { compact, normal, large }

class UserAccount {
  UserAccount({
    required this.username,
    required this.password,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.nida = '',
    this.email = '',
    this.tillNumber = '',
    this.id = '',
  });

  String username;
  String password;
  UserRole role;
  String firstName;
  String lastName;
  String phone;
  String nida;
  String email;
  String tillNumber;
  String id;

  String get fullName => '$firstName $lastName'.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
}

class AppState extends ChangeNotifier {
  int walletBalance = 0;
  final List<Transaction> transactions = [];
  ThemeMode themeMode = ThemeMode.light;
  AppLanguage language = AppLanguage.sw;
  DisplaySize displaySize = DisplaySize.normal;
  bool walletHidden = true;
  bool dataSaver = true;
  bool ledgerHasMore = false;
  String? ledgerCursor;
  UserRole? currentRole;
  UserAccount? currentUser;
  String? authToken;
  bool mustChangePassword = false;
  String? profilePhotoUpdatedAt;
  String? hiddenUsername;

  double get textScale => switch (displaySize) {
        DisplaySize.compact => 0.90,
        DisplaySize.normal => 1.0,
        DisplaySize.large => 1.15,
      };

  String get displayName => currentUser?.fullName ?? '';
  String get displayId => currentUser?.phone ?? '';
  String get displayPhone => currentUser?.phone ?? '';
  String get displayEmail => currentUser?.email ?? '';
  String get agentTill => currentUser?.tillNumber ?? '0000-0000';
  int get historyPageSize => dataSaver ? 10 : 20;

  Future<void>? _ledgerFlight;
  bool _ledgerFlightHasHistory = false;

  void applyRemoteLogin(
    Map<String, dynamic> data, {
    bool notify = true,
    bool scheduleLedger = true,
  }) {
    final rawUser = data['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : Map<String, dynamic>.from(data);

    authToken = (data['token'] ?? data['accessToken'] ?? user['token'])
        ?.toString();

    final phone = (user['phone'] ?? user['mobile'] ?? '').toString();
    final username = (user['username'] ?? hiddenUsername ?? '').toString();
    final roleValue =
        (user['role'] ?? data['role'] ?? '').toString().toLowerCase();
    final role = roleValue.contains('agent')
        ? UserRole.agent
        : (LoginId.roleOf(username) ?? UserRole.conductor);

    final names = (user['name'] ?? user['fullName'] ?? '').toString().trim();
    var first = (user['firstName'] ?? '').toString().trim();
    var last = (user['lastName'] ?? '').toString().trim();
    if (first.isEmpty && names.isNotEmpty) {
      final parts = names.split(RegExp(r'\s+'));
      first = parts.first;
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    currentUser = UserAccount(
      username: username.isEmpty ? phone : username,
      password: '',
      role: role,
      firstName: first.isEmpty ? 'Conductor' : first.toUpperCase(),
      lastName: last.toUpperCase(),
      phone: phone,
      nida: (user['nida'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      tillNumber: (user['tillNumber'] ?? user['till'] ?? '').toString(),
      id: (user['id'] ?? '').toString(),
    );
    currentRole = role;
    mustChangePassword = user['mustChangePassword'] == true;
    final photoVersion = user['profilePhotoUpdatedAt']?.toString();
    profilePhotoUpdatedAt =
        photoVersion == null || photoVersion.isEmpty ? null : photoVersion;
    final collected = user['collected'] ?? data['collected'];
    if (collected is num) walletBalance = collected.toInt();
    if (role == UserRole.conductor && username.isNotEmpty) {
      hiddenUsername = username;
      AccountStore.saveUsername(username);
    }
    if (notify) notifyListeners();
    // Load ledger after navigation settles — avoids login-screen flicker.
    if (scheduleLedger) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        refreshLedger(history: !dataSaver);
      });
    }
  }

  /// Call after the login reveal finishes so UI rebuilds do not jank the slide.
  void finishLoginReveal() {
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      refreshLedger(history: !dataSaver);
    });
  }

  Future<void> loadSavedAccount() async {
    hiddenUsername = await AccountStore.readUsername();
    dataSaver = await AccountStore.readDataSaver();
    await _restoreLedger();
    notifyListeners();
  }

  Future<void> rememberAccount(String username) async {
    hiddenUsername = username;
    await AccountStore.saveUsername(username);
    notifyListeners();
  }

  void setProfilePhotoVersion(String? updatedAt) {
    profilePhotoUpdatedAt =
        updatedAt == null || updatedAt.isEmpty ? null : updatedAt;
    notifyListeners();
  }

  void passwordChangeCompleted() {
    mustChangePassword = false;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    currentRole = null;
    authToken = null;
    mustChangePassword = false;
    profilePhotoUpdatedAt = null;
    walletBalance = 0;
    transactions.clear();
    ledgerCursor = null;
    ledgerHasMore = false;
    AccountStore.clearSessionCache();
    notifyListeners();
  }

  void setDataSaver(bool enabled) {
    dataSaver = enabled;
    AccountStore.saveDataSaver(enabled);
    notifyListeners();
  }

  /// One in-flight ledger read. A history request is not replaced by a summary.
  Future<void> refreshLedger({bool history = true}) {
    if (_ledgerFlight != null && (_ledgerFlightHasHistory || !history)) {
      return _ledgerFlight!;
    }
    final run = _loadLedger(history);
    _ledgerFlight = run;
    _ledgerFlightHasHistory = history;
    return run.whenComplete(() {
      if (identical(_ledgerFlight, run)) _ledgerFlight = null;
    });
  }

  Future<void> loadMoreLedger() async {
    final cursor = ledgerCursor;
    if (!ledgerHasMore || cursor == null || cursor.isEmpty) return;
    final token = authToken;
    if (token == null || token.isEmpty) return;
    try {
      final data = await ApiService.getTransactions(
        token: token,
        limit: historyPageSize,
        cursor: cursor,
      );
      applyLedger(data, append: true);
    } catch (_) {}
  }

  Future<void> _loadLedger(bool history) async {
    final token = authToken;
    if (token == null || token.isEmpty) return;
    try {
      final data = await ApiService.getTransactions(
        token: token,
        limit: historyPageSize,
        summary: !history,
      );
      applyLedger(data, replaceHistory: history);
    } catch (_) {}
  }

  Future<void> _restoreLedger() async {
    final raw = await AccountStore.readLedger();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final collected = decoded['collected'];
      if (collected is num) walletBalance = collected.toInt();
      final rows = decoded['transactions'];
      if (rows is! List) return;
      transactions
        ..clear()
        ..addAll(rows.whereType<Map>().map((row) {
          final map = Map<String, dynamic>.from(row);
          final typeName = (map['type'] ?? 'nauli').toString();
          final type = TransactionType.values.asNameMap()[typeName] ??
              TransactionType.nauli;
          return Transaction(
            passengerName: (map['passengerName'] ?? '').toString(),
            amount: (map['amount'] as num?)?.toInt() ?? 0,
            time: DateTime.tryParse('${map['time'] ?? ''}')?.toLocal() ??
                DateTime.now(),
            type: type,
            detail: (map['detail'] ?? '').toString(),
            reference: (map['reference'] ?? '').toString(),
            fee: (map['fee'] as num?)?.toInt(),
            totalDebit: (map['totalDebit'] as num?)?.toInt(),
          );
        }));
    } catch (_) {}
  }

  Future<void> _persistLedger() async {
    final payload = {
      'collected': walletBalance,
      'transactions': transactions.take(20).map((tx) => {
            'passengerName': tx.passengerName,
            'amount': tx.amount,
            'time': tx.time.toUtc().toIso8601String(),
            'type': tx.type.name,
            'detail': tx.detail,
            'reference': tx.reference,
            'fee': tx.fee,
            'totalDebit': tx.totalDebit,
          }).toList(),
    };
    await AccountStore.saveLedger(jsonEncode(payload));
  }

  void setWalletBalance(int value) {
    walletBalance = value < 0 ? 0 : value;
    notifyListeners();
  }

  void applyLedger(
    Map<String, dynamic> data, {
    bool replaceHistory = true,
    bool append = false,
  }) {
    final collected = data['collected'];
    if (collected is num) walletBalance = collected.toInt();
    if (!replaceHistory) {
      notifyListeners();
      _persistLedger();
      return;
    }
    final nauli = _parseNauli(data['transactions']);
    final withdrawals = _parseWithdrawals(data['withdrawals']);
    final payouts = _parsePayouts(data['payouts']);
    final incoming = [...nauli, ...withdrawals, ...payouts];
    if (append) {
      final seen = transactions
          .map((tx) => '${tx.type.name}:${tx.reference}')
          .toSet();
      for (final tx in incoming) {
        final key = '${tx.type.name}:${tx.reference}';
        if (tx.reference.isEmpty || !seen.contains(key)) {
          transactions.add(tx);
          seen.add(key);
        }
      }
    } else {
      transactions
        ..clear()
        ..addAll(incoming);
    }
    transactions.sort((a, b) => b.time.compareTo(a.time));
    if (collected is! num && !append) {
      walletBalance = nauli.fold(0, (sum, tx) => sum + tx.amount) -
          withdrawals.fold(0, (sum, tx) => sum + tx.amount);
      if (walletBalance < 0) walletBalance = 0;
    }
    ledgerHasMore = data['hasMore'] == true;
    final next = data['nextCursor']?.toString();
    ledgerCursor = next == null || next.isEmpty ? null : next;
    notifyListeners();
    _persistLedger();
  }

  List<Transaction> _parseNauli(Object? rows) {
    if (rows is! List) return const [];
    return rows.map((row) {
      final map = row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};
      final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}') ??
          DateTime.now();
      final card = (map['card'] ?? '').toString().trim();
      return Transaction(
        passengerName: card.isEmpty ? 'D-Card' : card,
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        time: createdAt.toLocal(),
        reference: (map['reference'] ?? '').toString(),
        detail: (map['card'] ?? '').toString(),
      );
    }).toList();
  }

  List<Transaction> _parseWithdrawals(Object? rows) {
    if (rows is! List) return const [];
    return rows.map((row) {
      final map = row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};
      final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}') ??
          DateTime.now();
      final agent = (map['agent'] ?? '').toString().trim();
      final till = (map['tillNumber'] ?? '').toString().trim();
      final detail = till.isEmpty ? 'Wakala' : till;
      return Transaction(
        passengerName: agent.isEmpty ? 'Wakala' : agent,
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        time: createdAt.toLocal(),
        type: TransactionType.toaPesa,
        reference: (map['reference'] ?? '').toString(),
        detail: detail,
      );
    }).toList();
  }

  List<Transaction> _parsePayouts(Object? rows) {
    if (rows is! List) return const [];
    return rows.map((row) {
      final map = row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};
      final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}') ??
          DateTime.now();
      final provider = (map['provider'] ?? '').toString();
      final destination = (map['destination'] ?? '').toString();
      final status = (map['status'] ?? '').toString();
      final fee = (map['platformFee'] as num?)?.toInt() ?? (map['fee'] as num?)?.toInt();
      return Transaction(
        passengerName: destination.isEmpty ? provider : '$provider $destination',
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        time: createdAt.toLocal(),
        type: TransactionType.toaPesa,
        reference: (map['reference'] ?? '').toString(),
        detail: status,
        fee: fee,
        totalDebit: (map['totalDebit'] as num?)?.toInt(),
      );
    }).toList();
  }

  void toggleWalletHidden() {
    walletHidden = !walletHidden;
    notifyListeners();
  }

  void addNauliPayment({
    required String passengerName,
    required int amount,
  }) {
    walletBalance += amount;
    transactions.insert(
      0,
      Transaction(
        passengerName: passengerName,
        amount: amount,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  bool withdrawToAgent({
    required String agentName,
    required int amount,
  }) {
    if (amount <= 0 || amount > walletBalance) return false;
    walletBalance -= amount;
    transactions.insert(
      0,
      Transaction(
        passengerName: agentName,
        amount: amount,
        time: DateTime.now(),
        type: TransactionType.toaPesa,
        detail: 'Wakala',
      ),
    );
    notifyListeners();
    return true;
  }

  bool sendMobileMoney({
    required String network,
    required String phone,
    required int amount,
  }) {
    if (amount <= 0 || amount > walletBalance) return false;
    walletBalance -= amount;
    transactions.insert(
      0,
      Transaction(
        passengerName: phone,
        amount: amount,
        time: DateTime.now(),
        type: TransactionType.tumaPesa,
        detail: network,
      ),
    );
    notifyListeners();
    return true;
  }

  void setTheme(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    language = value;
    notifyListeners();
  }

  void setDisplaySize(DisplaySize value) {
    displaySize = value;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phone,
  }) {
    final user = currentUser;
    if (user == null) return;
    if (name != null) {
      final parts = name.trim().split(RegExp(r'\s+'));
      user.firstName = parts.isEmpty ? user.firstName : parts.first.toUpperCase();
      user.lastName = parts.length > 1 ? parts.sublist(1).join(' ').toUpperCase() : '';
    }
    if (email != null) user.email = email;
    if (phone != null) user.phone = phone;
    notifyListeners();
  }

  String changePassword({
    required String newPassword,
    required String confirmPassword,
  }) {
    final user = currentUser;
    if (user == null) return 'no_user';
    if (newPassword != confirmPassword) return 'mismatch';
    user.password = newPassword;
    notifyListeners();
    return 'ok';
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
