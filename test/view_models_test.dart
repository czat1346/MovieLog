import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_ratings_store.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/view_models/submit_status.dart';

/// 공통 오류 응답을 가진 DioException을 만든다.
DioException apiError(int status, String code, String message) {
  final options = RequestOptions(path: '/test');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: {
        'isSuccess': false,
        'code': code,
        'message': message,
        'result': null,
      },
    ),
  );
}

DioException networkError() => DioException(
  requestOptions: RequestOptions(path: '/test'),
  type: DioExceptionType.connectionError,
);

// ---------------------------------------------------------------------------
// Fakes (네트워크·기기 저장소 없이 ViewModel 로직만 검증)
// ---------------------------------------------------------------------------

class FakeTokenStorage implements TokenStorage {
  String? token;
  Object? readError;
  Object? deleteError;
  int deleteCalls = 0;

  @override
  Future<void> saveAccessToken(String value) async => token = value;

  @override
  Future<String?> readAccessToken() async {
    if (readError != null) throw readError!;
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    token = null;
  }
}

class FakeAuthApi extends AuthApiService {
  FakeAuthApi() : super(Dio());
  Object? error;
  LoginResult result = const LoginResult(nickname: '무비', accessToken: 'jwt-1');
  int calls = 0;

  @override
  Future<LoginResult> login(LoginRequest request) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

final member = MemberInfo(
  email: 'a@b.com',
  nickname: '무비',
  createdAt: DateTime(2026, 10, 10),
);

class FakeMemberApi extends MemberApiService {
  FakeMemberApi() : super(Dio());
  Object? fetchError;
  Object? updateError;
  MemberInfo me = member;
  int fetchCalls = 0;
  int updateCalls = 0;

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return me;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    me = MemberInfo(
      email: me.email,
      nickname: nickname,
      createdAt: me.createdAt,
    );
    return me;
  }
}

class FakeSignUpService extends SignUpService {
  FakeSignUpService() : super(Dio());
  Object? error; // 던질 예외
  SignUpResult? result = const SignUpResult(
    memberId: 42,
    email: 'a@b.com',
    nickname: '무비',
  );
  int calls = 0;

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    calls++;
    if (error != null) throw error!;
    return CommonResponse<SignUpResult>(
      isSuccess: true,
      code: 'COMMON201',
      message: 'ok',
      result: result,
    );
  }
}

/// v7 서버 흉내: 등록하면 Rating 객체를 돌려주고, 수정·삭제는 보유한 평점에만 동작한다.
class FakeRatingService extends RatingApiService {
  FakeRatingService() : super(Dio(), Dio());
  final Map<int, RatingDto> server = {};
  int _nextId = 1;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  final Set<int> deleteFailures = {};
  final List<String> log = [];

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    log.add('POST movieId=${request.movieId} score=${request.score}');
    if (createError != null) throw createError!;
    final created = RatingDto(
      ratingId: _nextId++,
      movieId: request.movieId,
      score: request.score,
      comment: request.comment,
      createdAt: DateTime(2026, 11, 16),
    );
    server[created.ratingId] = created;
    return created;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    log.add('PATCH $ratingId score=$score comment=$comment');
    if (updateError != null) throw updateError!;
    final old = server[ratingId]!;
    final updated = RatingDto(
      ratingId: ratingId,
      movieId: old.movieId,
      score: score,
      comment: comment,
      createdAt: old.createdAt,
    );
    server[ratingId] = updated;
    return updated;
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    log.add('DELETE $ratingId');
    if (deleteError != null) throw deleteError!;
    if (deleteFailures.contains(ratingId)) {
      throw apiError(500, 'COMMON500', '서버 오류');
    }
    server.remove(ratingId);
  }
}

class FakeTmdbService extends TmdbMovieService {
  FakeTmdbService() : super(Dio());
  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async => null;
}

const movie = TmdbMovieDto(
  id: 550,
  title: '파이트 클럽',
  overview: '',
  posterPath: null,
  backdropPath: null,
  releaseDate: '1999-10-15',
  genreIds: [],
  voteAverage: 8.4,
  popularity: 1,
);

