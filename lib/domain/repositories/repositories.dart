abstract class AuthRepository {
  Future<Map<String, dynamic>> agentLogin({
    required String email,
    required String password,
  });
}

abstract class CardRepository {
  Future<Map<String, dynamic>> registerCard({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    required String serialNumber,
    String? nfcUid,
    int initialLoad = 0,
  });

  Future<Map<String, dynamic>> renewCard({
    required String token,
    required String serialNumber,
    String? nfcUid,
    String? firstName,
    String? lastName,
    String? phone,
    int amount = 0,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> topUpCard({
    required String token,
    required String serialNumber,
    required int amount,
  });
}
