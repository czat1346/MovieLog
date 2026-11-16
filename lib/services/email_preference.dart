import 'package:shared_preferences/shared_preferences.dart';

/// (Challenge) "이메일 저장" 체크박스용. **이메일만** 저장합니다.
/// 비밀번호와 토큰은 shared_preferences에 절대 두지 않습니다(토큰은 secure storage).
class EmailPreference {
  EmailPreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _savedEmailKey = 'saved_login_email';

  final SharedPreferencesAsync _preferences;

  Future<String?> read() => _preferences.getString(_savedEmailKey);

  Future<void> save(String email) =>
      _preferences.setString(_savedEmailKey, email.trim());

  Future<void> clear() => _preferences.remove(_savedEmailKey);
}
