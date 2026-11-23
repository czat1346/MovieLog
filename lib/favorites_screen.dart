import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models/tmdb_movie_dto.dart';
import 'view_models/favorites_view_model.dart';
import 'view_models/load_phase.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/movielog_button.dart';
import 'widgets/tmdb_poster_image.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // build()가 아니라 화면이 처음 만들어질 때 한 번만 조회합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 즐겨찾기', centerTitle: true),
      body: Consumer<FavoritesViewModel>(
        builder: (context, vm, _) {
          if (vm.phase == LoadPhase.idle || vm.phase == LoadPhase.loading) {
            return const MovieListLoading();
          }
          if (vm.phase == LoadPhase.empty) {
            return const MovieListEmpty(message: '아직 즐겨찾기한 영화가 없습니다.');
          }
          if (vm.phase == LoadPhase.error) {
            return MovieListError(
              message: vm.errorMessage ?? '조회 오류입니다.',
              onRetry: vm.refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: vm.refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: vm.items.length,
              itemBuilder: (context, index) {
                final item = vm.items[index];
                final movie = item.movie;

                // 영화 정보 한 건 실패: placeholder + 재조회 버튼 (다른 카드는 그대로)
                if (movie == null) {
                  final movieId = item.favorite.movieId;
                  return ListTile(
                    leading: const Icon(Icons.broken_image_outlined),
                    title: Text('영화 #$movieId'),
                    subtitle: Text(item.errorMessage ?? '정보가 없습니다.'),
                    trailing: MovieLogButton(
                      width: 110,
                      label: '정보 재조회',
                      onPressed: () => vm.retryMovie(movieId),
                    ),
                  );
                }

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TmdbPosterImage(
                      posterPath: movie.posterPath,
                      width: 48,
                      height: 72,
                    ),
                  ),
                  title: Text(movie.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await widget.onOpenMovie(movie); // 상세에서 뒤로가기할 때까지 기다립니다.
                    if (!mounted) return;
                    await vm.refresh(); // 상세에서 해제했을 수 있으니 목록을 다시 조회합니다.
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}