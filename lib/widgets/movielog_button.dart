import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.secondary = false, // true: 흰 배경 + 보라 테두리 (취소 등 보조 동작)
    this.width, // null: 내용 크기 / double.infinity: 최대 너비 / 숫자: 고정
  });

  final String label;
  final VoidCallback? onPressed; // null이면 비활성
  final bool isLoading;
  final bool secondary;
  final double? width;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: secondary
            ? ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.gray,
                side: BorderSide(
                  color: _disabled ? AppColors.gray : AppColors.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.gray,
                foregroundColor: AppColors.white,
                disabledForegroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
