import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final bool centerTitle;
  final List<Widget>? actions; // 우측 버튼 (예: 편집/취소)
  final bool automaticallyImplyLeading; // false면 자동 뒤로가기 버튼을 숨김

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: AppColors.primary),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
