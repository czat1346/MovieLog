import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/models/tmdb_movie_dto.dart';
import 'data/services/rating_api_service.dart';
import 'data/services/tmdb_movie_service.dart';
import 'movie_detail_screen.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/movie_detail_view_model.dart';
import 'view_models/session_ratings_store.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_list_error.dart';

/// 영화 상세 화면의 시작점.
///
/// 목록에서 `extra`로 넘겨 준 [TmdbMovieDto]가 있으면 그대로 쓰고,
/// 직접 접근·Deep Link처럼 extra가 없으면 TMDB GET /movie/{movie_id}로 다시 조회합니다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  final int movieId; // URL 식별자. 5주차 TmdbMovieDto.id와 같은 값입니다.
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  late Future<TmdbMovieDto> _movieFuture;

  @override
  void initState() {
    super.initState();
    _movieFuture = _fetch();
  }

  Future<TmdbMovieDto> _fetch() {
    final initial = widget.initialMovie;
    if (initial != null) return Future.value(initial);
    return context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture, // build마다 새 Future를 만들지 않습니다.
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            appBar: CommonAppBar(title: 'Cinema Archive'),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final movie = snapshot.data;
        if (snapshot.hasError || movie == null) {
          return Scaffold(
            appBar: const CommonAppBar(title: 'Cinema Archive'),
            body: MovieListError(
              message: '영화를 불러오지 못했습니다.',
              onRetry: () => setState(() => _movieFuture = _fetch()),
            ),
          );
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            context.read<AuthViewModel>(),
            context.read<SessionRatingsStore>(),
            movie,
          ),
          child: const MovieDetailScreen(),
        );
      },
    );
  }
}
