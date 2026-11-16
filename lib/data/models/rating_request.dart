/// 평점 score는 1~5 정수입니다. 위젯이 정수 단위로 막아 준 뒤에도 남겨 두는 안전장치입니다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// 평점 등록 요청 body. (POST /v7/ratings) — memberId는 body·query 어디에도 넣지 않습니다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  }) : assert(score >= 1 && score <= 5, 'score는 1~5 정수여야 합니다.');

  /// 5주차 `TmdbMovieDto.id`. 영화 배열의 index나 임의 번호가 아닙니다.
  final int movieId;
  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    // 등록 comment는 선택 항목이라 빈 문자열 대신 키 자체를 생략합니다.
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}
