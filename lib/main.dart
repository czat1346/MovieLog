import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/session/auth_session_bridge.dart';
import 'core/session/session_guard.dart';
import 'data/services/favorite_api_service.dart';

import 'core/network/movie_log_client.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/token_storage.dart';
import 'data/services/auth_api_service.dart';
import 'data/services/member_api_service.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/sign_up_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/session_ratings_store.dart';

// 토큰은 secure storage(Keychain/Keystore)에만 둡니다.
final TokenStorage _tokenStorage = SecureTokenStorage(
  const FlutterSecureStorage(),
);

// MovieLog Client는 둘로 나눕니다.
// - 공개 Client: 로그인·회원가입·중복 확인·유저별 평점 조회 (Interceptor 없음)
// - 보호 Client: 내 정보·평점 등록/수정/삭제 (AuthInterceptor가 Bearer JWT를 붙임)
// TMDB Client(TMDB Read Access Token)와는 계속 합치지 않아 두 Authorization이 섞이지 않습니다.
final _publicClient = createMovieLogClient();
final _authClient = createAuthMovieLogClient(_tokenStorage);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // 금고 열기 (앱 시작 전에!)
  runApp(const MovieLogApp());
}

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: _tokenStorage),
        Provider<TmdbMovieService>(
          create: (_) => TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client
        Provider<AuthApiService>(create: (_) => AuthApiService(_publicClient)),
        Provider<SignUpService>(create: (_) => SignUpService(_publicClient)),
        // 보호 Client (RatingApiService는 공개 조회용 publicClient도 함께 받음)
        Provider<MemberApiService>(
          create: (_) => MemberApiService(_authClient),
        ),
        Provider<RatingApiService>(
          create: (_) => RatingApiService(_publicClient, _authClient),
        ),
        Provider<FavoriteApiService>(
          create: (_) => FavoriteApiService(_authClient),
        ),
        // Service를 주입받는 ViewModel
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 이번 로그인 세션에서 등록한 평점. 로그아웃·만료·회원 전환 시 비워집니다.
        ChangeNotifierProvider<SessionRatingsStore>(
          create: (context) => SessionRatingsStore(context.read<AuthViewModel>()),
        ),
                // 현재 로그인 세션을 판정합니다. (AuthViewModel 상태를 SessionGuard에 전달)
        Provider<AuthSessionBridge>(
          create: (context) {
            final auth = context.read<AuthViewModel>();
            return AuthSessionBridge(
              authSignals: auth,
              sessionVersion: () => auth.sessionVersion,
              verifiedEmail: () =>
                  auth.status == AuthStatus.signedIn ? auth.member?.email : null,
            );
          },
          dispose: (_, bridge) => bridge.dispose(),
        ),
        Provider<SessionGuard>(
          create: (context) => context.read<AuthSessionBridge>().guard,
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel); // 앱 수명 동안 한 번만 생성
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession(); // 첫 build 이후 세션 복원 시작
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
