import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'movie_data.dart';
import 'theme/app_colors.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/rating_dialog.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId; // Path Parameter는 String으로 들어옴

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;
  double? _myRating;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnack(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  Future<void> _openRatingDialog() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => const RatingDialog(),
    );
    if (!mounted || result == null) return;
    setState(() => _myRating = result);
    _showSnack('평점 $result점을 남겼습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(int.tryParse(widget.movieId));

    if (movie == null) {
      return const Scaffold(
        appBar: CommonAppBar(title: 'Cinema Archive'),
        body: Center(child: Text('영화를 찾을 수 없습니다.')),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const CommonAppBar(title: 'Cinema Archive'),
      // 스크롤되는 본문
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 420,
              child: Image.asset(
                movie.posterAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Icon(Icons.movie, size: 60),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.year} • ${movie.genre} • ${movie.runtime}분',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: movie.rating,
                        itemCount: 5,
                        itemSize: 24,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${movie.rating}',
                          style: textTheme.titleMedium),
                      const SizedBox(width: 4),
                      Text('(${movie.ratingCount})',
                          style: textTheme.bodySmall),
                    ],
                  ),
                  if (_myRating != null) ...[
                    const SizedBox(height: 8),
                    Text('내 평점: $_myRating점', style: textTheme.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in movie.tags) _TagChip(label: tag),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('시놉시스', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    movie.synopsis,
                    style: textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // 스크롤과 무관하게 항상 하단에 고정되는 버튼 영역
      bottomNavigationBar: _BottomActionBar(
        isFavorite: _isFavorite,
        onFavoriteTap: _toggleFavorite,
        onRateTap: _openRatingDialog,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E4E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// 하단 고정 버튼: 즐겨찾기(토글) + 평점 남기기
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onRateTap,
  });

  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onRateTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onFavoriteTap,
                // 즐겨찾기 상태에 따라 아이콘과 배경이 바뀜
                icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
                label: const Text('즐겨찾기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor:
                      isFavorite ? const Color(0xFFEADDFF) : Colors.transparent,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onRateTap,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('평점 남기기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}