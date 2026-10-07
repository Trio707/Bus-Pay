import '../../domain/repositories/repositories.dart';
import '../../services/api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Map<String, dynamic>> agentLogin({
    required String email,
    required String password,
  }) {
    return ApiService.agentLogin(email: email, password: password);
  }
}

class CardRepositoryImpl implements CardRepository {
  @override
  Future<Map<String, dynamic>> registerCard({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    required String serialNumber,
    String? nfcUid,
    int initialLoad = 0,
  }) {
    return ApiService.issueCard(
      token: token,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      serialNumber: serialNumber,
      nfcUid: nfcUid,
      initialLoad: initialLoad,
    );
  }

  @override
  Future<Map<String, dynamic>> renewCard({
    required String token,
    required String serialNumber,
    String? nfcUid,
    String? firstName,
    String? lastName,
    String? phone,
    int amount = 0,
    String? idempotencyKey,
  }) {
    return ApiService.renewCard(
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

  @override
  Future<Map<String, dynamic>> topUpCard({
    required String token,
    required String serialNumber,
    required int amount,
  }) {
    return ApiService.topUpWallet(
      token: token,
      amount: amount,
      serialNumber: serialNumber,
    );
  }
}
