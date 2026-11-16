import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_error.dart';

/// MovieLog 요청 로그. **Header·요청 body·응답 body는 출력하지 않습니다.**
///
/// 로그인 요청 body에는 비밀번호, 로그인 응답과 보호 요청 Header에는 JWT가 들어 있어
/// Dio 기본 LogInterceptor를 그대로 쓰면 콘솔·스크린샷으로 새어 나갑니다.
/// method / path / status / 서버 error code만 남깁니다.
class MovieLogLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[MovieLog 요청] ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[MovieLog 응답] ${response.statusCode} ${response.requestOptions.uri.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[MovieLog 오류] ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri.path} code=${apiErrorCode(err)}',
    );
    handler.next(err);
  }
}
