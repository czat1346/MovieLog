/// 회원가입 성공 응답의 `result` payload.
/// `CommonResponse<SignUpResult>`로 감싸서 파싱합니다.
class SignUpResult {
  const SignUpResult({
    required this.memberId,
    required this.email,
    required this.nickname,
  });

  final int memberId;
  final String email;
  final String nickname;

  /// 서버 응답 → Dart 객체.
  factory SignUpResult.fromJson(Map<String, dynamic> json) {
    return SignUpResult(
      memberId: (json['memberId'] as num).toInt(),
      email: json['email'] as String,
      nickname: json['nickname'] as String,
    );
  }
}
