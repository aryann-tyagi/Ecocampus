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
                      'Not configured yet',
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
                            value: 0.0,
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
                            'Levels not connected yet',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'EcoPoints ledger not connected yet',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF168047),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Levels will appear when rewards are connected',
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

              // Gamification items stay hidden until they are backed by trusted data.
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
                child: Text(
                  'Achievements and challenges are not connected yet. They will appear here once the rewards system is implemented.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkSecondary,
                    height: 1.4,
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

              // No fabricated names or ranks: this is pending a trusted server-side points ledger.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
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
                    Icon(Icons.leaderboard_outlined, size: 34, color: AppColors.inkMuted),
                    const SizedBox(height: 10),
                    Text(
                      'Leaderboard not available yet',
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Campus and monthly rankings will show here after EcoPoints are stored and calculated securely in Supabase.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                        height: 1.4,
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
