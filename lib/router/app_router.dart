import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../edit_profile_screen.dart';
import '../home_screen.dart';
import '../login_screen.dart';
import '../main_screen.dart';
import '../movie_detail_loader.dart';
import '../movie_list_screen.dart';
import '../my_page_screen.dart';
import '../my_ratings_screen.dart';
import '../signup.dart';
import '../start_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_ratings_store.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

/// 인증 상태별 화면 이동 규칙. 상태만 읽고 판단하며 API 호출 같은 비동기 작업은 하지 않습니다.
///
/// - initializing / retryRequired: 스플래시(/start) 유지 (저장소 확인 전 login·home 노출 금지)
/// - signedOut / authenticating: 공개 화면(/login, /register)만 허용
/// - signedIn: 스플래시와 로그인·회원가입은 /home으로
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// GoRouter는 앱이 살아 있는 동안 한 번만 만들어야 합니다(_MovieLogRouterApp.initState).
  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // 인증 상태가 바뀌면 redirect를 다시 실행합니다. (로그인·로그아웃·만료 모두 이 한 곳)
      refreshListenable: authViewModel,
      redirect: (context, state) =>
          authRedirect(authViewModel.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
            child: const SignupScreen(),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => MainScreen(
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieHomeViewModel>(
                    create: (context) =>
                        MovieHomeViewModel(context.read<TmdbMovieService>())
                          ..loadPopular(),
                    child: const HomeScreen(),
                  ),
            ),
            GoRoute(
              path: '/movies',
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieListViewModel>(
                    create: (context) =>
                        MovieListViewModel(context.read<TmdbMovieService>())
                          ..loadInitial(),
                    child: const MovieListScreen(),
                  ),
            ),
            GoRoute(
              path: '/my',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'ratings',
                  parentNavigatorKey: rootNavigatorKey, // 하단 NavigationBar를 가림
                  builder: (context, state) =>
                      ChangeNotifierProvider<MyRatingsViewModel>(
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          context.read<SessionRatingsStore>(),
                          context.read<AuthViewModel>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'profile/edit',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    if (auth.member == null) {
                      return Scaffold(
                        appBar: AppBar(
                          centerTitle: true,
                          title: const Text('프로필 수정'),
                        ),
                        body: Center(
                          child: auth.memberStatus == MemberLoadStatus.error
                              ? MovieLogButton(
                                  label: '다시 시도',
                                  onPressed: () =>
                                      auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        auth,
                      ),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) {
            // movieId는 URL 식별자(= TmdbMovieDto.id)로만 쓰고,
            // 목록에서 넘긴 TmdbMovieDto는 state.extra로 받습니다. (직접 접근 땐 없을 수 있음)
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return const Scaffold(
                body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
              );
            }
            final extra = state.extra;
            return MovieDetailLoader(
              movieId: id,
              initialMovie: extra is TmdbMovieDto && extra.id == id
                  ? extra
                  : null,
            );
          },
        ),
      ],
    );
  }

  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
