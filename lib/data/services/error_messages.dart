import 'package:dio/dio.dart';

import '../models/common_response.dart';

/// 오류 응답에서 사용자에게 보여줄 문장을 꺼냅니다.
///
/// 서버 `message`에 이미 사용자용 문장이 들어 있으므로 우선 사용하고,
/// 응답이 없거나 공통 형식이 아니면 연결 문제/기본 문구로 대체합니다.
String errorMessageFrom(DioException error, {required String fallback}) {
  final serverMessage = tryParseCommonResponse(error.response?.data)?.message;
  if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
    default:
      return fallback;
  }
}

/// 오류 응답의 공통 `code`(예: COMMON403). 공통 형식이 아니면 null.
String? errorCodeFrom(DioException error) =>
    tryParseCommonResponse(error.response?.data)?.code;
