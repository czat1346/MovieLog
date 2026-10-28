import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/tmdb_movie_dto.dart';
import 'tmdb_poster_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie});

  final TmdbMovieDto movie;

  // "2024-05-01" → "2024" (날짜가 없으면 null)
  String? get _year {
    final date = movie.releaseDate;
    if (date == null || date.length < 4) return null;
    return date.substring(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final year = _year;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // TMDB의 id를 그대로 넘긴다 (index 아님!) ← 제출양식 'movie.id 전달 위치'
      onTap: () => context.push('/movies/${movie.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) => TmdbPosterImage(
                  posterPath: movie.posterPath,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (year != null) Text(year, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
