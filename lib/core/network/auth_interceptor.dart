import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// MovieLog 보호 API에만 `Authorization: Bearer {JWT}`를 붙입니다.
///
/// - 보호 대상은 host + path로 좁힙니다. 외부 URL(TMDB·이미지 등)에는 절대 붙이지 않습니다.
/// - 이 Interceptor는 보호용 Client(createAuthMovieLogClient)에만 등록합니다.
/// - BuildContext를 사용하지 않습니다. 401 처리는 ViewModel이 담당합니다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);
  final TokenStorage _storage;

  static const _host = 'workbook.devnoco.com';

  bool _isProtected(RequestOptions options) {
    final path = options.uri.path;
    return options.uri.host == _host &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isProtected(options)) {
      handler.next(options);
      return;
    }
    options.headers.remove('Authorization'); // 이전 요청의 토큰을 재사용하지 않습니다.
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 서버 401과 기기 저장소 실패는 다른 오류입니다.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
