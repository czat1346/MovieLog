import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';
import 'error_messages.dart';

/// v7 result(Rating 객체)를 읽습니다. result가 없으면 성공으로 취급하지 않습니다.
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// 평점 API.
///
/// - 조회(공개): memberId path를 유지하며 토큰이 필요 없어 [_publicDio]를 씁니다.
/// - 등록·수정·삭제(보호): memberId 없이 `Authorization` 헤더만으로 사용자를 식별하므로
///   [_authDio]를 씁니다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);
  final Dio _publicDio;
  final Dio _authDio;

  /// GET /v7/members/{memberId}/ratings → 직접 배열 (공개).
  /// v7 로그인·내 정보 응답에 memberId가 없어 현재 화면 흐름에서는 호출하지 않습니다.
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  /// POST /v7/ratings → result = Rating 객체. body에 memberId를 넣지 않습니다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post(
      '/v7/ratings',
      data: request.toJson(),
    );
    return parseRatingResult(response.data);
  }

  /// PATCH /v7/ratings/{ratingId} → result = Rating 객체.
  ///
  /// 부분 수정이 아니라 **전체 교체**입니다. comment를 생략하면 null로 덮이므로
  /// 항상 score·comment를 함께 보냅니다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  /// DELETE /v7/ratings/{ratingId} → 200, result null (v6의 204가 아님).
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

const sessionExpiredMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';

/// 평점 쓰기(등록/수정/삭제) 오류 문구.
///
/// 도메인 오류(RATING403_1 등)는 서버 message를 그대로 보여주고,
/// 세션 만료(AUTH401_2/3/4)는 고정 안내 문구를 씁니다.
String writeErrorMessage(DioException error) {
  if (isSessionExpiredCode(apiErrorCode(error))) return sessionExpiredMessage;
  return errorMessageFrom(
    error,
    fallback: '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
  );
}

/// Dialog 안에 보여줄 쓰기 실패 문구.
String describeWriteError(Object error) {
  if (error is DioException) return writeErrorMessage(error);
  if (error is StateError) return error.message;
  return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
