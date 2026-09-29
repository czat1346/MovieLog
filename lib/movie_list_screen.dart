import 'package:flutter/material.dart';

import 'movie_data.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_card.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  static const _all = '전체';
  String _selected = _all;

  List<String> get _genres => [_all, ...movies.map((m) => m.genre).toSet()];

  @override
  Widget build(BuildContext context) {
    final filtered = _selected == _all
        ? movies
        : movies.where((m) => m.genre == _selected).toList();

    return Scaffold(
      appBar: const CommonAppBar(title: '영화'),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _genres.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final genre = _genres[index];
                return ChoiceChip(
                  label: Text(genre),
                  selected: genre == _selected,
                  onSelected: (_) => setState(() => _selected = genre),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
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