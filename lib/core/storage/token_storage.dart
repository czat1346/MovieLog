import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// accessToken 저장·조회·삭제를 한곳에 모은 추상화입니다.
/// 인증 코드가 FlutterSecureStorage에 직접 의존하지 않아 테스트에서 대체하기 쉽습니다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// iOS Keychain / Android Keystore 기반 구현.
/// 비밀번호는 저장하지 않고, shared_preferences에도 토큰을 두지 않습니다.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);
  static const _accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}
