import 'package:dio/dio.dart';

/// 서버 오류 body의 `code`를 꺼냅니다. 공통 형식이 아니면 null.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 서버 오류 body의 `message`를 꺼냅니다. 공통 형식이 아니면 null.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 현재 세션을 더 이상 쓸 수 없다는 code인지 확인합니다.
///
/// AUTH401_2(토큰 없음) / AUTH401_3(무효) / AUTH401_4(만료)만 해당합니다.
/// 로그인 입력 오류인 AUTH401_1과 권한 부족(403)은 세션 만료가 아닙니다.
bool isSessionExpiredCode(String? code) =>
    code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
