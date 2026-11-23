import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/models/member_info.dart';
import 'theme/app_colors.dart';
import 'view_models/auth_view_model.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            // 토큰과 member를 지우면 Router가 /login으로 보냅니다. 만료 Snackbar는 뜨지 않습니다.
            onPressed: auth.storageCleanupInProgress
                ? null
                : () => context.read<AuthViewModel>().logout(),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, auth)),
    );
  }

  Widget _buildBody(BuildContext context, AuthViewModel auth) {
    final member = auth.member;
    if (member == null) {
      // (Challenge) 내 정보 로딩·실패·재시도: 네트워크 실패로 로그아웃하지 않습니다.
      if (auth.memberStatus == MemberLoadStatus.error) {
        return MovieListError(
          message: '내 정보를 불러오지 못했어요.',
          onRetry: () => context.read<AuthViewModel>().loadMember(force: true),
        );
      }
      return const MovieListLoading();
    }
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: ProfileHeader()),
          SizedBox(height: 22),
          Center(child: EditProfileButton()),
          SizedBox(height: 32),
          ProfileStats(),
          SizedBox(height: 28),
          FavoriteGenres(),
          SizedBox(height: 24),
          MyRatingsTile(),
          MyFavoritesTile(),
          SizedBox(height: 32),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

String _formatJoinedDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final member = context.select<AuthViewModel, MemberInfo?>((a) => a.member);

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: const AssetImage('assets/images/profile/profile_movielog.jpg'),
          backgroundColor: AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(member?.nickname ?? '', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        // (Challenge) 가입일: "2026.10.10 가입"
        if (member != null)
          Text(
            '${_formatJoinedDate(member.createdAt)} 가입',
            style: textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            member?.email ?? '',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        SvgPicture.asset(
          'assets/icons/movie.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            AppColors.primary,
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StatItem(label: '본 영화', value: '5600'),
        StatItem(label: '평점', value: '9.9'),
        StatItem(label: '즐겨찾기', value: '1'),
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 115,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('선호 장르', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GenreChip(label: 'animation'),
            GenreChip(label: 'anime'),
            GenreChip(label: '애니메이션'),
          ],
        ),
      ],
    );
  }
}

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.white,
      side: const BorderSide(color: AppColors.primary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 48,
      child: ElevatedButton(
        // member가 있을 때만 이 화면이 그려지므로 항상 활성입니다.
        onPressed: () => context.push('/my/profile/edit'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('프로필 수정'),
      ),
    );
  }
}

class MyRatingsTile extends StatelessWidget {
  const MyRatingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('내가 등록한 평점'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/my/ratings'),
    );
  }
}
class MyFavoritesTile extends StatelessWidget {
  const MyFavoritesTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('내 즐겨찾기'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/my/favorites'),
    );
  }
}
