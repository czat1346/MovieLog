import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'load_phase.dart';

class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    required this.auth,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final AuthViewModel auth;
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  bool _isStale(int sessionGeneration, int refreshGeneration) =>
      !sessionGuard.isCurrent(sessionGeneration, accountId) ||
      refreshGeneration != _refreshGeneration ||
      isDisposed;

  // 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 5개씩 보충합니다.
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final authVersion = auth.sessionVersion;
    final refreshGeneration = ++_refreshGeneration;
    // 이미 목록이 보이는 중(ready)이면 전체 로딩으로 바꾸지 않고 뒤에서 조용히 갱신합니다.
    if (phase != LoadPhase.ready) phase = LoadPhase.loading;
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      final enriched = await mapBounded(favorites, enrichmentConcurrency, (
        favorite,
      ) async {
        try {
          // movieId로 TMDB 상세를 조회해 제목·포스터를 보충합니다. (실패해도 이 카드만 실패 처리)
          final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
          return FavoriteListItem(favorite: favorite, movie: movie);
        } catch (_) {
          return FavoriteListItem(
            favorite: favorite,
            errorMessage: '영화 정보를 불러오지 못했습니다.',
          );
        }
      });
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      // 내 즐겨찾기 목록(MovieLog)의 AUTH401_2/3/4만 세션 만료입니다.
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await auth.expireSession(requestVersion: authVersion);
        return;
      }
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } catch (_) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } finally {
      if (!_isStale(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  // "정보 재조회" 버튼: 영화 정보를 못 가져온 카드 한 개만 다시 조회합니다. 다른 카드는 그대로 둡니다.
  Future<void> retryMovie(int movieId) async {
    final sessionGeneration = sessionGuard.generation;
    final refreshGeneration = _refreshGeneration;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final index = items.indexWhere((e) => e.favorite.movieId == movieId);
    if (index < 0) return;
    final target = items[index];
    FavoriteListItem replaced;
    try {
      final movie = await tmdbApi.fetchMovieDetail(movieId);
      replaced = FavoriteListItem(favorite: target.favorite, movie: movie);
    } catch (_) {
      replaced = FavoriteListItem(
        favorite: target.favorite,
        errorMessage: '다시 시도했지만 영화 정보를 불러오지 못했습니다.',
      );
    }
    // 그 사이 목록이 새로 갱신되었거나 세션이 바뀌었다면 결과를 버립니다.
    if (_isStale(sessionGeneration, refreshGeneration)) return;
    final current = items.indexWhere((e) => e.favorite.movieId == movieId);
    if (current < 0) return;
    items = [...items]..[current] = replaced;
    notifyIfAlive();
  }
}