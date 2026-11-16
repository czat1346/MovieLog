import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_ratings_store.dart';
import 'submit_status.dart';

/// 영화 상세 화면: 현재 화면의 TMDB 영화와 "평점 등록" 상태만 관리합니다.
/// 수정·삭제는 마이페이지의 MyRatingsViewModel이 맡습니다.
///
/// 사용자 식별은 memberId가 아니라 보호 Client가 붙이는 Authorization 헤더입니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._auth,
    this._store,
    this.movie,
  );

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatingsStore _store;

  /// 서버에 보내는 movieId는 항상 `movie.id`(TMDB 영화 ID)입니다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  bool _disposed = false;

  /// Dialog를 새로 열 때 이전 시도의 결과가 남아 있지 않게 초기화합니다.
  void resetSubmitState() {
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.idle;
    submitMessage = null;
  }

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return; // 연속 탭 차단
    if (_auth.status != AuthStatus.signedIn) {
      submitStatus = SubmitStatus.error;
      submitMessage = '로그인이 필요해요.';
      notifyListeners();
      return;
    }
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      // 화면을 떠났어도 현재 세션의 등록 결과는 보관합니다. 이전 세션 응답은 store가 거부합니다.
      final kept = _store.add(created, sessionVersion: version);
      if (_disposed) return;
      if (kept) {
        submitStatus = SubmitStatus.success;
      } else {
        submitStatus = SubmitStatus.error;
        submitMessage = '로그인 상태가 바뀌어 등록 결과를 반영하지 않았어요.';
      }
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      if (version != _auth.sessionVersion) {
        // 이전 세션의 늦은 오류가 새 세션을 지우지 않게 합니다.
        submitMessage = '로그인 상태가 바뀌어 요청을 무시했어요.';
      } else {
        final code = apiErrorCode(error);
        if (isSessionExpiredCode(code)) {
          submitMessage = sessionExpiredMessage;
          await _auth.expireSession(requestVersion: version);
        } else if (code == 'RATING409_1') {
          submitMessage = '이미 이 영화에 평점을 남겼어요. 내가 등록한 평점에서 확인해 주세요.';
        } else {
          // RATING403_1·COMMON400 등: 서버 message를 그대로 보여주고 로그아웃하지 않습니다.
          submitMessage = writeErrorMessage(error);
        }
      }
    } on StateError {
      // 2xx지만 result가 없는 등 계약 밖 응답: 저장됐을 수 있으므로 재전송(409)을 유도하지 않습니다.
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '등록 결과를 확인하지 못했어요. 내가 등록한 평점에서 확인해 주세요.';
    } catch (_) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
