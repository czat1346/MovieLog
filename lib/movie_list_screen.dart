import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'view_models/movie_list_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '영화'),
      body: Consumer<MovieListViewModel>(
        builder: (context, vm, child) {
          final isLoading = vm.status == MovieListLoadStatus.idle ||
              vm.status == MovieListLoadStatus.loading;

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
                      // 로딩 중에는 null → 칩이 눌리지 않는다 (필수 미션 7번)
                      onSelected: isLoading
                          ? null
                          : (_) => context
                              .read<MovieListViewModel>()
                              .selectGenre(
                                // 이미 선택된 장르를 다시 누르면 해제 = 전체
                                (selected || genreId == null) ? null : genreId,
                              ),
                    );
                  },
                ),
              ),
              Expanded(
                child: switch (vm.status) {
                  MovieListLoadStatus.idle ||
                  MovieListLoadStatus.loading =>
                    const MovieListLoading(),
                  MovieListLoadStatus.error => MovieListError(
                      onRetry: () => vm.genres.isEmpty
                          ? context.read<MovieListViewModel>().loadInitial()
                          : context
                              .read<MovieListViewModel>()
                              .selectGenre(vm.selectedGenreId),
                    ),
                  MovieListLoadStatus.empty => const MovieListEmpty(),
                  MovieListLoadStatus.success => MovieGrid(movies: vm.movies),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}