/// 로그인까지 끝난 AuthViewModel을 만든다.
Future<AuthViewModel> signedInAuth({
  FakeTokenStorage? storage,
  FakeMemberApi? memberApi,
}) async {
  final auth = AuthViewModel(
    FakeAuthApi(),
    memberApi ?? FakeMemberApi(),
    storage ?? FakeTokenStorage(),
  );
  await auth.login('a@b.com', 'Abcdef1!');
  expect(auth.status, equals(AuthStatus.signedIn));
  return auth;
}

/// 요청 Header를 기록만 하는 어댑터.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SignUpViewModel.submit', () {
    const request = CreateMemberRequest(
      email: 'a@b.com',
      password: 'Abcdef1!',
      nickname: '무비',
    );

    test('성공: result.memberId를 보관한다', () async {
      final vm = SignUpViewModel(FakeSignUpService());
      await vm.submit(request);
      expect(vm.submitStatus, equals(SubmitStatus.success));
      expect(vm.createdMemberId, equals(42));
    });

    test('result가 null이면 가입 완료로 표시하지 않는다', () async {
      final service = FakeSignUpService()..result = null;
      final vm = SignUpViewModel(service);
      await vm.submit(request);
      expect(vm.submitStatus, equals(SubmitStatus.error));
      expect(vm.createdMemberId, isNull);
      expect(vm.snackbarMessage, isNotNull);
    });

    test('400 비밀번호 형식 → passwordErrorText (Snackbar 아님)', () async {
      final service = FakeSignUpService()
        ..error = apiError(400, 'COMMON400',
            '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.');
      final vm = SignUpViewModel(service);
      await vm.submit(request);
      expect(vm.passwordErrorText, contains('비밀번호'));
      expect(vm.snackbarMessage, isNull);
      expect(vm.submitStatus, equals(SubmitStatus.error));

      vm.onPasswordChanged(); // 입력을 고치기 시작하면 서버 오류 해제
      expect(vm.passwordErrorText, isNull);
    });

    test('다른 400 → Snackbar', () async {
      final service = FakeSignUpService()
        ..error = apiError(400, 'COMMON400', '요청 형식이 올바르지 않습니다.');
      final vm = SignUpViewModel(service);
      await vm.submit(request);
      expect(vm.passwordErrorText, isNull);
      expect(vm.snackbarMessage, equals('요청 형식이 올바르지 않습니다.'));
    });

    test('409 이메일 중복 → Snackbar + 이메일 확인 상태를 duplicated로', () async {
      final service = FakeSignUpService()
        ..error = apiError(409, 'COMMON409', '이미 사용 중인 이메일입니다.');
      final vm = SignUpViewModel(service);
      vm.onEmailChanged('a@b.com');
      await vm.submit(request);
      expect(vm.snackbarMessage, equals('이미 사용 중인 이메일입니다.'));
      expect(vm.emailCheckStatus, equals(CheckStatus.duplicated));
      expect(vm.canCheckEmail, isFalse);
    });

    test('409 닉네임 중복은 닉네임 칸만 표시', () async {
      final service = FakeSignUpService()
        ..error = apiError(409, 'COMMON409', '이미 사용 중인 닉네임입니다.');
      final vm = SignUpViewModel(service);
      vm.onNicknameChanged('무비');
      vm.onEmailChanged('a@b.com');
      await vm.submit(request);
      expect(vm.nicknameCheckStatus, equals(CheckStatus.duplicated));
      expect(vm.emailCheckStatus, equals(CheckStatus.idle));
    });

    test('예상 밖 예외에도 제출 중 상태가 남지 않는다', () async {
      final service = FakeSignUpService()..error = const FormatException('x');
      final vm = SignUpViewModel(service);
      await vm.submit(request);
      expect(vm.submitStatus, equals(SubmitStatus.error));
    });

    test('입력을 바꾸면 이전 제출 오류가 무효화된다', () async {
      final service = FakeSignUpService()
        ..error = apiError(409, 'COMMON409', '이미 사용 중인 이메일입니다.');
      final vm = SignUpViewModel(service);
      await vm.submit(request);
      vm.onNicknameChanged('다른닉');
      expect(vm.snackbarMessage, isNull);
      expect(vm.submitStatus, equals(SubmitStatus.idle));
    });
  });

  group('authRedirect', () {
    test('initializing·retryRequired는 /start만 허용', () {
      expect(authRedirect(AuthStatus.initializing, '/home'), equals('/start'));
      expect(authRedirect(AuthStatus.initializing, '/login'), equals('/start'));
      expect(authRedirect(AuthStatus.initializing, '/start'), isNull);
      expect(authRedirect(AuthStatus.retryRequired, '/my'), equals('/start'));
      expect(authRedirect(AuthStatus.retryRequired, '/start'), isNull);
    });

    test('signedOut·authenticating은 /login·/register만 허용', () {
      for (final status in [AuthStatus.signedOut, AuthStatus.authenticating]) {
        expect(authRedirect(status, '/home'), equals('/login'));
        expect(authRedirect(status, '/my/ratings'), equals('/login'));
        expect(authRedirect(status, '/movies/550'), equals('/login'));
        expect(authRedirect(status, '/start'), equals('/login'));
        expect(authRedirect(status, '/login'), isNull);
        expect(authRedirect(status, '/register'), isNull);
      }
    });

    test('signedIn은 /start·/login·/register에서 /home으로', () {
      expect(authRedirect(AuthStatus.signedIn, '/start'), equals('/home'));
      expect(authRedirect(AuthStatus.signedIn, '/login'), equals('/home'));
      expect(authRedirect(AuthStatus.signedIn, '/register'), equals('/home'));
      expect(authRedirect(AuthStatus.signedIn, '/my'), isNull);
    });
  });

  group('AuthInterceptor', () {
    Future<List<RequestOptions>> run(
      TokenStorage storage,
      List<String> urls,
    ) async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(storage));
      for (final url in urls) {
        await dio.get(url);
      }
      return adapter.requests;
    }

    test('보호 경로에만 Bearer를 붙인다', () async {
      final storage = FakeTokenStorage()..token = 'jwt-secret';
      final requests = await run(storage, [
        '/v7/members/me',
        '/v7/ratings',
        '/v7/ratings/3',
        '/v7/members/9/ratings', // 공개 조회
        '/v7/auth/login', // 공개
      ]);
      expect(requests[0].headers['Authorization'], equals('Bearer jwt-secret'));
      expect(requests[1].headers['Authorization'], equals('Bearer jwt-secret'));
      expect(requests[2].headers['Authorization'], equals('Bearer jwt-secret'));
      expect(requests[3].headers.containsKey('Authorization'), isFalse);
      expect(requests[4].headers.containsKey('Authorization'), isFalse);
    });

    test('다른 host(TMDB·이미지)에는 붙이지 않는다', () async {
      final storage = FakeTokenStorage()..token = 'jwt-secret';
      final adapter = _RecordingAdapter();
      final dio = Dio()
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(storage));
      await dio.get('https://api.themoviedb.org/v7/ratings');
      expect(adapter.requests.single.headers.containsKey('Authorization'),
          isFalse);
    });

    test('토큰이 없으면 헤더 없이 보내고, 저장소 오류는 요청을 보내지 않는다', () async {
      final empty = await run(FakeTokenStorage(), ['/v7/members/me']);
      expect(empty.single.headers.containsKey('Authorization'), isFalse);

      final broken = FakeTokenStorage()..readError = StateError('keystore');
      await expectLater(
        run(broken, ['/v7/members/me']),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('AuthViewModel', () {
    test('복원: 토큰 없음 → signedOut (GET me 호출 없음)', () async {
      final memberApi = FakeMemberApi();
      final auth = AuthViewModel(FakeAuthApi(), memberApi, FakeTokenStorage());
      await auth.restoreSession();
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(memberApi.fetchCalls, equals(0));
    });

    test('복원: 토큰이 있어도 GET me 성공 뒤에만 signedIn', () async {
      final storage = FakeTokenStorage()..token = 'jwt-1';
      final memberApi = FakeMemberApi();
      final auth = AuthViewModel(FakeAuthApi(), memberApi, storage);
      final future = auth.restoreSession();
      expect(auth.status, equals(AuthStatus.initializing)); // 검증 전에는 확정하지 않음
      await future;
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(auth.member?.nickname, equals('무비'));
      expect(memberApi.fetchCalls, equals(1));
    });

    test('복원: 네트워크 실패 → retryRequired, 토큰은 지우지 않는다', () async {
      final storage = FakeTokenStorage()..token = 'jwt-1';
      final memberApi = FakeMemberApi()..fetchError = networkError();
      final auth = AuthViewModel(FakeAuthApi(), memberApi, storage);
      await auth.restoreSession();
      expect(auth.status, equals(AuthStatus.retryRequired));
      expect(storage.token, equals('jwt-1'));
      expect(storage.deleteCalls, equals(0));
      expect(auth.sessionExpired, isFalse);

      memberApi.fetchError = null; // 다시 시도
      await auth.restoreSession();
      expect(auth.status, equals(AuthStatus.signedIn));
    });

    test('복원: 저장소 읽기 실패 → retryRequired', () async {
      final storage = FakeTokenStorage()..readError = StateError('keystore');
      final auth = AuthViewModel(FakeAuthApi(), FakeMemberApi(), storage);
      await auth.restoreSession();
      expect(auth.status, equals(AuthStatus.retryRequired));
    });

    test('복원: AUTH401_2/3/4 → 토큰 삭제 + signedOut + 만료 표시', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        final storage = FakeTokenStorage()..token = 'jwt-1';
        final memberApi = FakeMemberApi()
          ..fetchError = apiError(401, code, '인증 오류');
        final auth = AuthViewModel(FakeAuthApi(), memberApi, storage);
        await auth.restoreSession();
        expect(auth.status, equals(AuthStatus.signedOut), reason: code);
        expect(storage.token, isNull, reason: code);
        expect(auth.sessionExpired, isTrue, reason: code);
      }
    });

    test('로그인 성공: 토큰 저장 → signedIn, GET me는 MainScreen이 loadMember로', () async {
      final storage = FakeTokenStorage();
      final memberApi = FakeMemberApi();
      final auth = AuthViewModel(FakeAuthApi(), memberApi, storage);
      await auth.login(' a@b.com ', 'Abcdef1!');
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(storage.token, equals('jwt-1'));
      expect(memberApi.fetchCalls, equals(0)); // 로그인 함수에 GET me를 중복 추가하지 않는다
      expect(auth.member, isNull);

      await auth.loadMember();
      expect(auth.member?.email, equals('a@b.com'));
      expect(auth.memberStatus, equals(MemberLoadStatus.success));
      await auth.loadMember(); // 이미 있으면 다시 부르지 않음
      expect(memberApi.fetchCalls, equals(1));
    });

    test('로그인 AUTH401_1: Form 오류, 만료 처리 아님', () async {
      final api = FakeAuthApi()
        ..error = apiError(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.');
      final storage = FakeTokenStorage();
      final auth = AuthViewModel(api, FakeMemberApi(), storage);
      await auth.login('a@b.com', 'wrong');
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.message, equals('이메일 또는 비밀번호를 확인해 주세요.'));
      expect(auth.sessionExpired, isFalse);
      expect(storage.token, isNull);
    });

    test('로그인 네트워크 실패: 다른 문구, 만료 아님', () async {
      final api = FakeAuthApi()..error = networkError();
      final auth = AuthViewModel(api, FakeMemberApi(), FakeTokenStorage());
      await auth.login('a@b.com', 'Abcdef1!');
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.message, contains('로그인 요청에 실패'));
      expect(auth.sessionExpired, isFalse);
    });

    test('loadMember 네트워크 실패: 로그아웃하지 않고 error, 재시도 가능', () async {
      final memberApi = FakeMemberApi();
      final auth = await signedInAuth(memberApi: memberApi);
      memberApi.fetchError = networkError();
      await auth.loadMember();
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(auth.memberStatus, equals(MemberLoadStatus.error));

      memberApi.fetchError = null;
      await auth.loadMember(force: true);
      expect(auth.memberStatus, equals(MemberLoadStatus.success));
    });

    test('loadMember 401 → 세션 정리', () async {
      final storage = FakeTokenStorage();
      final memberApi = FakeMemberApi();
      final auth = await signedInAuth(storage: storage, memberApi: memberApi);
      memberApi.fetchError = apiError(401, 'AUTH401_4', '만료');
      await auth.loadMember();
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('직접 로그아웃: 토큰·member 삭제, 만료 표시는 켜지 않는다', () async {
      final storage = FakeTokenStorage();
      final auth = await signedInAuth(storage: storage);
      await auth.loadMember();
      await auth.logout();
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.member, isNull);
      expect(storage.token, isNull);
      expect(auth.sessionExpired, isFalse);
    });

    test('동시 401: expireSession을 여러 번 불러도 정리는 한 번', () async {
      final storage = FakeTokenStorage();
      final auth = await signedInAuth(storage: storage);
      await Future.wait([
        auth.expireSession(),
        auth.expireSession(),
        auth.expireSession(),
      ]);
      expect(storage.deleteCalls, equals(1));
    });

    test('이전 세션의 늦은 401은 새 로그인 세션을 지우지 않는다', () async {
      final storage = FakeTokenStorage();
      final auth = await signedInAuth(storage: storage);
      final oldVersion = auth.sessionVersion;
      await auth.logout();
      await auth.login('a@b.com', 'Abcdef1!'); // 새 세션
      expect(auth.status, equals(AuthStatus.signedIn));

      await auth.expireSession(requestVersion: oldVersion); // 이전 요청의 늦은 401
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(storage.token, equals('jwt-1'));
    });

    test('토큰 삭제 실패: signedOut은 유지하고 안내 문구를 남긴다', () async {
      final storage = FakeTokenStorage()..deleteError = StateError('keystore');
      final auth = await signedInAuth(storage: storage);
      await auth.logout();
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.message, contains('지우지 못했어요'));
    });

    test('consumeSessionExpired: 한 번 소비하면 꺼진다', () async {
      final auth = await signedInAuth();
      await auth.expireSession();
      expect(auth.sessionExpired, isTrue);
      auth.consumeSessionExpired();
      expect(auth.sessionExpired, isFalse);
    });
  });

  group('EditProfileViewModel', () {
    Future<(EditProfileViewModel, FakeMemberApi, AuthViewModel)> build() async {
      final memberApi = FakeMemberApi();
      final auth = await signedInAuth(memberApi: memberApi);
      await auth.loadMember();
      return (EditProfileViewModel(memberApi, auth), memberApi, auth);
    }

    test('2~12자 검증은 요청 전에 걸러낸다', () async {
      final (vm, api, _) = await build();
      expect(await vm.save('a'), isFalse);
      expect(vm.nicknameError, isNotNull);
      expect(await vm.save('a' * 13), isFalse);
      expect(api.updateCalls, equals(0));
    });

    test('현재 닉네임과 같으면 요청 없이 성공', () async {
      final (vm, api, _) = await build();
      expect(await vm.save(' 무비 '), isTrue);
      expect(api.updateCalls, equals(0));
    });

    test('성공: member를 응답으로 교체한다', () async {
      final (vm, api, auth) = await build();
      expect(await vm.save('새닉네임'), isTrue);
      expect(auth.member?.nickname, equals('새닉네임'));
      expect(api.fetchCalls, equals(1)); // GET me를 다시 부르지 않는다
    });

    test('MEMBER409_1: 필드 오류, 로그아웃 없음', () async {
      final (vm, api, auth) = await build();
      api.updateError = apiError(409, 'MEMBER409_1', '중복');
      expect(await vm.save('다른사람'), isFalse);
      expect(vm.nicknameError, equals('이미 사용 중인 닉네임이에요.'));
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(auth.member?.nickname, equals('무비'));
    });

    test('COMMON400: 서버 message를 필드 아래에 보여준다', () async {
      final (vm, api, _) = await build();
      api.updateError = apiError(400, 'COMMON400', '닉네임은 2자 이상이어야 합니다.');
      await vm.save('ab');
      expect(vm.nicknameError, equals('닉네임은 2자 이상이어야 합니다.'));
    });

    test('네트워크 실패: Snackbar 문구, 로그아웃 없음, 재시도 가능', () async {
      final (vm, api, auth) = await build();
      api.updateError = networkError();
      expect(await vm.save('새닉네임'), isFalse);
      expect(vm.message, contains('네트워크'));
      expect(auth.status, equals(AuthStatus.signedIn));

      api.updateError = null;
      expect(await vm.save('새닉네임'), isTrue);
    });

    test('AUTH401_3: 세션 정리 (false 반환 → 화면은 pop하지 않는다)', () async {
      final (vm, api, auth) = await build();
      api.updateError = apiError(401, 'AUTH401_3', '무효');
      expect(await vm.save('새닉네임'), isFalse);
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.sessionExpired, isTrue);
    });
  });

  group('MovieDetailViewModel.createRating', () {
    Future<(MovieDetailViewModel, FakeRatingService, SessionRatingsStore,
        AuthViewModel)> build() async {
      final auth = await signedInAuth();
      final store = SessionRatingsStore(auth);
      final service = FakeRatingService();
      return (MovieDetailViewModel(service, auth, store, movie), service, store, auth);
    }

    test('로그인 상태가 아니면 요청하지 않는다', () async {
      final auth = AuthViewModel(FakeAuthApi(), FakeMemberApi(), FakeTokenStorage());
      final service = FakeRatingService();
      final vm = MovieDetailViewModel(service, auth, SessionRatingsStore(auth), movie);
      await vm.createRating(score: 4);
      expect(vm.submitStatus, equals(SubmitStatus.error));
      expect(service.log, isEmpty);
    });

    test('성공: movieId는 TmdbMovieDto.id, 응답 Rating을 store에 보관', () async {
      final (vm, service, store, _) = await build();
      await vm.createRating(score: 5, comment: '굿');
      expect(vm.submitStatus, equals(SubmitStatus.success));
      expect(service.log, equals(['POST movieId=550 score=5']));
      expect(store.ratings.single.movieId, equals(550));
      expect(store.ratings.single.comment, equals('굿'));
    });

    test('RATING409_1: 안내만 하고 로그아웃하지 않는다', () async {
      final (vm, service, store, auth) = await build();
      service.createError = apiError(409, 'RATING409_1', '이미 평점을 남겼습니다.');
      await vm.createRating(score: 4);
      expect(vm.submitStatus, equals(SubmitStatus.error));
      expect(vm.submitMessage, contains('이미'));
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(store.ratings, isEmpty);
    });

    test('RATING403_1: 서버 message를 보여주고 로그아웃하지 않는다', () async {
      final (vm, service, _, auth) = await build();
      service.createError = apiError(403, 'RATING403_1', '본인이 작성한 평점이 아닙니다.');
      await vm.createRating(score: 4);
      expect(vm.submitMessage, equals('본인이 작성한 평점이 아닙니다.'));
      expect(auth.status, equals(AuthStatus.signedIn));
    });

    test('AUTH401_2/3/4: 세션 정리', () async {
      final (vm, service, _, auth) = await build();
      service.createError = apiError(401, 'AUTH401_4', '만료');
      await vm.createRating(score: 4);
      expect(vm.submitMessage, equals(sessionExpiredMessage));
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.sessionExpired, isTrue);
    });

    test('예상 밖 응답(StateError)에도 제출 중 상태가 남지 않는다', () async {
      final (vm, service, _, _) = await build();
      service.createError = StateError('result 없음');
      await vm.createRating(score: 4);
      expect(vm.submitStatus, equals(SubmitStatus.error));
      expect(vm.submitMessage, contains('확인'));
    });

    test('로그아웃 뒤 늦게 도착한 응답은 store에 반영하지 않는다', () async {
      final (vm, _, store, auth) = await build();
      final future = vm.createRating(score: 4);
      await auth.logout(); // 응답 도착 전 로그아웃
      await future;
      expect(store.ratings, isEmpty);
      expect(vm.submitStatus, equals(SubmitStatus.error));
    });
  });

  group('SessionRatingsStore', () {
    test('로그아웃하면 비워지고, 회원 전환 뒤에도 이전 평점이 보이지 않는다', () async {
      final auth = await signedInAuth();
      final store = SessionRatingsStore(auth);
      final service = FakeRatingService();
      await MovieDetailViewModel(service, auth, store, movie).createRating(score: 3);
      expect(store.ratings, hasLength(1));

      await auth.logout();
      expect(store.ratings, isEmpty);
      await auth.login('b@b.com', 'Abcdef1!');
      expect(store.ratings, isEmpty);
    });
  });

  group('MyRatingsViewModel', () {
    Future<(MyRatingsViewModel, FakeRatingService, SessionRatingsStore,
        AuthViewModel)> build({int seed = 0}) async {
      final auth = await signedInAuth();
      final store = SessionRatingsStore(auth);
      final service = FakeRatingService();
      for (var i = 0; i < seed; i++) {
        final created = await service.createRating(
          CreateRatingRequest(movieId: 100 + i, score: 3, comment: '기존$i'),
        );
        store.add(created, sessionVersion: auth.sessionVersion);
      }
      service.log.clear();
      final vm = MyRatingsViewModel(service, FakeTmdbService(), store, auth);
      return (vm, service, store, auth);
    }

    test('load: 세션에 등록한 평점이 없으면 empty (서버 GET 없음)', () async {
      final (vm, service, _, _) = await build();
      await vm.load();
      expect(vm.status, equals(MyRatingsLoadStatus.empty));
      expect(service.log, isEmpty);
    });

    test('TMDB에 없는 영화는 평점을 지우지 않고 placeholder 제목', () async {
      final (vm, _, _, _) = await build(seed: 1);
      await vm.load();
      expect(vm.status, equals(MyRatingsLoadStatus.success));
      expect(vm.ratings.single.movie, isNull);
      expect(
        movieTitleOrPlaceholder(vm.ratings.single.rating, null),
        equals('영화 #100'),
      );
    });

    test('수정 성공: PATCH 응답 Rating으로 목록 갱신 (재조회 GET 없음)', () async {
      final (vm, service, _, _) = await build(seed: 1);
      await vm.load();
      await vm.updateRating(ratingId: 1, score: 5, comment: null);
      expect(service.log, equals(['PATCH 1 score=5 comment=null']));
      expect(vm.ratings.single.rating.score, equals(5));
      expect(vm.ratings.single.rating.comment, isNull);
    });

    test('수정 RATING403_1: 예외를 다시 던지고 로그아웃하지 않는다', () async {
      final (vm, service, _, auth) = await build(seed: 1);
      await vm.load();
      service.updateError = apiError(403, 'RATING403_1', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 4),
        throwsA(isA<DioException>()),
      );
      expect(auth.status, equals(AuthStatus.signedIn));
      expect(
        describeWriteError(service.updateError!),
        equals('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'),
      );
      expect(vm.ratings, hasLength(1)); // 목록 유지
    });

    test('수정 RATING404_1: 서버에 없는 평점은 목록에서 제거', () async {
      final (vm, service, store, auth) = await build(seed: 2);
      await vm.load();
      service.updateError = apiError(404, 'RATING404_1', '평점 없음');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 4),
        throwsA(isA<DioException>()),
      );
      expect(store.ratings.map((r) => r.ratingId), equals([2]));
      expect(auth.status, equals(AuthStatus.signedIn));
    });

    test('수정 COMMON400: 재조회·로그아웃 없이 예외만', () async {
      final (vm, service, _, auth) = await build(seed: 1);
      await vm.load();
      service.updateError = apiError(400, 'COMMON400', '별점은 5점 이하여야 합니다.');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 4),
        throwsA(isA<DioException>()),
      );
      expect(auth.status, equals(AuthStatus.signedIn));
    });

    test('수정 AUTH401_3: 세션 정리 + Dialog용 만료 문구', () async {
      final (vm, service, store, auth) = await build(seed: 1);
      await vm.load();
      service.updateError = apiError(401, 'AUTH401_3', '무효');
      await expectLater(
        vm.updateRating(ratingId: 1, score: 4),
        throwsA(isA<DioException>()),
      );
      expect(auth.status, equals(AuthStatus.signedOut));
      expect(auth.sessionExpired, isTrue);
      expect(store.ratings, isEmpty);
      expect(describeWriteError(service.updateError!), equals(sessionExpiredMessage));
    });

    test('삭제 성공(200): 목록에서 사라지고 마지막이면 empty', () async {
      final (vm, service, _, _) = await build(seed: 1);
      await vm.load();
      await vm.deleteRating(1);
      expect(service.log, equals(['DELETE 1']));
      expect(vm.status, equals(MyRatingsLoadStatus.empty));
    });

    test('삭제 실패(500): 예외를 던지고 목록은 그대로', () async {
      final (vm, service, _, _) = await build(seed: 1);
      await vm.load();
      service.deleteFailures.add(1);
      await expectLater(vm.deleteRating(1), throwsA(isA<DioException>()));
      expect(vm.ratings, hasLength(1));
    });

    test('다중 삭제: 일부 실패하면 성공한 항목만 사라지고 실패 항목은 선택 유지', () async {
      final (vm, service, _, _) = await build(seed: 3);
      service.deleteFailures.add(2);
      await vm.load();
      vm.enterSelectionMode();
      vm.toggleSelection(1);
      vm.toggleSelection(2);
      vm.toggleSelection(3);

      final failed = await vm.deleteSelectedRatings();
      expect(failed, equals(1));
      expect(vm.isDeletingSelected, isFalse);
      expect(vm.selectedRatingIds, equals({2}));
      expect(vm.isSelectionMode, isTrue);
      expect(vm.ratings.map((e) => e.rating.ratingId), equals([2]));
    });

    test('다중 삭제: 전부 성공하면 선택 모드 종료', () async {
      final (vm, _, _, _) = await build(seed: 2);
      await vm.load();
      vm.enterSelectionMode();
      vm.toggleSelection(1);
      vm.toggleSelection(2);
      expect(await vm.deleteSelectedRatings(), equals(0));
      expect(vm.isSelectionMode, isFalse);
      expect(vm.status, equals(MyRatingsLoadStatus.empty));
    });

    test('다중 삭제 중 401: 남은 항목은 시도하지 않고 세션 정리', () async {
      final (vm, service, _, auth) = await build(seed: 3);
      service.deleteError = apiError(401, 'AUTH401_4', '만료');
      await vm.load();
      vm.enterSelectionMode();
      vm.toggleSelection(1);
      vm.toggleSelection(2);
      vm.toggleSelection(3);
      expect(await vm.deleteSelectedRatings(), equals(3));
      expect(service.log, equals(['DELETE 1'])); // 첫 401 뒤 중단
      expect(auth.status, equals(AuthStatus.signedOut));
    });

    test('dispose 뒤에 도착한 결과는 notify하지 않는다', () async {
      final (vm, _, _, _) = await build(seed: 1);
      final future = vm.load();
      vm.dispose();
      await future; // 예외가 없어야 한다
    });
  });
}
