import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sprig_mascot.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/eco_points_provider.dart';
import '../domain/eco_points_model.dart';
import '../data/achievements_provider.dart';
import '../domain/achievement_model.dart';
import '../data/challenges_provider.dart';
import '../domain/daily_challenge_model.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  final bool isActive;
  const RewardsScreen({super.key, this.isActive = true});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  bool _isCampusSelected = true;
  bool _showAllAchievements = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(achievementsProvider.notifier).refresh();
        ref.read(dailyChallengesProvider.notifier).refresh();
      }
    });
  }

  @override
  void didUpdateWidget(covariant RewardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(achievementsProvider.notifier).refresh();
          ref.read(dailyChallengesProvider.notifier).refresh();
        }
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      ref.read(ecoPointsProvider.notifier).refresh(),
      ref.read(leaderboardProvider.notifier).refresh(),
      ref.read(achievementsProvider.notifier).refresh(),
      ref.read(dailyChallengesProvider.notifier).refresh(),
      ref.refresh(ecoPointEventsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(ecoPointsProvider);
    final summary = summaryAsync.value ?? EcoPointsSummary.zero();
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final achievementsAsync = ref.watch(achievementsProvider);
    final dailyChallengesAsync = ref.watch(dailyChallengesProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rewards',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF144D37).withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Level ${summary.currentLevel.level} of ${EcoScoringRules.levels.length}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 2. Rank / Level Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFC7F3DD),
                        Color(0xFFE2FAF0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF144D37).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Sprig inside circular progress frame
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 108,
                            height: 108,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(
                            width: 114,
                            height: 114,
                            child: CircularProgressIndicator(
                              value: summary.levelProgress,
                              strokeWidth: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.5),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1EA05A)),
                            ),
                          ),
                          const SprigMascot(size: 84, animated: false),
                        ],
                      ),

                      const SizedBox(width: 20),

                      // User Rank Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your level',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.inkSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.currentLevel.title,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${summary.totalPoints} EcoPoints',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF168047),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary.nextLevel != null
                                  ? 'Next: ${summary.nextLevel!.title} · Level ${summary.nextLevel!.level} (${summary.pointsToNextLevel} pts to go)'
                                  : 'Max level reached! 🌟',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                color: AppColors.inkSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Daily Challenges Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Daily Challenges',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        if (dailyChallengesAsync.hasValue &&
                            dailyChallengesAsync.value!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7EE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _formatChallengeDate(
                                  dailyChallengesAsync.value!.first.challengeDate),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF144D37),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (dailyChallengesAsync.hasValue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6F2E3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${dailyChallengesAsync.value!.where((c) => c.isCompleted).length} of ${dailyChallengesAsync.value!.length} completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                dailyChallengesAsync.when(
                  data: (challenges) {
                    if (challenges.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.task_alt_rounded, size: 36, color: AppColors.inkMuted),
                              const SizedBox(height: 8),
                              Text(
                                'No active challenges today',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: challenges.map((c) => _buildDailyChallengeCard(c)).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
                  error: (error, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Unable to load daily challenges.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(dailyChallengesProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 4. Achievements Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Achievements',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (achievementsAsync.hasValue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6F2E3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${achievementsAsync.value!.where((a) => a.isUnlocked).length} of ${achievementsAsync.value!.length} unlocked',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                achievementsAsync.when(
                  data: (achievements) {
                    if (achievements.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.emoji_events_outlined, size: 36, color: AppColors.inkMuted),
                              const SizedBox(height: 8),
                              Text(
                                'No achievements found',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final displayedAchievements = _showAllAchievements
                        ? achievements
                        : achievements.take(2).toList();

                    return Column(
                      children: [
                        ...displayedAchievements.map((a) => _buildAchievementCard(a)),
                        if (achievements.length > 2) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showAllAchievements = !_showAllAchievements;
                                });
                              },
                              icon: Icon(
                                _showAllAchievements
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                _showAllAchievements ? 'Show less' : 'Show more',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Color(0xFFD6F2E3)),
                                ),
                                backgroundColor: const Color(0xFFF2FAF5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
                  error: (error, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Unable to load achievements.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(achievementsProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Leaderboard Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Leaderboard',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    // Toggle Pills (Campus / Monthly)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2EBE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _buildLeaderboardToggle('Campus', _isCampusSelected, () {
                            setState(() => _isCampusSelected = true);
                          }),
                          _buildLeaderboardToggle('Monthly', !_isCampusSelected, () {
                            setState(() => _isCampusSelected = false);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Leaderboard Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF144D37).withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: leaderboardAsync.when(
                    data: (leaderboard) {
                      if (leaderboard.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.leaderboard_outlined, size: 40, color: AppColors.inkMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No ranked students yet',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Submit reports to earn EcoPoints and claim #1!',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Check if current user is in the leaderboard
                      final profile = ref.watch(userProfileProvider).value;
                      final currentUserId = currentUser?.id;
                      final currentDisplayName = profile?.displayName?.trim();

                      bool isEntryCurrentUser(LeaderboardEntry entry) {
                        if (currentUserId != null && entry.userId.isNotEmpty && entry.userId == currentUserId) {
                          return true;
                        }
                        if (currentDisplayName != null &&
                            currentDisplayName.isNotEmpty &&
                            entry.displayName.trim().toLowerCase() == currentDisplayName.toLowerCase()) {
                          return true;
                        }
                        return false;
                      }

                      final userInLeaderboard = leaderboard.any(isEntryCurrentUser);

                      return Column(
                        children: [
                          for (int i = 0; i < leaderboard.length; i++) ...[
                            if (i > 0)
                              Divider(
                                color: AppColors.borderLight,
                                height: 1,
                                indent: 64,
                                endIndent: 20,
                              ),
                            _buildLeaderboardItem(
                              entry: leaderboard[i],
                              isCurrentUser: isEntryCurrentUser(leaderboard[i]),
                            ),
                          ],
                          if (!userInLeaderboard && currentUserId != null && summary.totalPoints > 0) ...[
                            Divider(
                              color: AppColors.borderLight,
                              height: 1,
                              indent: 64,
                              endIndent: 20,
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F7EE),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                              ),
                              child: _buildLeaderboardRow(
                                rank: leaderboard.length + 1,
                                rankColor: AppColors.primary,
                                initial: (currentDisplayName?.isNotEmpty ?? false)
                                    ? currentDisplayName![0].toUpperCase()
                                    : ((currentUser?.email?.isNotEmpty ?? false)
                                        ? currentUser!.email![0].toUpperCase()
                                        : 'Y'),
                                name: currentDisplayName?.isNotEmpty ?? false ? currentDisplayName! : 'You',
                                points: '${summary.totalPoints} pts',
                                levelSubtitle: 'Level ${summary.level} · ${summary.levelTitle}',
                                isCurrentUser: true,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      child: Center(
                        child: Text(
                          'Could not load leaderboard.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem({
    required LeaderboardEntry entry,
    required bool isCurrentUser,
  }) {
    Color rankColor;
    if (entry.rank == 1) {
      rankColor = const Color(0xFFE6B800);
    } else if (entry.rank == 2) {
      rankColor = const Color(0xFF9EA3A8);
    } else if (entry.rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = AppColors.inkSecondary;
    }

    final initial = entry.displayName.isNotEmpty
        ? entry.displayName[0].toUpperCase()
        : 'S';

    final name = isCurrentUser ? '${entry.displayName} (You)' : entry.displayName;

    final row = _buildLeaderboardRow(
      rank: entry.rank,
      rankColor: rankColor,
      initial: initial,
      name: name,
      points: '${entry.totalPoints} pts',
      levelSubtitle: 'Level ${entry.level} · ${entry.levelTitle}',
      isCurrentUser: isCurrentUser,
    );

    if (isCurrentUser) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8F7EE),
        ),
        child: row,
      );
    }
    return row;
  }

  String _formatChallengeDate(String dateStr) {
    if (dateStr.isEmpty) return 'Today';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return 'Today · ${dt.day} ${months[dt.month - 1]}';
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildDailyChallengeCard(DailyChallenge challenge) {
    final isCompleted = challenge.isCompleted;
    final accentColor = challenge.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isCompleted
            ? Border.all(color: const Color(0xFF1EA05A).withValues(alpha: 0.35), width: 1.5)
            : Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: isCompleted ? 0.05 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Icon with completed checkmark
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFD6F2E3)
                          : accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        challenge.iconData,
                        color: isCompleted ? const Color(0xFF1EA05A) : accentColor,
                        size: 24,
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1EA05A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Title and status badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFFD6F2E3)
                                : const Color(0xFFF0F3F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCompleted) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: Color(0xFF1EA05A),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isCompleted
                                    ? 'Completed'
                                    : '${challenge.progressCount} / ${challenge.targetCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted
                                      ? const Color(0xFF1EA05A)
                                      : AppColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress indicator bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: challenge.progressFraction,
                    backgroundColor: const Color(0xFFE4EDE7),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? const Color(0xFF1EA05A) : accentColor,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isCompleted
                    ? '100%'
                    : '${challenge.progressCount} / ${challenge.targetCount}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? const Color(0xFF1EA05A) : AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked;
    final accentColor = achievement.accentColor;

    final effectiveBg = isUnlocked
        ? accentColor.withValues(alpha: 0.15)
        : const Color(0xFFF3F4F6);
    final effectiveIconColor = isUnlocked
        ? accentColor
        : AppColors.inkSecondary;
    final effectiveTextColor = isUnlocked
        ? AppColors.inkPrimary
        : AppColors.inkSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isUnlocked
            ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5)
            : Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: isUnlocked ? 0.05 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Icon with unlocked checkmark or lock overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: effectiveBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        achievement.iconData,
                        color: effectiveIconColor,
                        size: 24,
                      ),
                    ),
                  ),
                  if (isUnlocked)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1EA05A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  if (!isUnlocked)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Title and status pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: effectiveTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? const Color(0xFFD6F2E3)
                                : const Color(0xFFF0F3F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isUnlocked
                                ? 'Unlocked'
                                : '${achievement.progressCount} / ${achievement.targetCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isUnlocked
                                  ? const Color(0xFF1EA05A)
                                  : AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progress bar or unlock timestamp
          if (!isUnlocked && achievement.targetCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: achievement.progressFraction,
                      backgroundColor: const Color(0xFFE4EDE7),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${achievement.progressCount} / ${achievement.targetCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ] else if (isUnlocked && achievement.formattedUnlockDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.stars_rounded, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  'Earned on ${achievement.formattedUnlockDate}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaderboardToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required int rank,
    required Color rankColor,
    required String initial,
    required String name,
    required String points,
    String? levelSubtitle,
    bool isCurrentUser = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isCurrentUser ? const Color(0xFFD6F2E3) : rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isCurrentUser ? AppColors.primary : rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Avatar Initial
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFD6F2E3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Name & Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 14,
                    color: isCurrentUser ? AppColors.primary : AppColors.inkPrimary,
                  ),
                ),
                if (levelSubtitle != null && levelSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    levelSubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Points
          Text(
            points,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isCurrentUser ? AppColors.primary : AppColors.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
