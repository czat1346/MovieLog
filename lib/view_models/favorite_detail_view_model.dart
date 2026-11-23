import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';
import 'auth_view_model.dart';

class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    required this.auth,
  });

  // 상세 화면의 TMDB 영화 ID입니다. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 씁니다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final AuthViewModel auth; // 토큰 만료 시 세션을 정리하는 데 씁니다.

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  // 요청 시작 때의 세션이 더 이상 현재가 아니거나 화면이 사라졌으면 true → 응답을 버립니다.
  bool _isStale(int generation) =>
      !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final authVersion = auth.sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (_isStale(snap.generation)) return;
      // AUTH401_2/3/4만 세션 만료입니다. 네트워크 실패·403은 로그아웃하지 않습니다.
      if (isSessionExpiredCode(apiErrorCode(error))) {
        await auth.expireSession(requestVersion: authVersion);
        return;
      }
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } catch (_) {
      if (_isStale(snap.generation)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (!_isStale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  // 서버 성공을 확인한 뒤에 북마크 상태를 바꿉니다. 요청 중에는 중복 탭을 막습니다.
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final authVersion = auth.sessionVersion;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (_isStale(snap.generation)) return;
        isFavorite = false;
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
        if (_isStale(snap.generation)) return;
        isFavorite = true;
      }
    } on DioException catch (error) {
      if (_isStale(snap.generation)) return;
      final code = apiErrorCode(error);
      if (isSessionExpiredCode(code)) {
        await auth.expireSession(requestVersion: authVersion);
        return;
      }
      // 이미 등록(409)이거나 이미 해제(404)이면 POST·DELETE를 다시 보내지 않고
      // 서버의 현재 여부를 GET으로 확인해 화면을 맞춥니다.
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        try {
          final synced = await favoriteApi.checkFavorite(movieId: movieId);
          if (_isStale(snap.generation)) return;
          isFavorite = synced.isFavorite;
          errorMessage = null;
        } catch (_) {
          if (_isStale(snap.generation)) return;
          isFavorite = before;
          errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
        }
      } else {
        isFavorite = before;
        errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
      }
    } catch (_) {
      if (_isStale(snap.generation)) return;
      isFavorite = before;
      errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    } finally {
      if (!_isStale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }
}