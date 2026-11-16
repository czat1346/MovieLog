import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'view_models/auth_view_model.dart';
import 'view_models/edit_profile_view_model.dart';
import 'widgets/movielog_button.dart';

/// 프로필 수정: email은 읽기 전용, nickname만 편집합니다.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  late final String _initialNickname;

  @override
  void initState() {
    super.initState();
    _initialNickname = context.read<AuthViewModel>().member?.nickname ?? '';
    _controller = TextEditingController(text: _initialNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text.trim() != _initialNickname;

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      router.pop(); // 새 닉네임은 이미 AuthViewModel.member에 반영돼 있습니다.
    } else if (viewModel.message != null) {
      messenger.showSnackBar(SnackBar(content: Text(viewModel.message!)));
    }
    // 세션 만료(401)는 Router가 /login으로 보내므로 여기서 pop하지 않습니다.
  }

  /// (Challenge) 변경 내용이 있을 때 뒤로가기 확인.
  Future<void> _confirmLeave() async {
    final router = GoRouter.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('변경 내용이 있어요'),
        content: const Text('저장하지 않고 나갈까요?'),
        actions: [
          MovieLogButton(
            label: '취소',
            secondary: true,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          MovieLogButton(
            label: '나가기',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (leave == true && mounted) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (a) => a.member?.email,
    );

    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, child) {
        final saving = viewModel.status == EditProfileStatus.saving;
        return PopScope(
          canPop: !saving && !_dirty,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || saving) return; // 저장 중에는 나갈 수 없습니다.
            _confirmLeave();
          },
          child: Scaffold(
            appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: email,
                    enabled: false, // email은 읽기 전용입니다.
                    decoration: const InputDecoration(labelText: '이메일'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    enabled: !saving,
                    maxLength: 12,
                    onChanged: (_) => setState(() {}), // dirty 갱신
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      errorText: viewModel.nicknameError,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: MovieLogButton(
                      label: '저장',
                      width: double.infinity,
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
