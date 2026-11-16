/// 로그인 요청 body. (POST /v7/auth/login)
class LoginRequest {
  const LoginRequest({required this.email, required this.password});
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password, // 비밀번호는 값을 바꾸지 않고, 저장·로그하지 않습니다.
  };
}

/// 로그인 성공 result. v7 응답에는 memberId가 없습니다(JWT claim도 추정하지 않습니다).
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});
  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }
}
