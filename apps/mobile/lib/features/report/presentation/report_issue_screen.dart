import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sprig_mascot.dart';
import '../data/reports_provider.dart';
import '../domain/report_model.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  IssueCategory _selectedCategory = IssueCategory.waste;
  IssueSeverity _selectedSeverity = IssueSeverity.medium;
  
  CampusLocation _selectedLocation = const CampusLocation(
    building: 'Block B',
    floor: 'Ground Floor',
    area: 'Cafeteria Entrance',
  );

  bool _isSubmitting = false;

  final List<String> _buildings = ['Block A', 'Block B', 'Library', 'Canteen', 'Sports Complex'];
  final Map<String, List<String>> _floors = {
    'Block A': ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor'],
    'Block B': ['Ground Floor', '1st Floor', '2nd Floor'],
    'Library': ['Ground Floor', '1st Floor', 'Mezzanine'],
    'Canteen': ['Ground Floor'],
    'Sports Complex': ['Ground Floor', 'Upper Deck'],
  };
  final Map<String, List<String>> _areas = {
    'Ground Floor': ['Cafeteria Entrance', 'Lobby', 'East Corridor', 'Washroom 101'],
    '1st Floor': ['Hallway A', 'Lab 102', 'Faculty Lounge'],
    '2nd Floor': ['Room 204', 'Lecture Theatre 2', 'Balcony'],
    '3rd Floor': ['Research Wing', 'Terrace'],
    'Mezzanine': ['Reading Area', 'Silent Study'],
    'Upper Deck': ['Gym Area', 'Viewing Gallery'],
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Overflowing waste bin');
    _descController = TextEditingController(
      text: 'Recycling bin overflowing near east patio with food containers spilled.',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submitReport() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final newReport = ReportModel(
      id: 'REP-2026-${const Uuid().v4().substring(0, 4).toUpperCase()}',
      title: _titleController.text.trim().isEmpty ? 'Reported Issue' : _titleController.text.trim(),
      category: _selectedCategory,
      severity: _selectedSeverity,
      location: _selectedLocation,
      status: ReportStatus.reported,
      createdAt: DateTime.now(),
      description: _descController.text.trim(),
      department: _getSuggestedDepartment(_selectedCategory),
      aiConfidence: 0.96,
      distanceMeters: 5,
    );

    ref.read(reportsProvider.notifier).addReport(newReport);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    _showSuccessReceiptDialog(newReport);
  }

  String _getSuggestedDepartment(IssueCategory category) {
    switch (category) {
      case IssueCategory.waste:
        return 'Sanitation & Grounds';
      case IssueCategory.water:
        return 'Plumbing & Facilities';
      case IssueCategory.electricity:
        return 'Electrical Maintenance';
      case IssueCategory.infrastructure:
        return 'Campus Infrastructure';
      case IssueCategory.greenery:
        return 'Horticulture & Landscape';
      case IssueCategory.cleanliness:
        return 'Housekeeping';
      case IssueCategory.other:
        return 'General Operations';
    }
  }

  void _showSuccessReceiptDialog(ReportModel report) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFD6F2E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Report Added',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tracking ID: ${report.id}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              Text(
                'This report is currently stored only in the app session. Supabase submission and campus-team notifications are not connected yet.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPickerModal() {
    String tempBuilding = _selectedLocation.building;
    String tempFloor = _selectedLocation.floor;
    String tempArea = _selectedLocation.area;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final floorList = _floors[tempBuilding] ?? ['Ground Floor'];
          if (!floorList.contains(tempFloor)) {
            tempFloor = floorList.first;
          }
          final areaList = _areas[tempFloor] ?? ['Main Entrance'];
          if (!areaList.contains(tempArea)) {
            tempArea = areaList.first;
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Location',
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Campus hierarchy: Building → Floor → Area (PRD §7.6)',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  // Building Dropdown
                  Text('Building', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: tempBuilding,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _buildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          tempBuilding = val;
                          tempFloor = _floors[val]!.first;
                          tempArea = _areas[tempFloor]!.first;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Floor Dropdown
                  Text('Floor', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: tempFloor,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: floorList.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          tempFloor = val;
                          tempArea = _areas[val]?.first ?? 'Main Area';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Area Dropdown
                  Text('Area / Room', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: tempArea,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: areaList.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => tempArea = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedLocation = CampusLocation(
                            building: tempBuilding,
                            floor: tempFloor,
                            area: tempArea,
                          );
                        });
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text('Confirm Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.inkPrimary),
            ),
          ),
        ),
        title: Text(
          'Report issue',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Photo Viewfinder Card
            _buildViewfinderCard(),

            const SizedBox(height: 16),

            // 2. Mascot Analysis Status Row
            _buildAnalysisStatusRow(),

            const SizedBox(height: 16),

            // 3. Form Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF144D37).withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Issue Label & Editable Field
                  Text(
                    'Issue',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _titleController,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        suffixIcon: Icon(Icons.edit_outlined, size: 18, color: AppColors.inkSecondary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Category Selector Chips
                  Text(
                    'Category',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip(IssueCategory.waste),
                        const SizedBox(width: 8),
                        _buildCategoryChip(IssueCategory.water),
                        const SizedBox(width: 8),
                        _buildCategoryChip(IssueCategory.electricity),
                        const SizedBox(width: 8),
                        _buildCategoryChip(IssueCategory.greenery),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Severity Segmented Selector
                  Text(
                    'Severity',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildSeverityOption(IssueSeverity.low, AppColors.severityLow)),
                        Expanded(child: _buildSeverityOption(IssueSeverity.medium, AppColors.severityMedium)),
                        Expanded(child: _buildSeverityOption(IssueSeverity.high, AppColors.severityHigh)),
                        Expanded(child: _buildSeverityOption(IssueSeverity.critical, AppColors.severityCritical)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Location Card (Building -> Floor -> Area)
                  Text(
                    'Location',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showLocationPickerModal,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD6F2E3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedLocation.building} · ${_selectedLocation.floor}',
                                  style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedLocation.area,
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit without claiming unimplemented EcoPoints rewards
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Submit report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinderCard() {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF9FB6C4),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Simulated photo content: Green waste bin with items
          Center(
            child: Container(
              width: 140,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF288B5D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Overspill garbage on top
                  Positioned(
                    top: -24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTrashBubble(28, const Color(0xFFF6E58D)),
                        _buildTrashBubble(36, const Color(0xFFDFF9FB)),
                        _buildTrashBubble(32, const Color(0xFFF9CA24)),
                      ],
                    ),
                  ),
                  // Bin rim
                  Positioned(
                    top: 0,
                    left: -8,
                    right: -8,
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E6C47),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  // Bin front accent
                  Center(
                    child: Container(
                      width: 50,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38A16F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // White Viewfinder Brackets
          // Top-Left bracket
          Positioned(
            top: 24,
            left: 24,
            child: _buildCornerBracket(isTop: true, isLeft: true),
          ),
          // Bottom-Left bracket
          Positioned(
            bottom: 24,
            left: 24,
            child: _buildCornerBracket(isTop: false, isLeft: true),
          ),
          // Bottom-Right bracket
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildCornerBracket(isTop: false, isLeft: false),
          ),

          // Detected Object Badge (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF14241E).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Waste bin · 96%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Retake button (Bottom Right)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Retake',
                style: TextStyle(
                  color: AppColors.inkPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCornerBracket({required bool isTop, required bool isLeft}) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _BracketPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }

  Widget _buildAnalysisStatusRow() {
    return Row(
      children: [
        // Sprig avatar
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFD6F2E3),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SprigMascot(size: 32, animated: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analysis complete',
                style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Text(
                'Edit anything before you submit',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        // No duplicates badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F8EE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 14, color: Color(0xFF1EA05A)),
              SizedBox(width: 4),
              Text(
                'No duplicates',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1EA05A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(IssueCategory cat) {
    final bool isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          cat.displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.inkPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityOption(IssueSeverity severity, Color dotColor) {
    final bool isSelected = _selectedSeverity == severity;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeverity = severity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              severity.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;

  _BracketPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (!isTop && !isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
