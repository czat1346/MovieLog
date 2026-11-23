import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'view_models/load_phase.dart';
import 'view_models/paged_movies_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/movie_page_footer.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '영화 검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/movies/search'),
          ),
        ],
      ),
      body: Consumer<PagedMoviesViewModel>(
        builder: (context, vm, child) {
          final isLoading =
              vm.phase == LoadPhase.idle || vm.phase == LoadPhase.loading;

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: vm.genres.length + 1, // +1 = "전체" 칩
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    // 0번 = 전체 (with_genres를 보내지 않음)
                    final int? genreId = index == 0 ? null : vm.genres[index - 1].id;
                    final label = index == 0 ? '전체' : vm.genres[index - 1].name;
                    final selected = vm.selectedGenreId == genreId;

                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      // 로딩 중에는 null → 칩이 눌리지 않습니다.
                      onSelected: isLoading
                          ? null
                          : (_) => context
                              .read<PagedMoviesViewModel>()
                              .loadInitial(
                                // 이미 선택된 장르를 다시 누르면 해제 = 전체
                                genreId: (selected || genreId == null)
                                    ? null
                                    : genreId,
                              ),
                    );
                  },
                ),
              ),
              Expanded(
                child: switch (vm.phase) {
                  LoadPhase.idle ||
                  LoadPhase.loading =>
                    const MovieListLoading(),
                  LoadPhase.error => MovieListError(
                      message: vm.errorMessage ?? '영화를 불러오지 못했습니다.',
                      onRetry: () {
                        vm.loadGenres(); // 장르 목록도 비어 있으면 다시 시도
                        vm.loadInitial(genreId: vm.selectedGenreId);
                      },
                    ),
                  LoadPhase.empty => const MovieListEmpty(),
                  LoadPhase.ready => MovieGrid(
                      movies: vm.movies,
                      footer: MoviePageFooter(vm: vm),
                    ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}