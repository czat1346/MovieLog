import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

import 'data/models/rating_dto.dart';
import 'data/models/rating_with_movie.dart';
import 'data/services/rating_api_service.dart';
import 'theme/app_colors.dart';
import 'view_models/my_ratings_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';
import 'widgets/movielog_button.dart';
import 'widgets/rating_dialog.dart';
import 'widgets/tmdb_poster_image.dart';

/// 마이페이지 > 내가 등록한 평점. 이번 로그인 세션에서 등록한 평점의 수정 · 삭제 · (Challenge) 다중 삭제.
///
/// v7에는 토큰 기반 내 평점 전체 조회가 없어 재시작 뒤 기존 평점은 복원하지 않습니다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MyRatingsViewModel>(
      builder: (context, vm, child) {
        // 다중 삭제 중에는 뒤로가기·스와이프 백을 막습니다. (AppBar 뒤로가기 포함)
        return PopScope(
          canPop: !vm.isDeletingSelected,
          child: Scaffold(
            appBar: _buildAppBar(vm),
            body: LoadingOverlay(
              isLoading: vm.isDeletingSelected,
              child: _buildBody(context, vm),
            ),
            bottomNavigationBar:
                vm.isSelectionMode && vm.status == MyRatingsLoadStatus.success
                ? _DeleteSelectedBar(
                    count: vm.selectedRatingIds.length,
                    onPressed:
                        vm.selectedRatingIds.isEmpty || vm.isDeletingSelected
                        ? null
                        : () => onDeleteSelectedPressed(context),
                  )
                : null,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(MyRatingsViewModel vm) {
    if (vm.isSelectionMode) {
      // 선택 모드: 왼쪽에 선택한 카드 수, 오른쪽에는 "편집" 대신 "취소"
      return CommonAppBar(
        title: '${vm.selectedRatingIds.length}개 선택',
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: vm.isDeletingSelected ? null : vm.exitSelectionMode,
            child: const Text('취소'),
          ),
        ],
      );
    }
    // 기본 모드: 왼쪽 뒤로가기 · 중앙 제목 · 오른쪽 "편집" (하단 NavigationBar 없음)
    return CommonAppBar(
      title: '내가 등록한 평점',
      centerTitle: true,
      actions: [
        if (vm.status == MyRatingsLoadStatus.success)
          TextButton(onPressed: vm.enterSelectionMode, child: const Text('편집')),
      ],
    );
  }

  Widget _buildBody(BuildContext context, MyRatingsViewModel vm) {
    return switch (vm.status) {
      MyRatingsLoadStatus.idle ||
      MyRatingsLoadStatus.loading => const MovieListLoading(),
      MyRatingsLoadStatus.empty => const MovieListEmpty(
        message: '이번 로그인 이후 등록한 평점이 없습니다.\n영화 상세에서 평점을 남기면 여기에 표시돼요.',
      ),
      MyRatingsLoadStatus.error => MovieListError(
        message: vm.message ?? '평점을 불러오지 못했습니다.',
        onRetry: vm.load,
      ),
      MyRatingsLoadStatus.success => _RatingsList(
        ratings: vm.ratings,
        notice: vm.message,
        selectionMode: vm.isSelectionMode,
        selectedIds: vm.selectedRatingIds,
        onToggle: vm.toggleSelection,
        onEdit: (rating) => onEditPressed(context, rating),
        onDelete: (rating) => onDeletePressed(context, rating),
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// 수정 / 삭제 동작
// ---------------------------------------------------------------------------

/// 수정 버튼 → 기존 별점·코멘트가 채워진 RatingDialog를 다시 엽니다.
Future<void> onEditPressed(BuildContext context, RatingDto rating) async {
  // 저장 뒤 목록이 재조회되면 카드가 다시 그려지므로, 필요한 객체는 await 전에 잡아 둡니다.
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => RatingDialog(
      title: '평점 수정',
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 TextField가 빈 칸으로 시작합니다.
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment, // score와 함께 항상 전송: 유지/삭제 의도를 명확히 합니다.
      ),
    ),
  );

  if (saved != true) return; // 취소·저장 실패는 별도 처리 없음 (실패는 Dialog가 안내)
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('평점을 수정했습니다.')));
}

