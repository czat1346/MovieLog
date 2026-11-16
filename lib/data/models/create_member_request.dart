/// 회원가입 요청 body. (POST /v6/members)
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// Dart 객체 → 요청 JSON.
  ///
  /// 이메일·닉네임은 앞뒤 공백을 제거합니다. 비밀번호는 사용자가 입력한 문자가
  /// 의미 있으므로 값을 바꾸지 않습니다(앞뒤 공백 허용 여부는 Form validator가 결정).
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };
}
