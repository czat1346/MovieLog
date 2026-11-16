import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'movie_log_logging_interceptor.dart';

BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
}

/// 공개 요청용: 로그인, 회원가입, 중복 확인, 유저별 평점 조회.
/// AuthInterceptor가 없으므로 토큰이 실릴 수 없습니다.
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());
  if (kDebugMode) dio.interceptors.add(MovieLogLoggingInterceptor());
  return dio;
}

/// 보호 요청용: 내 정보, 평점 등록/수정/삭제.
/// AuthInterceptor를 먼저 등록해 Bearer를 붙이고, 로그는 그 뒤에 둡니다.
/// TMDB Client(createTmdbClient)와는 절대 합치지 않습니다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  if (kDebugMode) dio.interceptors.add(MovieLogLoggingInterceptor());
  return dio;
}
