/// 회원가입 로컬 검증. 빠른 안내용이며 서버 검증을 대체하지 않습니다.

/// 닉네임: 앞뒤 공백 제거 후 2~12자.
String? validateNicknameFormat(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 2 || length > 12) return '닉네임은 2~12자여야 합니다.';
  return null;
}

/// 비밀번호: 8자 이상, 소문자·대문자·숫자·`!@#$%^&*` 중 특수문자를 각각 하나 이상.
/// 앞뒤 공백은 허용하지 않습니다(값을 조용히 trim하지 않고 명확히 거절).
String? validatePasswordFormat(String? value) {
  if (value == null || value.isEmpty) return '비밀번호를 입력해주세요';
  if (value != value.trim()) return '비밀번호 앞뒤에는 공백을 둘 수 없습니다.';
  if (value.length < 8) return '비밀번호는 8자 이상이어야 합니다';
  final hasLower = RegExp(r'[a-z]').hasMatch(value);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
  final hasDigit = RegExp(r'[0-9]').hasMatch(value);
  final hasSpecial = RegExp(r'[!@#$%^&*]').hasMatch(value);
  if (!(hasLower && hasUpper && hasDigit && hasSpecial)) {
    return r'비밀번호는 소문자·대문자·숫자·특수문자(!@#$%^&*)를 각각 포함해야 합니다.';
  }
  return null;
}
