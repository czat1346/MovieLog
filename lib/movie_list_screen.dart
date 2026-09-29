import 'package:flutter/material.dart';

import 'movie_data.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_card.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  Set<String> _applied = {}; // 비어 있으면 전체 표시

  List<String> get _allGenres => movies.map((m) => m.genre).toSet().toList();

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => GenreFilterSheet(
          genres: _allGenres,
          initialSelected: _applied,
          scrollController: scrollController,
        ),
      ),
    );
    if (result == null) return; // 바깥을 눌러 닫으면 변경 없음
    setState(() => _applied = result);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applied.isEmpty
        ? movies
        : movies.where((m) => _applied.contains(m.genre)).toList();

    return Scaffold(
      appBar: const CommonAppBar(title: '영화'),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.filter),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) => MovieCard(movie: filtered[index]),
            ),
          ),
        ],
      ),
    );
  }
}