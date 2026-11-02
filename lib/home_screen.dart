import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/models/tmdb_movie_dto.dart';
import 'theme/app_colors.dart';
import 'view_models/movie_home_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_card.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/tmdb_poster_image.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'MovieLog'),
      body: SafeArea(
        // Consumer: 상태가 바뀔 때 이 부분만 다시 그린다
        child: Consumer<MovieHomeViewModel>(
          builder: (context, vm, child) {
            return switch (vm.status) {
              MovieHomeLoadStatus.idle ||
              MovieHomeLoadStatus.loading =>
                const MovieListLoading(),
              MovieHomeLoadStatus.error => MovieListError(
                  onRetry: () => context.read<MovieHomeViewModel>().loadPopular(),
                ),
              MovieHomeLoadStatus.empty => const MovieListEmpty(),
              MovieHomeLoadStatus.success =>
                _HomeContent(movies: vm.popularMovies),
            };
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.movies});

  final List<TmdbMovieDto> movies; // 최대 5개

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘은 어떤\n영화를 볼까요?', style: textTheme.titleLarge),
          const SizedBox(height: 20),
          _FeaturedMovieCard(movie: movies.first), // 비어 있으면 Empty 화면이라 안전
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('인기 영화', style: textTheme.titleMedium),
              GestureDetector(
                onTap: () => context.go('/movies'),
                child: Text(
                  '전체보기 >',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 140,
                child: MovieCard(movie: movies[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedMovieCard extends StatelessWidget {
  const _FeaturedMovieCard({required this.movie});

  final TmdbMovieDto movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = movie.releaseDate;
    final year = (date != null && date.length >= 4) ? date.substring(0, 4) : null;
    final info = [
      if (year != null) year,
      '평점 ${movie.voteAverage.toStringAsFixed(1)}',
    ].join(' · ');

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => TmdbPosterImage(
                posterPath: movie.posterPath,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0xE6000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info,
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/movies/${movie.id}'),
                      icon: const Icon(Icons.info),
                      label: const Text('상세보기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}