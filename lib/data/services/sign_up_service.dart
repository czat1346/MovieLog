import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';
import 'error_messages.dart';

/// 회원가입 관련 MovieLog v6 API. (6주차 MemberCheckService에서 이름 변경)
class SignUpService {
  SignUpService(this._dio);
  final Dio _dio;

  /// GET /v6/members/nickname/{nickname} → 성공 시 직접 객체 `{ "available": bool }`
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// GET /v6/members/email/{email} → 성공 시 직접 객체 `{ "available": bool }`
  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// POST /v6/members → 201 + `CommonResponse<SignUpResult>`
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 회원가입 오류(400 비밀번호 형식 / 409 중복)는 서버 message를 그대로 보여줍니다.
String writeSignUpErrorMessage(DioException error) =>
    errorMessageFrom(error, fallback: '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.');
