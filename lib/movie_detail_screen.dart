import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import 'theme/app_colors.dart';
import 'view_models/movie_detail_view_model.dart';
import 'view_models/submit_status.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/rating_dialog.dart';
import 'widgets/tmdb_poster_image.dart';

/// 영화 상세 화면 (TMDB 영화 정보 + MovieLog 평점 등록).
/// 평점 조회·수정·삭제는 마이페이지의 "내가 등록한 평점" 화면에서만 합니다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isFavorite = false;

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
    final viewModel = context.read<MovieDetailViewModel>()
      ..resetSubmitState(); // 이전 시도의 오류가 이번 Dialog 결과로 오인되지 않게 초기화

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            // Dialog가 오류 문구를 보여주고 입력을 유지한 채 재시도할 수 있게 합니다.
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계이므로 mounted를 다시 확인합니다.
    if (!mounted) return;
    if (saved == true) {
      _showSnack('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
    } else if (saved == false && viewModel.submitStatus == SubmitStatus.error) {
      // 저장에 실패한 뒤 Dialog를 취소한 경우에만 실패 안내를 남깁니다.
      _showSnack('평점을 등록하지 못했습니다. ${viewModel.submitMessage ?? ''}'.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;
    final textTheme = Theme.of(context).textTheme;

    final date = movie.releaseDate;
    final year = (date != null && date.length >= 4)
        ? date.substring(0, 4)
        : null;

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
              child: LayoutBuilder(
                builder: (context, constraints) => TmdbPosterImage(
                  posterPath: movie.posterPath,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: textTheme.titleLarge),
                  if (year != null) ...[
                    const SizedBox(height: 4),
                    Text(year, style: textTheme.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // TMDB voteAverage는 10점 만점이라 5점 만점 별로 환산해 보여줍니다.
                      RatingBarIndicator(
                        rating: movie.voteAverage / 2,
                        itemCount: 5,
                        itemSize: 24,
                        itemBuilder: (context, index) =>
                            const Icon(Icons.star, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        movie.voteAverage.toStringAsFixed(1),
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(width: 4),
                      Text('(TMDB)', style: textTheme.bodySmall),
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
                    movie.overview.isEmpty ? '등록된 줄거리가 없습니다.' : movie.overview,
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
        // 이 화면은 Router redirect로 로그인 상태에서만 열립니다.
        onRateTap: _openRatingDialog,
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onFavoriteTap,
                    // 즐겨찾기 상태에 따라 아이콘과 배경이 바뀜
                    icon: Icon(
                      isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: const Text('즐겨찾기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: isFavorite
                          ? const Color(0xFFEADDFF)
                          : Colors.transparent,
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
                      disabledBackgroundColor: AppColors.gray,
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
