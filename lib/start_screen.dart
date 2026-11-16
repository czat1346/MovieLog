import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'widgets/movielog_button.dart';

/// 앱 시작 화면(1주차 StartScreen 레이아웃 재사용) = 세션 확인 스플래시.
///
/// - [onRetry]가 null이면 세션 확인 중(initializing): 인디케이터
/// - [onRetry]가 있으면 세션 확인 실패(retryRequired): 안내 문구 + 다시 시도 버튼
/// 저장소를 확인하기 전에 login/home을 보여주지 않기 위해 두 상태 모두 이 화면을 씁니다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 32),
                  const Text('FLUTTER 8주차'),
                  const SizedBox(height: 64),
                  SvgPicture.asset(
                    'assets/logos/movielog_logo.svg',
                    width: 84,
                    height: 84,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '영화의 순간을\n기록하세요',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
              // 1주차 '시작하기' 버튼 자리를 로딩/재시도 상태로 대체합니다.
              if (onRetry == null)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    Text(message ?? '로그인 상태를 확인하지 못했어요.'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: MovieLogButton(
                        label: '다시 시도',
                        width: double.infinity,
                        onPressed: onRetry,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
