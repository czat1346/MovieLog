import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_ratings_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 마이페이지 "내가 등록한 평점": 이번 세션에서 등록한 평점의 수정 · 삭제 · (Challenge) 다중 삭제.
///
/// v7에는 토큰 기반 내 평점 전체 조회가 없어 [SessionRatingsStore]의 목록을 보여줍니다.
/// 수정·삭제는 서버 응답(Rating 객체 / 200)을 받은 뒤 store에 반영합니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._store,
    this._auth,
  );

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final SessionRatingsStore _store;
  final AuthViewModel _auth;
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  // ---------- Challenge: 다중 선택 삭제 ----------
  bool isSelectionMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  /// 화면 이탈(dispose) 뒤에 도착한 요청 결과가 notify로 이어지지 않게 막습니다.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// store의 평점에 TMDB 영화 정보를 붙입니다. (평점 자체는 서버 호출 없이 store에서 읽습니다)
  /// 영화 조회 실패·TMDB에 없는 ID는 평점을 지우지 않고 placeholder로 표시합니다.
  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();
    try {
      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      for (final rating in _store.ratings) {
        if (_disposed || version != _requestVersion) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException {
            // 일시적 네트워크 실패는 캐시하지 않습니다. 다음 로딩에서 재시도합니다.
          }
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_disposed || version != _requestVersion) return;
      ratings = entries;
      final liveIds = {for (final entry in entries) entry.rating.ratingId};
      selectedRatingIds.removeWhere((id) => !liveIds.contains(id));
      if (entries.isEmpty) isSelectionMode = false;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } catch (_) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    notifyListeners();
  }

  /// 쓰기 실패 공통 처리. 항상 호출한 쪽에서 rethrow/집계합니다.
  /// - AUTH401_2/3/4: 현재 세션 정리(이전 세션의 늦은 401이면 무시)
  /// - RATING404_1: 서버에 없는 평점이므로 목록에서 제거
  /// - RATING403_1 등: 안내만(로그아웃하지 않음)
  Future<void> _handleWriteError(
    DioException error,
    int ratingId,
    int version,
  ) async {
    if (version != _auth.sessionVersion) return;
    final code = apiErrorCode(error);
    if (isSessionExpiredCode(code)) {
      await _auth.expireSession(requestVersion: version);
    } else if (code == 'RATING404_1') {
      _store.remove(ratingId, sessionVersion: version);
      await load();
    }
  }

  /// PATCH(전체 교체). 실패하면 예외를 다시 던져 Dialog가 오류 문구를 보여주고 재시도하게 합니다.
  /// comment가 null이면 기존 후기가 삭제됩니다(Dialog가 현재 값을 채워 열기 때문에 의도된 동작).
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      if (!_store.replace(updated, sessionVersion: version)) {
        throw StateError('로그인 상태가 바뀌어 결과를 반영하지 않았어요.');
      }
    } on DioException catch (error) {
      await _handleWriteError(error, ratingId, version);
      rethrow;
    }
    await load();
  }

  /// DELETE(200). 성공하면 store에서 빼고 목록을 다시 만듭니다.
  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      if (version != _auth.sessionVersion) {
        throw StateError('로그인 상태가 바뀌어 결과를 반영하지 않았어요.');
      }
      _store.remove(ratingId, sessionVersion: version);
    } on DioException catch (error) {
      await _handleWriteError(error, ratingId, version);
      rethrow;
    }
    await load();
  }

  // ---------- Challenge ----------

  void enterSelectionMode() {
    if (status != MyRatingsLoadStatus.success || isDeletingSelected) return;
    isSelectionMode = true;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    if (isDeletingSelected) return; // 삭제 중에는 선택을 바꾸지 않습니다.
    isSelectionMode = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelection(int ratingId) {
    if (isDeletingSelected) return;
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  /// 선택한 평점을 하나씩 삭제하고, 실패한 개수를 반환합니다.
  /// 실패한 항목은 선택 상태를 유지하고, 성공한 항목만 선택에서 뺍니다.
  /// 세션 만료(401)가 나오면 남은 항목은 시도하지 않고 중단합니다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    isDeletingSelected = true;
    notifyListeners();
    final version = _auth.sessionVersion;
    var failed = 0;
    try {
      // 원본 Set을 순회하며 remove하면 ConcurrentModificationError → 복사본을 순회합니다.
      final targets = selectedRatingIds.toList();
      for (var i = 0; i < targets.length; i++) {
        final ratingId = targets[i];
        if (_disposed) return failed;
        try {
          await _service.deleteRating(ratingId);
          if (version != _auth.sessionVersion) {
            failed += targets.length - i;
            break;
          }
          _store.remove(ratingId, sessionVersion: version);
          selectedRatingIds.remove(ratingId);
        } on DioException catch (error) {
          failed++;
          await _handleWriteError(error, ratingId, version);
          if (isSessionExpiredCode(apiErrorCode(error))) {
            failed += targets.length - i - 1;
            break;
          }
        } catch (_) {
          failed++; // 예상 밖 응답도 실패로 세고, 선택은 유지합니다.
        }
      }
    } finally {
      isDeletingSelected = false;
      notifyListeners(); // 예상하지 못한 오류에도 로딩을 해제합니다.
    }
    if (failed == 0) isSelectionMode = false;
    if (!_disposed) await load();
    return failed;
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}

/// 보여줄 때 쓰는 헬퍼: TMDB에 없는 영화는 `영화 #{movieId}`로 표시합니다.
String movieTitleOrPlaceholder(RatingDto rating, TmdbMovieDto? movie) =>
    movie?.title ?? '영화 #${rating.movieId}';
