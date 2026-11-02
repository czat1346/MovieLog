import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import 'data/models/rating_with_movie.dart';
import 'theme/app_colors.dart';
import 'view_models/my_ratings_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/tmdb_poster_image.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // bottomNavigationBar를 주지 않고, 뒤로가기는 AppBar가 자동으로 만든다
    return Scaffold(
      appBar: const CommonAppBar(title: '내가 등록한 평점', centerTitle: true),
      body: Consumer<MyRatingsViewModel>(
        builder: (context, vm, child) => switch (vm.status) {
          MyRatingsLoadStatus.idle ||
          MyRatingsLoadStatus.loading =>
            const MovieListLoading(),
          MyRatingsLoadStatus.empty =>
            const MovieListEmpty(message: '등록한 평점이 없습니다.'),
          MyRatingsLoadStatus.error => MovieListError(
              message: vm.message ?? '평점을 불러오지 못했습니다.',
              onRetry: vm.load,
            ),
          MyRatingsLoadStatus.success =>
            _RatingsList(ratings: vm.ratings, notice: vm.message),
        },
      ),
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.ratings, this.notice});

  final List<RatingWithMovie> ratings;
  final String? notice; // 일부 영화 정보 누락 안내

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(notice!, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final entry in ratings) _RatingCard(entry: entry),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.entry});

  final RatingWithMovie entry;

  String _date(DateTime d) {
    final local = d.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$m.$day';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rating = entry.rating;
    final movie = entry.movie; // null이면 포스터는 placeholder, 제목은 대체 문구
    final comment = rating.comment;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: 64,
              height: 92,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie?.title ?? '영화 정보 없음 (ID ${rating.movieId})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                RatingBarIndicator(
                  rating: rating.score.toDouble(),
                  itemCount: 5,
                  itemSize: 18,
                  itemBuilder: (context, index) =>
                      const Icon(Icons.star, color: AppColors.primary),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(comment, style: textTheme.bodyMedium),
                ],
                const SizedBox(height: 6),
                Text(_date(rating.createdAt), style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
