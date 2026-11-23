/// 공통 응답: `{ isSuccess, code, message, result }`
///
/// - 로그인·내 정보·평점 등록/수정(v7, result=객체)과 회원가입 성공 응답, 공통 오류 응답에 사용합니다.
/// - 닉네임/이메일 확인·평점 목록 조회의 **성공** 응답은 직접 객체/배열이라 사용하지 않습니다.
/// - 평점 삭제 성공(v7: 200, result null)은 result를 읽을 필요가 없습니다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;
  final T? result;

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }
}

/// 오류 응답 body를 안전하게 공통 응답으로 읽습니다.
///
/// 서버/프록시가 공통 형식이 아닌 body(HTML, 문자열 등)를 돌려주는 경우에도
/// 오류 처리 코드가 다시 예외를 던지지 않도록, 형식이 맞지 않으면 null을 반환합니다.
CommonResponse<Object?>? tryParseCommonResponse(Object? data) {
  if (data is! Map<String, dynamic>) return null;
  try {
    return CommonResponse<Object?>.fromJson(data, (value) => value);
  } on TypeError {
    return null;
  }
}