/// 삭제 버튼 → 확인 Dialog. 취소하면 삭제 API 요청을 보내지 않습니다.
Future<void> onDeletePressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막습니다.
    builder: (_) => _DeleteRatingDialog(
      onConfirm: () => viewModel.deleteRating(rating.ratingId),
    ),
  );

  // confirmed는 실제로 삭제까지 마쳤을 때만 true입니다.
  if (confirmed != true) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('평점을 삭제했습니다.')));
}

class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.onConfirm});
  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('평점을 삭제할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('삭제한 평점은 복구할 수 없습니다.'),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          MovieLogButton(
            label: '취소',
            secondary: true,
            onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() {
      _isDeleting = true;
      _errorText = null;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패하면 로딩을 풀고 오류 문구를 보여줘 다시 시도하거나 취소할 수 있게 합니다.
      setState(() {
        _isDeleting = false;
        _errorText = describeWriteError(error);
      });
    }
  }
}

/// (Challenge) 선택한 평점 삭제 확인 → Dialog는 바로 닫고, 삭제는 화면의 오버레이가 이어받습니다.
Future<void> onDeleteSelectedPressed(BuildContext context) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final messenger = ScaffoldMessenger.of(context);
  final count = viewModel.selectedRatingIds.length;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('선택한 $count개 평점을 삭제할까요?'),
      content: const Text('삭제한 평점은 복구할 수 없습니다.'),
      actions: [
        MovieLogButton(
          label: '취소',
          secondary: true,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        MovieLogButton(
          label: '삭제',
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  // 여기서 Dialog는 이미 닫혔습니다. 삭제 요청은 Dialog가 닫힌 뒤 화면에서 시작합니다.

  if (confirmed != true) return;

  final failed = await viewModel.deleteSelectedRatings();
  if (failed > 0) {
    // 일부만 실패: 성공한 항목만 목록에서 사라지고, 실패한 항목은 선택이 유지됩니다.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.')),
      );
  }
}

// ---------------------------------------------------------------------------
// 목록 UI
// ---------------------------------------------------------------------------

class _DeleteSelectedBar extends StatelessWidget {
  const _DeleteSelectedBar({required this.count, required this.onPressed});

  final int count;
  final VoidCallback? onPressed; // 선택이 1개 이상일 때만 활성화

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
        child: MovieLogButton(
          label: '선택한 $count개 삭제',
          width: double.infinity,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({
    required this.ratings,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.notice,
  });

  final List<RatingWithMovie> ratings;
  final String? notice; // 일부 영화 정보 누락 안내
  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;
  final ValueChanged<RatingDto> onEdit;
  final ValueChanged<RatingDto> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '이번 로그인 이후 등록한 평점만 표시돼요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(notice!, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final entry in ratings)
          _RatingCard(
            entry: entry,
            selectionMode: selectionMode,
            selected: selectedIds.contains(entry.rating.ratingId),
            onToggle: () => onToggle(entry.rating.ratingId),
            onEdit: () => onEdit(entry.rating),
            onDelete: () => onDelete(entry.rating),
          ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.entry,
    required this.selectionMode,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RatingWithMovie entry;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _date(DateTime d) {
    final local = d.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}.$m.$day';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rating = entry.rating;
    final movie = entry.movie; // null이면 포스터는 placeholder, 제목은 대체 문구
    final comment = rating.comment;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 선택 모드에서는 카드 어디를 눌러도 선택/해제됩니다.
      onTap: selectionMode ? onToggle : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TmdbPosterImage(
                posterPath: movie?.posterPath,
                width: 64,
                height: 92,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movieTitleOrPlaceholder(rating, movie), // 없으면 `영화 #{movieId}`
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RatingBarIndicator(
                    rating: rating.score.toDouble(),
                    itemCount: 5,
                    itemSize: 18,
                    itemBuilder: (context, index) =>
                        const Icon(Icons.star, color: AppColors.primary),
                  ),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(comment, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 6),
                  Text(_date(rating.createdAt), style: textTheme.bodySmall),
                ],
              ),
            ),
            // 이 목록은 현재 세션에서 본인이 등록한 평점이므로 모든 카드에 수정·삭제 버튼을 표시합니다.
            if (selectionMode)
              Checkbox(value: selected, onChanged: (_) => onToggle())
            else
              Column(
                children: [
                  IconButton(
                    tooltip: '수정',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
