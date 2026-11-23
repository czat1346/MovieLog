import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import 'auth_view_model.dart';

/// 현재 로그인 세션에서 등록·수정한 평점 보관소.
///
/// v7에는 토큰 기반 "내 평점 전체 조회 GET"이 없고 로그인·내 정보 응답에도 memberId가 없습니다.
/// 그래서 등록 응답으로 받은 Rating 객체를 메모리에 모아 같은 세션에서 수정·삭제합니다.
/// **앱 재시작 뒤 기존 평점 복원은 지원하지 않습니다**(계약 확인 전까지 완료 기능이 아님).
///
/// 로그아웃·만료·회원 전환(sessionVersion 변경) 시 비웁니다.
class SessionRatingsStore extends ChangeNotifier {
  SessionRatingsStore(this._auth) : _version = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _version;
  bool _disposed = false;
  final List<RatingDto> _ratings = [];

  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  void _onAuthChanged() {
    if (_auth.sessionVersion == _version && _auth.status == AuthStatus.signedIn) {
      return;
    }
    _version = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings.clear();
    if (!_disposed) notifyListeners();
  }

  /// 요청을 보낸 시점의 [sessionVersion]이 지금과 다르면 이전 세션의 응답이므로 반영하지 않습니다.
  bool add(RatingDto rating, {required int sessionVersion}) {
    if (_disposed || sessionVersion != _auth.sessionVersion) return false;
    _ratings.removeWhere((r) => r.ratingId == rating.ratingId);
    _ratings.insert(0, rating);
    notifyListeners();
    return true;
  }

  bool replace(RatingDto rating, {required int sessionVersion}) {
    if (_disposed || sessionVersion != _auth.sessionVersion) return false;
    final index = _ratings.indexWhere((r) => r.ratingId == rating.ratingId);
    if (index < 0) return false;
    _ratings[index] = rating;
    notifyListeners();
    return true;
  }

  bool remove(int ratingId, {required int sessionVersion}) {
    if (_disposed || sessionVersion != _auth.sessionVersion) return false;
    final before = _ratings.length;
    _ratings.removeWhere((r) => r.ratingId == ratingId);
    if (_ratings.length == before) return false;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
