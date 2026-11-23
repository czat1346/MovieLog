import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 API. **보호 Client**(AuthInterceptor 등록)로만 호출합니다.
class MemberApiService {
  MemberApiService(this._authDio);
  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v8/members/me');
    return parseMemberInfo(response.data);
  }

  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v8/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
