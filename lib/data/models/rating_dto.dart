/// 평점 응답 모델. v7 등록/수정의 result(Rating 객체)와 공개 목록 조회 항목에 공통으로 씁니다.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  final int ratingId;
  final int movieId;
  final int score;
  final String? comment; // nullable: 값이 없을 수 있다
  final DateTime createdAt;

  factory RatingDto.fromJson(Map<String, dynamic> json) => RatingDto(
        ratingId: (json['ratingId'] as num).toInt(),
        movieId: (json['movieId'] as num).toInt(),
        score: (json['score'] as num).toInt(),
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
