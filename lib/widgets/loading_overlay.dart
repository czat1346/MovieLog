import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 진행 중에는 child 위에 어두운 ModalBarrier와 중앙 흰색 인디케이터만 올립니다.
/// (카드·문구 없음) 터치를 막아 요청이 끝나기 전 조작을 차단합니다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isLoading)
          const ModalBarrier(dismissible: false, color: Colors.black45),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          ),
      ],
    );
  }
}
