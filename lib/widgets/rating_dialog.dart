import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

/// 평점 등록·수정 공용 Dialog (별점 + 코멘트).
///
/// - 저장 로직은 [onSubmit]으로 받아 Dialog 안에서 실행합니다.
/// - onSubmit이 예외 없이 끝나면 true, 취소하면 onSubmit 호출 없이 false를 반환합니다.
///   (null = 뒤로가기 등으로 아무 동작도 하지 않고 닫힌 경우)
/// - 저장 중에는 확인 버튼이 로딩 상태가 되고, 뒤로가기·별점·코멘트 변경이 막힙니다.
///   바깥 탭을 막으려면 호출부에서 `barrierDismissible: false`도 함께 지정합니다.
/// - 실패하면 입력(별점·코멘트)을 그대로 둔 채 오류 문구만 보여줘 재시도할 수 있습니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.title = '영화는 어떠셨나요?',
    this.initialScore = 0,
    this.initialComment,
    required this.onSubmit,
  });

  final String title;
  final int initialScore; // 0 = 아직 선택 안 함
  final String? initialComment; // null이면 TextField는 빈 칸으로 시작
  final Future<void> Function(int score, String? comment) onSubmit;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  static const _maxCommentLength = 500;

  late int _score = widget.initialScore;
  // State가 살아 있는 동안 한 번만 만듭니다. (build()에서 만들면 setState마다 입력이 초기화됨)
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting, // 저장 중 시스템 뒤로가기 차단
      child: Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              MovieRatingInput(
                rating: _score.toDouble(),
                enabled: !_isSubmitting,
                onChanged: (value) =>
                    setState(() => _score = validateServerScore(value)),
              ),
              const SizedBox(height: 8),
              Text(_score == 0 ? '별을 눌러 선택하세요' : '$_score점'),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: _maxCommentLength,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: '코멘트를 남겨보세요 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      secondary: true,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MovieLogButton(
                      label: '확인',
                      isLoading: _isSubmitting,
                      // 별점을 고르기 전에는 코멘트를 입력해도 확인할 수 없습니다.
                      onPressed: _score > 0 && !_isSubmitting
                          ? _onConfirm
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > _maxCommentLength) {
      setState(() => _errorText = '코멘트는 500자 이하로 입력해 주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // 빈 코멘트는 null로 바꿔 보냅니다.
      await widget.onSubmit(_score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 _isSubmitting을 되돌려 다시 시도할 수 있게 하고, 입력은 그대로 보존합니다.
      setState(() {
        _isSubmitting = false;
        _errorText = describeWriteError(error);
      });
    }
  }
}
