import '../repositories/repositories.dart';

class AgentLogin {
  AgentLogin(this._auth);
  final AuthRepository _auth;

  Future<Map<String, dynamic>> call({
    required String email,
    required String password,
  }) {
    return _auth.agentLogin(email: email, password: password);
  }
}

class RegisterCard {
  RegisterCard(this._cards);
  final CardRepository _cards;

  Future<Map<String, dynamic>> call({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    required String serialNumber,
    String? nfcUid,
    int initialLoad = 0,
  }) {
    return _cards.registerCard(
      token: token,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      serialNumber: serialNumber,
      nfcUid: nfcUid,
      initialLoad: initialLoad,
    );
  }
}

class RenewCard {
  RenewCard(this._cards);
  final CardRepository _cards;

  Future<Map<String, dynamic>> call({
    required String token,
    required String serialNumber,
    String? nfcUid,
    String? firstName,
    String? lastName,
    String? phone,
    int amount = 0,
    String? idempotencyKey,
  }) {
    return _cards.renewCard(
      token: token,
      serialNumber: serialNumber,
      nfcUid: nfcUid,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      amount: amount,
      idempotencyKey: idempotencyKey,
    );
  }
}

class TopUpCard {
  TopUpCard(this._cards);
  final CardRepository _cards;

  Future<Map<String, dynamic>> call({
    required String token,
    required String serialNumber,
    required int amount,
  }) {
    return _cards.topUpCard(
      token: token,
      serialNumber: serialNumber,
      amount: amount,
    );
  }
}
