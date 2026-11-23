import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models/tmdb_movie_dto.dart';
import 'view_models/load_phase.dart';
import 'view_models/paged_movies_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/movie_page_footer.dart';
import 'widgets/tmdb_poster_image.dart';

class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();

  String _submittedQuery = '';
  String? _inputError;

  void _submitSearch(String value) {
    final query = value.trim();

    // 빈 검색어는 서버(TMDB)에 보내지 않고 입력 안내만 보여 줍니다.
    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력합니다.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _inputError = null;
      _submittedQuery = query;
    });

    // 새 검색은 항상 page 1부터 시작합니다. (이전 결과·generation 초기화는 ViewModel이 합니다)
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '영화 검색', centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submitSearch,
                    decoration: InputDecoration(
                      labelText: '검색어',
                      errorText: _inputError,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '검색',
                  onPressed: () => _submitSearch(_text.text),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, vm, _) {
                if (vm.phase == LoadPhase.idle) {
                  return const Center(child: Text('검색어를 입력합니다.'));
                }
                if (vm.phase == LoadPhase.loading) {
                  return const MovieListLoading();
                }
                if (vm.phase == LoadPhase.error) {
                  return MovieListError(
                    message: vm.errorMessage ?? '조회 오류입니다.',
                    onRetry: () => vm.loadInitial(query: _submittedQuery),
                  );
                }
                if (vm.phase == LoadPhase.empty) {
                  return const MovieListEmpty(message: '검색 결과가 없습니다.');
                }

                return ListView.builder(
                  itemCount: vm.movies.length + 1, // +1 = 맨 아래 더 보기 영역
                  itemBuilder: (context, index) {
                    if (index == vm.movies.length) {
                      return MoviePageFooter(vm: vm);
                    }
                    final movie = vm.movies[index];
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
                      onTap: () => widget.onOpenMovie(movie),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}