import 'package:flutter/material.dart';
 
import 'movie_data.dart';
import 'services/fake_movie_service.dart';
import 'services/genre_preference.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
 
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});
 
  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}
 
class _MovieListScreenState extends State<MovieListScreen> {
  // TODO(5주차 유저별 평점 조회 API): 실제 API 서비스로 교체할 위치
  final _service = const FakeMovieService();
  final _genrePref = GenrePreference();
 
  // 테스트용: success / empty / failure 로 바꿔가며 화면 확인 (제출 시 success)
  MovieLoadMode _mode = MovieLoadMode.failure;
 
  late Future<List<Movie>> _moviesFuture;
  Set<String> _applied = {}; // 비어 있으면 전체 표시
 
  List<String> get _allGenres => movies.expand((m) => m.tags).toSet().toList();
 
  @override
  void initState() {
    super.initState();
    // Future는 build가 아니라 여기서 딱 한 번 만든다
    _moviesFuture = _service.fetchMovies(mode: _mode);
    _loadSavedGenres();
  }
 
  Future<void> _loadSavedGenres() async {
    final saved = await _genrePref.read();
    if (!mounted) return; // await 뒤에 setState를 쓰므로 필수
    setState(() => _applied = saved);
  }
 
  void _retry() {
    setState(() {
      _mode = MovieLoadMode.success; // 재시도는 성공하도록
      _moviesFuture = _service.fetchMovies(mode: _mode); // 새 Future 생성
    });
  }
 
  // Chip을 누를 때마다 즉시 화면을 갱신하고 마지막 선택을 저장한다
  Future<void> _toggleGenre(String genre) async {
    final next = {..._applied};
    if (!next.remove(genre)) next.add(genre);
    setState(() => _applied = next);
    await _genrePref.save(next);
  }
 
  @override
  Widget build(BuildContext context) {
    final genres = _allGenres;
 
    return Scaffold(
      appBar: const CommonAppBar(title: '영화'),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: genres.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final genre = genres[index];
                return FilterChip(
                  label: Text(genre),
                  selected: _applied.contains(genre),
                  onSelected: (_) => _toggleGenre(genre),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Movie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                // 1) 기다리는 중
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MovieListLoading();
                }
 
                // 2) 오류 (Empty보다 먼저 확인!)
                if (snapshot.hasError) {
                  return MovieListError(onRetry: _retry);
                }
 
                // 3) 성공 → 장르 필터 적용
                final all = snapshot.data ?? const <Movie>[];
                final filtered = _applied.isEmpty
                    ? all
                    : all
                        .where(
                          (m) => _applied.every((tag) => m.tags.contains(tag)),
                        )
                        .toList();
 
                // 4) 비어 있음
                if (filtered.isEmpty) {
                  return const MovieListEmpty();
                }
 
                return MovieGrid(movies: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }
}