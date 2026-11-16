import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

/// 7주차 서버 연동용 별점 입력: 1~5 **정수**만 선택합니다. (v6 score는 정수)
///
/// 값은 RatingBar가 항상 double로 돌려주므로 1.0, 2.0처럼 정수를 나타내는 double입니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final bool enabled; // false면 저장 중 별점 변경을 막습니다.

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: AppColors.primary),
      onRatingUpdate: onChanged,
    );
  }
}
