import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_bottom_nav.dart';
import '../../../core/widgets/severity_badge.dart';
import '../../report/data/reports_provider.dart';
import '../../report/domain/report_model.dart';
import '../../report/presentation/report_issue_screen.dart';
import '../../reports_tracking/presentation/report_detail_screen.dart';
import '../../auth/data/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/companion_provider.dart';
import '../data/home_providers.dart';
import '../../rewards/data/eco_points_provider.dart';
import '../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../notices/data/notices_provider.dart';
import '../../notices/presentation/notice_banner_card.dart';

/// Sustainability tips cycled when tapping the mascot speech bubble.
const List<String> _kCompanionTips = [
  "Let's make our campus better!",
  "Reporting a dripping tap can save over 5,000 liters of water a year!",
  "Turn off classroom projectors when leaving to conserve energy.",
  "Sorted recycling helps divert 80% of waste from landfills.",
  "Every verified report earns you EcoPoints towards campus rewards!",
];

final DateFormat _kHomeDateFormat = DateFormat('d MMMM yyyy');

class StudentHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToReports;
  final VoidCallback? onNavigateToRewards;
  final bool isActive;

  const StudentHomeScreen({
    super.key,
    required this.onNavigateToReports,
    this.onNavigateToRewards,
    this.isActive = true,
  });

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  final ValueNotifier<int> _tipIndex = ValueNotifier<int>(0);
  Timer? _periodicRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPushNotifications();
    });
    // Automatic periodic background refresh every 30 seconds while Home is active
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.isActive) {
        ref.read(campusReportsProvider.notifier).refresh();
        ref.read(myReportsProvider.notifier).refresh();
      }
    });
  }

  @override
  void didUpdateWidget(StudentHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When student navigates back to Home tab, refresh the feed automatically
    if (widget.isActive && !oldWidget.isActive) {
      _handleRefresh();
    }
  }

  Future<void> _initPushNotifications() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await PushNotificationService.instance.requestPermission();
      await PushNotificationService.instance.syncDeviceToken(user.id);
    }
  }

  @override
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _tipIndex.dispose();
    super.dispose();
  }

  void _cycleTip() {
    _tipIndex.value = (_tipIndex.value + 1) % _kCompanionTips.length;
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      ref.read(myReportsProvider.notifier).refresh(),
      ref.read(campusReportsProvider.notifier).refresh(),
      ref.refresh(userProfileProvider.future),
      ref.read(ecoPointsProvider.notifier).refresh(),
      ref.read(activeNoticesProvider.notifier).refresh(),
    ]);
  }

  void _navigateToReportIssue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const ReportIssueScreen(),
      ),
    );
  }

  void _showRenameCompanionSheet(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F7EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pets_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Name Your Companion',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Give your eco companion a personalized name. It will be saved locally on your device and synced with your EcoCampus profile.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.inkSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    maxLength: kCompanionNameMaxLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Companion Name',
                      hintText: 'e.g. Cutuuu, Leafy, Sprig',
                      prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Companion name cannot be empty';
                      }
                      if (trimmed.length > kCompanionNameMaxLength) {
                        return 'Must be $kCompanionNameMaxLength characters or less';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              final newName = controller.text.trim();
                              final notifier = ref.read(companionNameProvider.notifier);
                              final success = await notifier.setName(newName);
                              if (context.mounted) {
                                Navigator.of(sheetCtx).pop();
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Companion renamed to $newName!'),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  final errorMsg = notifier.lastError ??
                                      'Failed to update companion name. Please check your connection and try again.';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMsg),
                                      backgroundColor: AppColors.severityCritical,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Save Name'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEcoScoreDetails(BuildContext context, HomeDashboardStats stats, [int? points]) {
    final displayPoints = points ?? stats.totalPoints;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F7EE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF1EA05A),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Campus Eco Score',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '$displayPoints pts',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Text(
                        'ESTIMATE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Per PRD §14, Eco Score is an estimated metric calculated from resolution health, campus cleanliness reports, and response speed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCol('Total Reports', '${stats.totalReports}'),
                      _buildStatCol('Resolved', '${stats.resolvedReports}', color: const Color(0xFF1EA05A)),
                      _buildStatCol('Active', '${stats.activeReports}', color: const Color(0xFFD98327)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLevelDetails(BuildContext context, HomeDashboardStats stats, int points) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDF4E7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD98327),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${stats.level} · ${stats.levelTitle}',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '$points EcoPoints earned',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Earn EcoPoints by reporting environmental hazards, participating in sustainability challenges, and verifying campus fixes.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.inkSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    if (widget.onNavigateToRewards != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            widget.onNavigateToRewards!();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('View Rewards'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCol(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.inkPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.inkSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showProfileSheet(BuildContext context) {
    final profile = ref.read(userProfileProvider).value;
    final user = ref.read(currentUserProvider);
    final stats = ref.read(homeDashboardProvider);
    final points = ref.read(ecoTotalPointsProvider);
    final companionName = ref.read(companionNameProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryContainer,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Eco Student',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'student@campus.edu',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.inkSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$points',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EcoPoints',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.inkSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    Column(
                      children: [
                        Text(
                          stats.levelTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level ${stats.level}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.inkSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    Column(
                      children: [
                        Text(
                          companionName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Companion',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.inkSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                ),
                title: const Text(
                  'Edit Display Name',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showEditDisplayNameDialog(context, profile?.displayName ?? '');
                },
              ),
              const Divider(color: AppColors.borderLight, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pets_rounded, size: 20, color: AppColors.primary),
                ),
                title: const Text(
                  'Rename Companion',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _showRenameCompanionSheet(context, companionName);
                },
              ),
              const Divider(color: AppColors.borderLight, height: 1),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.severityCritical, size: 18),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.severityCritical,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.severityCritical.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await _confirmSignOut(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDisplayNameDialog(BuildContext context, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Update Display Name', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
                if (v.trim().length < 2) return 'Must be at least 2 characters';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newName = nameCtrl.text.trim();
                  try {
                    await ref
                        .read(userProfileProvider.notifier)
                        .updateDisplayName(newName);
                    if (context.mounted) {
                      Navigator.of(dlgCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Display name updated to $newName!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final errorMsg = e.toString().contains('permission denied') ||
                              e.toString().contains('42501')
                          ? 'Permission denied in database. Please run the Supabase migration to grant UPDATE on public.profiles.'
                          : 'Failed to update display name: $e';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: AppColors.severityCritical,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatIssueLocation(ReportModel issue) {
    if (issue.location.floor.isNotEmpty && issue.location.area.isNotEmpty) {
      return '${issue.location.building} · ${issue.location.floor} ${issue.location.area}';
    } else if (issue.location.area.isNotEmpty) {
      return '${issue.location.building} · ${issue.location.area}';
    } else if (issue.location.floor.isNotEmpty) {
      return '${issue.location.building} · ${issue.location.floor}';
    }
    return issue.location.building;
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      return '$h ${h == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays < 7) {
      final d = difference.inDays;
      return '$d ${d == 1 ? "day" : "days"} ago';
    } else {
      return DateFormat('d MMM').format(dt);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out of EcoCampus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.severityCritical,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(ecoTotalPointsProvider);
    final reportsAsync = ref.watch(myReportsProvider);
    final campusAsync = ref.watch(campusReportsProvider);
    final nearbyIssues = ref.watch(nearbyReportsProvider);
    final companionName = ref.watch(companionNameProvider);
    final greeting = ref.watch(greetingProvider);
    final stats = ref.watch(homeDashboardProvider);
    final profile = ref.watch(userProfileProvider).value;
    final todayStr = _kHomeDateFormat.format(DateTime.now());

    final displayName = profile?.displayName != null && profile!.displayName!.trim().isNotEmpty
        ? profile.displayName!.trim()
        : 'Aryan';

    final double scaffoldBottomPadding = MediaQuery.paddingOf(context).bottom;
    final double hardwareBottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // When hosted inside MainNavigationShell's Scaffold(extendBody: true),
    // Scaffold automatically includes the bottomNavigationBar height in MediaQuery.paddingOf(context).bottom.
    // To prevent duplicating this inset, we use the Scaffold-provided bottom padding directly if available,
    // or fallback to CustomBottomNavBar.totalHeight(context) if tested standalone without a parent Scaffold.
    final double navBarHeight = scaffoldBottomPadding > hardwareBottomInset
        ? scaffoldBottomPadding
        : CustomBottomNavBar.totalHeight(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF8F2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Campus Illustrated Background Image at top with smooth fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/home/campus_header_background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const _CampusHeaderAtmosphere(),
                ),
                // 1b. Natural, continuous flying birds in campus sky
                const _AnimatedCampusSkyBirds(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFEAF8F2).withValues(alpha: 0.0),
                          const Color(0xFFEAF8F2),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Decorative Bottom Foliage behind navigation
          Positioned(
            left: -12,
            bottom: 30,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/home/decorative_leaves.png',
                width: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            right: -12,
            bottom: 30,
            child: IgnorePointer(
              child: Transform.flip(
                flipX: true,
                child: Image.asset(
                  'assets/images/home/decorative_leaves.png',
                  width: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // 3. Main Scrollable Content:
          // Strictly constrained so its viewport ends at the upper boundary of CustomBottomNavBar.
          // Content scrolls naturally and clips cleanly at the boundary without passing behind the nav.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: navBarHeight,
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header Row with Greeting, EcoPoints, Notification Bell, and Profile
                      _buildTopHeader(context, greeting, displayName, todayStr, points),

                      const SizedBox(height: 12),

                      // Compact Announcements Section (surfaces latest published/urgent notice)
                      const NoticeBannerCard(),

                      // Illustrated Campus Hero Banner with mascot and interactive report capsule
                      _buildHeroBanner(context, companionName),

                      const SizedBox(height: 12),

                      // Eco Score & Level Cards
                      _buildStatsCards(context, stats, points),

                      const SizedBox(height: 14),

                      // Primary Report CTA Button
                      _buildPrimaryReportButton(context),

                      const SizedBox(height: 20),

                      // Nearby Issues Section
                      _buildNearbySection(context, campusAsync, reportsAsync, nearbyIssues),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    String greeting,
    String displayName,
    String todayStr,
    int points,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting & Date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF092F25),
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    ',',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF092F25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '$displayName 👋',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF092F25),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                todayStr,
                style: const TextStyle(
                  color: Color(0xFF5A7266),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),

        // EcoPoints Pill, Notification Bell, and Profile Button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // EcoPoints Pill
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onNavigateToRewards,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        size: 16,
                        color: Color(0xFF1EA05A),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$points',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF092F25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Notification Bell Button
            const NotificationBellButton(),
            const SizedBox(width: 6),

            // Profile Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showProfileSheet(context),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: Color(0xFF064E3B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroBanner(BuildContext context, String companionName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFC7F3DD),
            Color(0xFFD8F7E8),
            Color(0xFFE2FAF0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Content Layout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Companion Name Badge
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showRenameCompanionSheet(context, companionName),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            companionName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Color(0xFF092F25),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: Color(0xFF5A7266),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Left Headline & Subtitle Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spotted something on campus?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF092F25),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            "Snap it, I'll sort the rest!",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF235347),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spacer for mascot
                    const SizedBox(width: 135),
                  ],
                ),

                const SizedBox(height: 14),

                // Report Search Box / Entry Launcher
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToReportIssue,
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Dark green camera circle
                          Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF064E3B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Placeholder
                          const Expanded(
                            child: Text(
                              'Describe the issue or add a photo...',
                              style: TextStyle(
                                color: Color(0xFF728F81),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Microphone icon
                          const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.mic_none_rounded,
                              color: Color(0xFF4A685B),
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Peeking Mascot & Speech Bubble on the right with natural eye-blinking and rotating decorative leaves/stars
          Positioned(
            right: 8,
            top: 5,
            child: _AnimatedHeroMascot(
              tipIndex: _tipIndex,
              onCycleTip: _cycleTip,
              tips: _kCompanionTips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context, HomeDashboardStats stats, int points) {
    return Row(
      children: [
        // 1. Eco Score Card
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showEcoScoreDetails(context, stats, points),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F7EE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 14,
                            color: Color(0xFF1EA05A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Eco Score',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF092F25),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFF8FA499),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$points',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF092F25),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 7,
                        color: const Color(0xFFE5EFE9),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: stats.levelProgress > 0.0
                              ? stats.levelProgress.clamp(0.04, 1.0)
                              : (points > 0 ? ((points % 100) / 100.0).clamp(0.04, 1.0) : 0.0),
                          child: Container(
                            color: const Color(0xFF064E3B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 2. Level Card
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showLevelDetails(context, stats, points),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative corner leaf watermark
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Image.asset(
                        'assets/images/home/level_leaf_decoration.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => CustomPaint(
                          size: const Size(44, 44),
                          painter: _LeafWatermarkPainter(),
                        ),
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFDF4E7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFD98327),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Level',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF092F25),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: Color(0xFF8FA499),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${stats.level}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF092F25),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                stats.levelTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF092F25),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Report more issues to level up!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7A9487),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryReportButton(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _navigateToReportIssue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: const Color(0xFF064E3B).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Report an issue',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                // Sparkle rays
                CustomPaint(
                  size: const Size(18, 18),
                  painter: _BurstRaysPainter(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(16, 8),
              painter: _FlourishLeafPainter(isLeft: true),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Under a minute · AI fills in the details',
                style: AppTextStyles.bodySmall.copyWith(
                  color: const Color(0xFF5A7266),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            CustomPaint(
              size: const Size(16, 8),
              painter: _FlourishLeafPainter(isLeft: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNearbySection(
    BuildContext context,
    AsyncValue<List<ReportModel>> campusAsync,
    AsyncValue<List<ReportModel>> reportsAsync,
    List<ReportModel> nearbyIssues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Heading Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 20,
                    color: Color(0xFF064E3B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Nearby issues',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: const Color(0xFF092F25),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onNavigateToReports,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View all',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: const Color(0xFF064E3B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF064E3B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Issue List or States
        if ((campusAsync.isLoading || reportsAsync.isLoading) &&
            !campusAsync.hasValue &&
            !reportsAsync.hasValue &&
            nearbyIssues.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF064E3B),
                ),
              ),
            ),
          ),
        ] else if (campusAsync.hasError && !campusAsync.hasValue && nearbyIssues.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: AppColors.severityCritical,
                ),
                const SizedBox(height: 10),
                Text(
                  'Unable to load campus issues',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pull down to refresh or check your connection.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ] else if (nearbyIssues.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: const Color(0xFF229A5B).withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
                Text(
                  'All clear nearby!',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No open issues around your current campus location.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Render genuine list of cards
          Column(
            children: [
              for (final issue in nearbyIssues)
                _buildIssueCard(context, issue),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIssueCard(BuildContext context, ReportModel issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => ReportDetailScreen(
                  reportId: issue.id,
                  initialReport: issue,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Issue Thumbnail (56x56)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: _buildIssueThumbnail(issue),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF092F25),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF8FA499),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _formatIssueLocation(issue),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF5A7266),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: Color(0xFF8FA499),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatTimeAgo(issue.createdAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF8FA499),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Severity Badge
                SeverityBadge(severity: issue.severity, compact: true),
                const SizedBox(width: 4),

                // Right Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF8FA499),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIssueThumbnail(ReportModel issue) {
    if (issue.imageUrl != null && issue.imageUrl!.trim().isNotEmpty) {
      return Image.network(
        issue.imageUrl!,
        fit: BoxFit.cover,
        cacheWidth: 168,
        cacheHeight: 168,
        errorBuilder: (_, __, ___) => _buildNeutralPlaceholder(issue),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFEAF5EF),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF064E3B)),
              ),
            ),
          );
        },
      );
    }
    return _buildNeutralPlaceholder(issue);
  }

  Widget _buildNeutralPlaceholder(ReportModel issue) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE5EFE9), Color(0xFFD6E5DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          color: const Color(0xFF7A9487),
          size: 22,
        ),
      ),
    );
  }
}

/// Custom painter for top campus scenery background (used as fallback).
class _CampusHeaderAtmosphere extends StatelessWidget {
  const _CampusHeaderAtmosphere();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CampusSkylinePainter(),
      size: Size.infinite,
    );
  }
}

class _CampusSkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sky Gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFD5F4E7),
          Color(0xFFE3F8EF),
          Color(0xFFEAF8F2),
        ],
        stops: [0.0, 0.6, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Pale Sun/Moon
    final sunCenter = Offset(w * 0.50, h * 0.36);
    final sunHalo = Paint()
      ..color = const Color(0xFFFFFDE0).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(sunCenter, 28, sunHalo);

    final sunDisk = Paint()..color = const Color(0xFFFFFEE5);
    canvas.drawCircle(sunCenter, 18, sunDisk);

    // 3. Flying birds in sky (handled dynamically by _AnimatedCampusSkyBirds)

    // 4. Academic Building Facade (Right Side)
    final buildingLeft = w * 0.42;
    final buildingRight = w * 0.95;
    final buildingTop = h * 0.40;
    final buildingBottom = h * 0.88;

    final buildingPaint = Paint()..color = const Color(0xFFE2EFE7);
    canvas.drawRect(
      Rect.fromLTRB(buildingLeft, buildingTop, buildingRight, buildingBottom),
      buildingPaint,
    );

    // Building Roof Parapet
    final roofPaint = Paint()..color = const Color(0xFFD4E6DC);
    canvas.drawRect(
      Rect.fromLTRB(buildingLeft - 4, buildingTop - 6, buildingRight + 4, buildingTop),
      roofPaint,
    );

    // Architectural Pillars & Windows
    final pillarPaint = Paint()..color = const Color(0xFFD6EAE0);
    final windowPaint = Paint()..color = const Color(0xFFC7DDD1);

    const int cols = 5;
    final colWidth = (buildingRight - buildingLeft) / cols;

    for (int i = 0; i < cols; i++) {
      final colX = buildingLeft + (i * colWidth);
      canvas.drawRect(Rect.fromLTWH(colX + 2, buildingTop + 10, colWidth * 0.65, 14), windowPaint);
      canvas.drawRect(Rect.fromLTWH(colX + 2, buildingTop + 32, colWidth * 0.65, 16), windowPaint);
      canvas.drawRect(Rect.fromLTWH(colX + 2, buildingTop + 56, colWidth * 0.65, 16), windowPaint);
      canvas.drawRect(Rect.fromLTWH(colX + colWidth - 2, buildingTop, 2, buildingBottom - buildingTop), pillarPaint);
    }

    // 5. Classic Campus Streetlamps
    _drawStreetLamp(canvas, Offset(w * 0.385, h * 0.45), h * 0.42);
    _drawStreetLamp(canvas, Offset(w * 0.875, h * 0.48), h * 0.38);

    // 6. Lush Campus Trees (Layered in Depth)
    _drawTree(canvas, Offset(w * 0.28, h * 0.68), 34, const Color(0xFF5BAA80));
    _drawTree(canvas, Offset(w * 0.92, h * 0.72), 30, const Color(0xFF5BAA80));

    _drawTree(canvas, Offset(w * 0.16, h * 0.72), 38, const Color(0xFF389764));
    _drawTree(canvas, Offset(w * 0.33, h * 0.76), 36, const Color(0xFF2E8C58));
    _drawTree(canvas, Offset(w * 0.72, h * 0.78), 34, const Color(0xFF389764));

    _drawTree(canvas, Offset(w * 0.05, h * 0.78), 44, const Color(0xFF1E7545));
    _drawTree(canvas, Offset(w * 0.22, h * 0.82), 40, const Color(0xFF1B6E40));
    _drawTree(canvas, Offset(w * 0.96, h * 0.82), 36, const Color(0xFF1B6E40));
  }

  void _drawStreetLamp(Canvas canvas, Offset top, double height) {
    final postPaint = Paint()
      ..color = const Color(0xFF1F382E)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(top, Offset(top.dx, top.dy + height), postPaint);

    final basePaint = Paint()..color = const Color(0xFF1F382E);
    canvas.drawRect(Rect.fromLTWH(top.dx - 3, top.dy + height - 4, 6, 4), basePaint);

    final lanternPaint = Paint()..color = const Color(0xFF1F382E);
    canvas.drawRect(Rect.fromLTWH(top.dx - 3.5, top.dy - 6, 7, 7), lanternPaint);

    final glowPaint = Paint()..color = const Color(0xFFFFF9D2);
    canvas.drawRect(Rect.fromLTWH(top.dx - 2, top.dy - 4.5, 4, 4), glowPaint);
  }

  void _drawTree(Canvas canvas, Offset center, double radius, Color color) {
    final treePaint = Paint()..color = color;
    canvas.drawCircle(center, radius, treePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - radius * 0.25, center.dy - radius * 0.25), radius * 0.55, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated birds soaring and gliding naturally across the top campus sky.
/// Features subtle wing-flapping, natural horizontal drift, gentle altitude variation,
/// and smooth infinite loop continuity with zero boundary hitch or snap.
class _AnimatedCampusSkyBirds extends StatefulWidget {
  const _AnimatedCampusSkyBirds();

  @override
  State<_AnimatedCampusSkyBirds> createState() => _AnimatedCampusSkyBirdsState();
}

class _AnimatedCampusSkyBirdsState extends State<_AnimatedCampusSkyBirds>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flightController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 14.0 second continuous linear flight loop
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_flightController.isAnimating) {
        _flightController.repeat();
      }
    } else {
      _flightController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flightController,
        builder: (context, _) {
          return CustomPaint(
            painter: _CampusSkyBirdsPainter(
              progress: disableAnimations ? 0.0 : _flightController.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CampusSkyBirdsPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 linear loop progress

  const _CampusSkyBirdsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Align with campus_header_background.png (322 x 145) under BoxFit.cover, topCenter
    final scale = math.max(w / 322.0, h / 145.0);
    final scaledW = 322.0 * scale;
    final imageLeft = (w - scaledW) / 2.0;

    final t = progress; // 0.0 -> 1.0 linear loop
    final twoPi = 2.0 * math.pi;

    // -------------------------------------------------------------
    // Bird 1: Leading bird (Left of sun in campus sky, size ~ 11.5)
    // Base in 322x145 image: X=131.0, Y=52.0
    // -------------------------------------------------------------
    final base1X = imageLeft + 131.0 * scale;
    final base1Y = 52.0 * scale;

    // Harmonic flight path with integer frequencies (k=1, 2)
    final dx1 = 18.0 * math.sin(twoPi * 1.0 * t) + 5.0 * math.sin(twoPi * 2.0 * t + 0.4);
    final dy1 = 4.5 * math.cos(twoPi * 1.0 * t) - 2.0 * math.cos(twoPi * 2.0 * t);

    // Approximate horizontal velocity for banking/tilt
    final vx1 = 18.0 * math.cos(twoPi * 1.0 * t) + 10.0 * math.cos(twoPi * 2.0 * t + 0.4);
    final vy1 = -4.5 * math.sin(twoPi * 1.0 * t) + 4.0 * math.sin(twoPi * 2.0 * t);
    final bank1 = (vy1 * 0.015).clamp(-0.12, 0.12) + (vx1 * 0.005).clamp(-0.08, 0.08);

    // Flap cycle: 4 complete flap cycles per 14s (k=4)
    final flapPhase1 = twoPi * 4.0 * t;
    final flapFactor1 = math.sin(flapPhase1);

    _drawFlappingBird(
      canvas: canvas,
      center: Offset(base1X + dx1, base1Y + dy1),
      wingSpan: 11.5 * (scale / 1.517),
      flapFactor: flapFactor1,
      bankAngle: bank1,
      color: const Color(0xFF5E8573),
      strokeWidth: 1.35,
    );

    // -------------------------------------------------------------
    // Bird 2: Middle-right bird (Below-right of sun, size ~ 9.0)
    // Base in 322x145 image: X=175.0, Y=58.0
    // -------------------------------------------------------------
    final base2X = imageLeft + 175.0 * scale;
    final base2Y = 58.0 * scale;

    // Independent drift in counter-cadence
    final dx2 = -15.0 * math.sin(twoPi * 1.0 * t + 1.2) - 4.0 * math.sin(twoPi * 2.0 * t + 1.8);
    final dy2 = 4.0 * math.sin(twoPi * 1.0 * t + 0.7) + 1.8 * math.sin(twoPi * 2.0 * t);

    final vx2 = -15.0 * math.cos(twoPi * 1.0 * t + 1.2) - 8.0 * math.cos(twoPi * 2.0 * t + 1.8);
    final vy2 = 4.0 * math.cos(twoPi * 1.0 * t + 0.7) + 3.6 * math.cos(twoPi * 2.0 * t);
    final bank2 = (vy2 * 0.018).clamp(-0.14, 0.14) + (vx2 * 0.006).clamp(-0.08, 0.08);

    // Flap cycle: 5 complete flap cycles per 14s (k=5)
    final flapPhase2 = twoPi * 5.0 * t + 1.5;
    final flapFactor2 = math.sin(flapPhase2);

    _drawFlappingBird(
      canvas: canvas,
      center: Offset(base2X + dx2, base2Y + dy2),
      wingSpan: 9.0 * (scale / 1.517),
      flapFactor: flapFactor2,
      bankAngle: bank2,
      color: const Color(0xFF5E8573),
      strokeWidth: 1.20,
    );

    // -------------------------------------------------------------
    // Bird 3: High-right bird (Upper-right sky, size ~ 8.0)
    // Base in 322x145 image: X=191.0, Y=47.0
    // -------------------------------------------------------------
    final base3X = imageLeft + 191.0 * scale;
    final base3Y = 47.0 * scale;

    // Playful higher-altitude soaring arc
    final dx3 = 12.0 * math.cos(twoPi * 1.0 * t + 2.1) + 3.5 * math.cos(twoPi * 2.0 * t + 0.8);
    final dy3 = -3.8 * math.sin(twoPi * 1.0 * t + 1.4) + 1.5 * math.cos(twoPi * 2.0 * t);

    final vx3 = -12.0 * math.sin(twoPi * 1.0 * t + 2.1) - 7.0 * math.sin(twoPi * 2.0 * t + 0.8);
    final vy3 = -3.8 * math.cos(twoPi * 1.0 * t + 1.4) - 3.0 * math.sin(twoPi * 2.0 * t);
    final bank3 = (vy3 * 0.018).clamp(-0.14, 0.14) + (vx3 * 0.006).clamp(-0.08, 0.08);

    // Flap cycle: 6 complete flap cycles per 14s (k=6)
    final flapPhase3 = twoPi * 6.0 * t + 2.8;
    final flapFactor3 = math.sin(flapPhase3);

    _drawFlappingBird(
      canvas: canvas,
      center: Offset(base3X + dx3, base3Y + dy3),
      wingSpan: 8.0 * (scale / 1.517),
      flapFactor: flapFactor3,
      bankAngle: bank3,
      color: const Color(0xFF6B9280),
      strokeWidth: 1.10,
    );
  }

  void _drawFlappingBird({
    required Canvas canvas,
    required Offset center,
    required double wingSpan,
    required double flapFactor,
    required double bankAngle,
    required Color color,
    required double strokeWidth,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (bankAngle != 0.0) {
      canvas.rotate(bankAngle);
    }

    final halfSpan = wingSpan / 2.0;

    // Wing arch and tip positions based on flap factor (-1.0 upstroke, +1.0 downstroke)
    final archY = -halfSpan * (0.38 - 0.20 * flapFactor);
    final tipY = halfSpan * (0.22 + 0.32 * flapFactor);
    final bodyY = halfSpan * (0.06 * flapFactor);

    final path = Path()
      ..moveTo(-halfSpan, tipY)
      ..quadraticBezierTo(-halfSpan * 0.45, archY, 0.0, bodyY)
      ..quadraticBezierTo(halfSpan * 0.45, archY, halfSpan, tipY);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CampusSkyBirdsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Animated Mascot for the Home Hero banner.
/// Supports natural eye-blinking (randomized 3-6s interval, 140ms duration)
/// and continuous elliptical orbital revolution of decorative leaves and sparkle stars
/// around the stationary mascot body.
class _AnimatedHeroMascot extends StatefulWidget {
  final ValueListenable<int> tipIndex;
  final VoidCallback onCycleTip;
  final List<String> tips;

  const _AnimatedHeroMascot({
    required this.tipIndex,
    required this.onCycleTip,
    required this.tips,
  });

  @override
  State<_AnimatedHeroMascot> createState() => _AnimatedHeroMascotState();
}

class _AnimatedHeroMascotState extends State<_AnimatedHeroMascot>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _blinkController;
  late final AnimationController _orbitController;
  final math.Random _random = math.Random();
  Timer? _blinkTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Eye blinking animation: 140ms duration (smooth close and reopen)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    // Continuous orbital revolution of leaves and stars around the mascot: 12.0s smooth loop
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();

    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    if (_isDisposed || !mounted) return;

    // Random interval between 3 and 6 seconds (3000ms - 6000ms)
    final nextIntervalMs = 3000 + _random.nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: nextIntervalMs), _performBlink);
  }

  void _performBlink() {
    if (_isDisposed || !mounted) return;

    // Respect reduced-motion preferences
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _scheduleNextBlink();
      return;
    }

    _blinkController.forward().then((_) {
      if (_isDisposed || !mounted) return;
      _blinkController.reverse().then((_) {
        if (_isDisposed || !mounted) return;
        // ~20% chance of a quick, natural double-blink
        if (_random.nextDouble() < 0.20) {
          _blinkTimer?.cancel();
          _blinkTimer = Timer(const Duration(milliseconds: 90), () {
            if (_isDisposed || !mounted) return;
            _blinkController.forward().then((_) {
              if (_isDisposed || !mounted) return;
              _blinkController.reverse().then((_) => _scheduleNextBlink());
            });
          });
        } else {
          _scheduleNextBlink();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_orbitController.isAnimating) {
        _orbitController.repeat();
      }
      _scheduleNextBlink();
    } else {
      _orbitController.stop();
      _blinkTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _blinkTimer?.cancel();
    _blinkController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Orbit center relative to the 128 x 118 mascot stage:
    // Aligned to the mascot's round body center
    const double centerX = 65.0;
    const double centerY = 64.0;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Speech Bubble with cycling tip
          GestureDetector(
            onTap: widget.onCycleTip,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
              constraints: const BoxConstraints(maxWidth: 125),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: widget.tipIndex,
                builder: (context, tipIdx, _) {
                  final text = (tipIdx >= 0 && tipIdx < widget.tips.length)
                      ? widget.tips[tipIdx]
                      : widget.tips.first;
                  return Text(
                    text,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF092F25),
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),

          // 2. Mascot Character with Layered Orbiting Leaves & Stars, and Smooth Eye Blinking
          GestureDetector(
            onTap: widget.onCycleTip,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 128,
              height: 118,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // --- LAYER 1 (BEHIND MASCOT): Orbiting decorative leaves and sparkle stars ---
                  AnimatedBuilder(
                    animation: _orbitController,
                    builder: (context, _) {
                      final progress = reduceMotion ? 0.0 : _orbitController.value;

                      // Element 1: Authentic Left Floating Leaf (size 18x18)
                      // Orbits counter-clockwise at 1 turn per cycle (Rx=56, Ry=44)
                      final theta1 = (progress * 2 * math.pi * 1.0) + 0.0;
                      final leaf1X = centerX + 56.0 * math.cos(theta1) - 9.0;
                      final leaf1Y = centerY + 44.0 * math.sin(theta1) - 9.0;
                      final leaf1Rot = reduceMotion ? 0.0 : (theta1 + 0.35);

                      // Element 2: Authentic Right Floating Leaf (size 16x19)
                      // Orbits counter-clockwise at 1 turn per cycle, opposite phase (Rx=52, Ry=40)
                      final theta2 = (progress * 2 * math.pi * 1.0) + math.pi;
                      final leaf2X = centerX + 52.0 * math.cos(theta2) - 8.0;
                      final leaf2Y = centerY + 40.0 * math.sin(theta2) - 9.5;
                      final leaf2Rot = reduceMotion ? 0.0 : (theta2 - 0.40);

                      // Element 3: Golden Star 1 (Large 16x16)
                      // Orbits clockwise at 1 turn per cycle (Rx=60, Ry=48)
                      final theta3 = -(progress * 2 * math.pi * 1.0) + 2.1;
                      final star1X = centerX + 60.0 * math.cos(theta3) - 8.0;
                      final star1Y = centerY + 48.0 * math.sin(theta3) - 8.0;
                      final star1Scale = reduceMotion ? 1.0 : (1.0 + 0.08 * math.cos(theta3 * 2));
                      final star1Rot = reduceMotion ? 0.0 : (0.15 * math.sin(theta3));

                      // Element 4: Golden Star 2 (Medium 14x14)
                      // Orbits counter-clockwise at 1 turn per cycle (Rx=48, Ry=36)
                      final theta4 = (progress * 2 * math.pi * 1.0) + 4.4;
                      final star2X = centerX + 48.0 * math.cos(theta4) - 7.0;
                      final star2Y = centerY + 36.0 * math.sin(theta4) - 7.0;
                      final star2Scale = reduceMotion ? 1.0 : (1.0 + 0.07 * math.sin(theta4 * 2));
                      final star2Rot = reduceMotion ? 0.0 : (-0.14 * math.cos(theta4));

                      // Element 5: Golden Star 3 (Small 12x12)
                      // Orbits clockwise at 2 turns per cycle (Rx=58, Ry=42)
                      final theta5 = -(progress * 2 * math.pi * 2.0) + 0.9;
                      final star3X = centerX + 58.0 * math.cos(theta5) - 6.0;
                      final star3Y = centerY + 42.0 * math.sin(theta5) - 6.0;
                      final star3Scale = reduceMotion ? 1.0 : (1.0 + 0.10 * math.cos(theta5 * 2));
                      final star3Rot = reduceMotion ? 0.0 : (0.12 * math.sin(theta5 * 2));

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Orbiting Floating Leaf 1
                          Positioned(
                            left: leaf1X,
                            top: leaf1Y,
                            child: Transform.rotate(
                              angle: leaf1Rot,
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/home/floating_leaf_1.png',
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const CustomPaint(
                                  size: Size(18, 18),
                                  painter: _MascotBehindLeavesPainter(),
                                ),
                              ),
                            ),
                          ),

                          // 2. Orbiting Floating Leaf 2
                          Positioned(
                            left: leaf2X,
                            top: leaf2Y,
                            child: Transform.rotate(
                              angle: leaf2Rot,
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/home/floating_leaf_2.png',
                                width: 16,
                                height: 19,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const CustomPaint(
                                  size: Size(16, 19),
                                  painter: _MascotBehindLeavesPainter(),
                                ),
                              ),
                            ),
                          ),

                          // 3. Orbiting Star 1 (Large)
                          Positioned(
                            left: star1X,
                            top: star1Y,
                            child: Transform.rotate(
                              angle: star1Rot,
                              alignment: Alignment.center,
                              child: Transform.scale(
                                scale: star1Scale,
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/images/home/sparkle_star.png',
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const CustomPaint(
                                    size: Size(16, 16),
                                    painter: _SparkleStarPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 4. Orbiting Star 2 (Medium)
                          Positioned(
                            left: star2X,
                            top: star2Y,
                            child: Transform.rotate(
                              angle: star2Rot,
                              alignment: Alignment.center,
                              child: Transform.scale(
                                scale: star2Scale,
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/images/home/sparkle_star.png',
                                  width: 14,
                                  height: 14,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const CustomPaint(
                                    size: Size(14, 14),
                                    painter: _SparkleStarPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 5. Orbiting Star 3 (Small)
                          Positioned(
                            left: star3X,
                            top: star3Y,
                            child: Transform.rotate(
                              angle: star3Rot,
                              alignment: Alignment.center,
                              child: Transform.scale(
                                scale: star3Scale,
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'assets/images/home/sparkle_star.png',
                                  width: 12,
                                  height: 12,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const CustomPaint(
                                    size: Size(12, 12),
                                    painter: _SparkleStarPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // --- LAYER 2: Stationary Mascot with natural eye-blinking (rendered ON TOP of orbiting elements) ---
                  Positioned(
                    left: 5,
                    top: 0,
                    width: 118,
                    height: 118,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedBuilder(
                          animation: _blinkController,
                          builder: (context, _) {
                            final blinkProgress = reduceMotion ? 0.0 : _blinkController.value;
                            return Image.asset(
                              'assets/images/home/eco_mascot.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => CustomPaint(
                                painter: _PeekingMascotPainter(blinkProgress: blinkProgress),
                              ),
                            );
                          },
                        ),

                        // Natural eye-blinking overlay: Smooth eyelid descent & opening (Proportionally scaled)
                        AnimatedBuilder(
                          animation: _blinkController,
                          builder: (context, _) {
                            final p = reduceMotion ? 0.0 : _blinkController.value;
                            if (p <= 0.005) return const SizedBox.shrink();
                            return CustomPaint(
                              painter: _MascotEyelidPainter(progress: p),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Precise eyelid overlay painter for natural smooth blinking.
class _MascotEyelidPainter extends CustomPainter {
  final double progress; // 0.0 = fully open, 1.0 = fully closed

  const _MascotEyelidPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.005) return;

    final sx = size.width / 178.0;
    final sy = size.height / 172.0;

    final leftCenter = Offset(72.5 * sx, 100.5 * sy);
    final leftRect = Rect.fromCenter(
      center: leftCenter,
      width: 38.0 * sx,
      height: 30.5 * sy,
    );

    final rightCenter = Offset(112.0 * sx, 89.0 * sy);
    final rightRect = Rect.fromCenter(
      center: rightCenter,
      width: 37.0 * sx,
      height: 29.5 * sy,
    );

    // Mascot face skin gradient colors
    final skinPaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFF62E08F),
          Color(0xFF36CA82),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 40 * sy, size.width, 35 * sy))
      ..style = PaintingStyle.fill;

    _paintEyeBlink(canvas, leftRect, progress, skinPaint, sx);
    _paintEyeBlink(canvas, rightRect, progress, skinPaint, sx);
  }

  void _paintEyeBlink(Canvas canvas, Rect eyeRect, double p, Paint skinPaint, double sx) {
    canvas.save();
    // Clip strictly to the eye socket opening
    canvas.clipPath(Path()..addOval(eyeRect));

    // The upper eyelid smoothly descends from the top of the eye downward
    final currentEyelidBottom = eyeRect.top + eyeRect.height * p;
    final eyelidRect = Rect.fromLTRB(
      eyeRect.left - 2,
      eyeRect.top - 2,
      eyeRect.right + 2,
      currentEyelidBottom,
    );
    canvas.drawRect(eyelidRect, skinPaint);
    canvas.restore();

    // When nearly closed, draw the delicate closed lash curve
    if (p > 0.45) {
      final lashAlpha = ((p - 0.45) / 0.55).clamp(0.0, 1.0);
      final lashPaint = Paint()
        ..color = const Color(0xFF0C2B1C).withValues(alpha: lashAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (sx / (105.0 / 178.0))
        ..strokeCap = StrokeCap.round;

      final lashY = eyeRect.top + eyeRect.height * (0.45 + 0.15 * p);
      final lashPath = Path()
        ..moveTo(eyeRect.left + 1.5, lashY)
        ..quadraticBezierTo(
          eyeRect.center.dx,
          lashY + 4.5,
          eyeRect.right - 1.5,
          lashY - 0.5,
        );
      canvas.drawPath(lashPath, lashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MascotEyelidPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Decorative 4-point golden sparkle star painter with soft radial gradient.
class _SparkleStarPainter extends CustomPainter {
  const _SparkleStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final sizeR = w * 0.48;
    const color = Color(0xFFFFD54F);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          color,
          color.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: sizeR))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - sizeR)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + sizeR, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + sizeR)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - sizeR, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - sizeR);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small fresh leaf cluster painter peeking from behind the mascot.
class _MascotBehindLeavesPainter extends CustomPainter {
  const _MascotBehindLeavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leafPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF5BE395), Color(0xFF28B568)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(w * 0.5, h)
      ..cubicTo(0, h * 0.6, 0, h * 0.1, w * 0.5, 0)
      ..cubicTo(w, h * 0.1, w, h * 0.6, w * 0.5, h);
    canvas.drawPath(path, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for the cute peeking mascot on the hero banner (used as fallback).
class _PeekingMascotPainter extends CustomPainter {
  final double blinkProgress;
  _PeekingMascotPainter({this.blinkProgress = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.52, h * 0.60);
    final radius = w * 0.36;

    // 1. Sprout leaves at top
    final leafPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF5BE395), Color(0xFF32C272)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.36, h * 0.05, w * 0.32, h * 0.35))
      ..style = PaintingStyle.fill;

    // Stem
    final stemPath = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..quadraticBezierTo(center.dx, h * 0.24, center.dx - 2, h * 0.16);
    final stemPaint = Paint()
      ..color = const Color(0xFF2CA860)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stemPath, stemPaint);

    // Left leaf
    final leftLeaf = Path()
      ..moveTo(center.dx - 2, h * 0.18)
      ..cubicTo(w * 0.34, h * 0.12, w * 0.36, h * 0.02, w * 0.48, h * 0.04)
      ..cubicTo(center.dx, h * 0.08, center.dx, h * 0.15, center.dx - 2, h * 0.18);
    canvas.drawPath(leftLeaf, leafPaint);

    // Right leaf
    final rightLeaf = Path()
      ..moveTo(center.dx - 2, h * 0.18)
      ..cubicTo(w * 0.66, h * 0.10, w * 0.70, h * 0.01, w * 0.56, h * 0.02)
      ..cubicTo(center.dx, h * 0.07, center.dx, h * 0.15, center.dx - 2, h * 0.18);
    canvas.drawPath(rightLeaf, leafPaint);

    // 2. Main round green body
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.3),
        radius: 0.9,
        colors: [
          Color(0xFF6AEFA5),
          Color(0xFF38CC85),
          Color(0xFF1EA864),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bodyPaint);

    // 3. Cute blush cheeks
    final blushPaint = Paint()..color = const Color(0xFFFF94A8).withValues(alpha: 0.42);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - radius * 0.58, center.dy + radius * 0.18), width: 14, height: 8),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + radius * 0.58, center.dy + radius * 0.18), width: 14, height: 8),
      blushPaint,
    );

    // 4. Large Sparkling Anime Eyes
    final openFactor = (1.0 - blinkProgress * 0.95).clamp(0.05, 1.0);
    final eyeRadiusX = radius * 0.25;
    final eyeRadiusY = radius * 0.32 * openFactor;
    final leftEye = Offset(center.dx - radius * 0.36, center.dy - radius * 0.02);
    final rightEye = Offset(center.dx + radius * 0.36, center.dy - radius * 0.02);

    final eyeWhite = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: leftEye, width: eyeRadiusX * 2, height: eyeRadiusY * 2), eyeWhite);
    canvas.drawOval(Rect.fromCenter(center: rightEye, width: eyeRadiusX * 2, height: eyeRadiusY * 2), eyeWhite);

    final pupilPaint = Paint()..color = const Color(0xFF0C2B1C);
    canvas.drawOval(Rect.fromCenter(center: leftEye, width: eyeRadiusX * 1.7, height: eyeRadiusY * 1.8), pupilPaint);
    canvas.drawOval(Rect.fromCenter(center: rightEye, width: eyeRadiusX * 1.7, height: eyeRadiusY * 1.8), pupilPaint);

    if (blinkProgress <= 0.5) {
      // Center sparkling stars in pupils
      _drawSparkle(canvas, Offset(leftEye.dx - 1, leftEye.dy - 2), 4.5, Colors.white);
      _drawSparkle(canvas, Offset(rightEye.dx - 1, rightEye.dy - 2), 4.5, Colors.white);

      // Extra mini shines
      canvas.drawCircle(Offset(leftEye.dx + 3, leftEye.dy + 3), 1.5, eyeWhite);
      canvas.drawCircle(Offset(rightEye.dx + 3, rightEye.dy + 3), 1.5, eyeWhite);
    } else {
      // Draw closed eye line on fallback painter
      final lashPaint = Paint()
        ..color = const Color(0xFF0C2B1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: leftEye, width: eyeRadiusX * 1.6, height: eyeRadiusX * 1.0),
        0.1,
        math.pi - 0.2,
        false,
        lashPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: rightEye, width: eyeRadiusX * 1.6, height: eyeRadiusX * 1.0),
        0.1,
        math.pi - 0.2,
        false,
        lashPaint,
      );
    }

    // 5. Cheerful smile
    final mouthPaint = Paint()
      ..color = const Color(0xFF0F3E28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(center.dx - radius * 0.14, center.dy + radius * 0.16)
      ..quadraticBezierTo(center.dx, center.dy + radius * 0.28, center.dx + radius * 0.14, center.dy + radius * 0.16);
    canvas.drawPath(mouthPath, mouthPaint);

    // 6. Cute paws resting/peeking
    final pawPaint = Paint()..color = const Color(0xFF26B26E);
    canvas.drawCircle(Offset(center.dx - radius * 0.72, center.dy + radius * 0.65), 7, pawPaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.72, center.dy + radius * 0.65), 7, pawPaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PeekingMascotPainter oldDelegate) =>
      oldDelegate.blinkProgress != blinkProgress;
}

/// Translucent leaf motif painter for the Level card corner (fallback).
class _LeafWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFE8D0).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.2, h * 0.9)
      ..cubicTo(w * 0.1, h * 0.4, w * 0.6, h * 0.05, w * 0.95, h * 0.1)
      ..cubicTo(w * 0.9, h * 0.6, w * 0.6, h * 0.9, w * 0.2, h * 0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sparkle rays on the Report CTA button.
class _BurstRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w * 0.2, h * 0.3), Offset(w * 0.4, h * 0.4), paint);
    canvas.drawLine(Offset(w * 0.5, h * 0.1), Offset(w * 0.55, h * 0.35), paint);
    canvas.drawLine(Offset(w * 0.8, h * 0.3), Offset(w * 0.65, h * 0.45), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Leaf flourishes beside the CTA subtitle.
class _FlourishLeafPainter extends CustomPainter {
  final bool isLeft;
  const _FlourishLeafPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8FA499)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final path = Path();
    if (isLeft) {
      path.moveTo(w, h * 0.5);
      path.quadraticBezierTo(w * 0.5, 0, 0, h * 0.5);
    } else {
      path.moveTo(0, h * 0.5);
      path.quadraticBezierTo(w * 0.5, 0, w, h * 0.5);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlourishLeafPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft;
}
