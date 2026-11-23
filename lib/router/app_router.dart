import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../edit_profile_screen.dart';
import '../favorites_screen.dart';
import '../home_screen.dart';
import '../login_screen.dart';
import '../main_screen.dart';
import '../movie_detail_loader.dart';
import '../movie_list_screen.dart';
import '../movie_search_screen.dart';
import '../my_page_screen.dart';
import '../my_ratings_screen.dart';
import '../signup.dart';
import '../start_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
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
                  ChangeNotifierProvider<PagedMoviesViewModel>(
                    create: (context) => PagedMoviesViewModel(
                      tmdbApi: context.read<TmdbMovieService>(),
                    )
                      ..loadGenres()
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
                  path: 'favorites',
                  parentNavigatorKey: rootNavigatorKey, // 하단 NavigationBar를 가립니다
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    final member = auth.member;
                    final guard = context.read<SessionGuard>();

                    if (member == null) {
                      return Scaffold(
                        appBar: AppBar(
                          centerTitle: true,
                          title: const Text('내 즐겨찾기'),
                        ),
                        body: Center(
                          child: auth.memberStatus == MemberLoadStatus.error
                              ? MovieLogButton(
                                  label: '내 정보 다시 조회',
                                  onPressed: () => auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (guard.accountId != member.email) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return ChangeNotifierProvider<FavoritesViewModel>(
                      // 계정이나 세션이 바뀌면 이전 사용자의 ViewModel을 버리고 새로 만듭니다.
                      key: ValueKey('${member.email}:${guard.generation}'),
                      create: (_) => FavoritesViewModel(
                        favoriteApi: context.read<FavoriteApiService>(),
                        tmdbApi: context.read<TmdbMovieService>(),
                        sessionGuard: guard,
                        accountId: member.email,
                        auth: auth,
                      ),
                      child: FavoritesScreen(
                        onOpenMovie: (movie) async {
                          await context.push('/movies/${movie.id}', extra: movie);
                        },
                      ),
                    );
                  },
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
        // ⚠️ 정적인 /movies/search 는 반드시 동적인 /movies/:movieId 보다 위에 둡니다.
        // 순서가 바뀌면 'search'가 영화 ID로 해석됩니다.
        // 최상위 Route이므로 하단 NavigationBar가 보이지 않습니다.
        GoRoute(
          path: '/movies/search',
          builder: (context, state) =>
              ChangeNotifierProvider<PagedMoviesViewModel>(
                // 영화 목록과 별도의 ViewModel 인스턴스를 사용합니다.
                create: (_) => PagedMoviesViewModel(
                  tmdbApi: context.read<TmdbMovieService>(),
                ),
                child: MovieSearchScreen(
                  onOpenMovie: (movie) async {
                    await context.push('/movies/${movie.id}', extra: movie);
                  },
                ),
              ),
        ),
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) {
            // movieId는 URL 식별자(= TmdbMovieDto.id)로만 쓰고,
            // 목록에서 넘긴 TmdbMovieDto는 state.extra로 받습니다.
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return const Scaffold(
                body: Center(child: Text('영화 ID가 올바르지 않습니다.')),
              );
            }

            final auth = context.watch<AuthViewModel>();
            final member = auth.member;
            final guard = context.read<SessionGuard>();

            // 내 정보가 아직 없으면 로딩(또는 실패 시 재시도)을 보여 줍니다.
            if (member == null) {
              return Scaffold(
                appBar: AppBar(centerTitle: true, title: const Text('영화 상세')),
                body: Center(
                  child: auth.memberStatus == MemberLoadStatus.error
                      ? MovieLogButton(
                          label: '내 정보 다시 조회',
                          onPressed: () => auth.loadMember(force: true),
                        )
                      : const CircularProgressIndicator(),
                ),
              );
            }
            // 현재 세션과 일치할 때까지 잠깐 로딩
            if (guard.accountId != member.email) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final extra = state.extra;
            return ChangeNotifierProvider<FavoriteDetailViewModel>(
              // 계정이나 세션이 바뀌면 새 ViewModel을 만듭니다.
              key: ValueKey('${member.email}:${guard.generation}'),
              create: (_) => FavoriteDetailViewModel(
                movieId: id,
                favoriteApi: context.read<FavoriteApiService>(),
                sessionGuard: guard,
                accountId: member.email,
                auth: auth,
              ),
              child: MovieDetailLoader(
                movieId: id,
                initialMovie: extra is TmdbMovieDto && extra.id == id
                    ? extra
                    : null,
              ),
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
