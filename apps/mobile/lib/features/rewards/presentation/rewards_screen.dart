import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sprig_mascot.dart';
import '../../report/data/reports_provider.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  bool _isCampusSelected = true;

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(userPointsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                      'Level 5 of 20',
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
                            value: 0.72,
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
                            'Your rank',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.inkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sprout',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$points EcoPoints',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF168047),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Next: Guardian · Level 10',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Active Challenge Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF144D37).withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active challenge',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.inkSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD6F2E3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '+100',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Report 5 valid issues',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: const LinearProgressIndicator(
                        value: 0.6,
                        backgroundColor: Color(0xFFE4EDE7),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1EA05A)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 4. Achievements Section
              Text(
                'Achievements',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAchievementCard(
                      icon: Icons.flag_rounded,
                      iconBg: const Color(0xFF1EA05A),
                      title: 'First Report',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAchievementCard(
                      icon: Icons.shield_rounded,
                      iconBg: const Color(0xFFE29520),
                      title: 'Eco Warrior',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAchievementCard(
                      icon: Icons.water_drop_rounded,
                      iconBg: const Color(0xFF64B5F6),
                      title: 'Water Saver',
                    ),
                  ),
                ],
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
                child: Column(
                  children: [
                    _buildLeaderboardRow(
                      rank: 1,
                      rankColor: const Color(0xFFE6B800),
                      initial: 'A',
                      name: 'Ananya R.',
                      points: '1,240 pts',
                    ),
                    Divider(color: AppColors.borderLight, height: 1, indent: 64, endIndent: 20),
                    _buildLeaderboardRow(
                      rank: 2,
                      rankColor: const Color(0xFF9EA3A8),
                      initial: 'K',
                      name: 'Kabir S.',
                      points: '1,105 pts',
                    ),
                    Divider(color: AppColors.borderLight, height: 1, indent: 64, endIndent: 20),
                    _buildLeaderboardRow(
                      rank: 3,
                      rankColor: const Color(0xFFCD7F32),
                      initial: 'M',
                      name: 'Meera T.',
                      points: '980 pts',
                    ),
                    // Current User Row (Highlighted with light mint background!)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F7EE),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                      ),
                      child: _buildLeaderboardRow(
                        rank: 14,
                        rankColor: AppColors.primary,
                        initial: 'Y',
                        name: 'You',
                        points: '$points pts',
                        isCurrentUser: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard({
    required IconData icon,
    required Color iconBg,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
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
          // User Name
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w700,
                fontSize: 14,
                color: isCurrentUser ? AppColors.primary : AppColors.inkPrimary,
              ),
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
