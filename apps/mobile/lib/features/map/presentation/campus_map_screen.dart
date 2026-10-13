import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  String _selectedBuilding = 'Block B';
  String _activeFilter = 'All';

  final Map<String, Map<String, dynamic>> _buildingData = {
    'Block B': {
      'score': 61,
      'status': 'Needs care',
      'active': 12,
      'resolved': 47,
      'recurring': 3,
      'waste': 52,
      'water': 48,
      'energy': 71,
      'greenery': 83,
      'insightTitle': 'Recurring water issue.',
      'insightDesc': 'Up from 2 reports in June to 12 in October. Inspect plumbing.',
    },
    'Block A': {
      'score': 82,
      'status': 'Fair',
      'active': 5,
      'resolved': 62,
      'recurring': 1,
      'waste': 85,
      'water': 78,
      'energy': 74,
      'greenery': 91,
      'insightTitle': 'Lighting efficiency check.',
      'insightDesc': 'Minor flickering reports in second floor labs.',
    },
    'Library': {
      'score': 91,
      'status': 'Good',
      'active': 2,
      'resolved': 89,
      'recurring': 0,
      'waste': 94,
      'water': 92,
      'energy': 88,
      'greenery': 90,
      'insightTitle': 'High sustainability rating.',
      'insightDesc': 'Energy conservation protocols functioning optimally.',
    },
    'Canteen': {
      'score': 87,
      'status': 'Good',
      'active': 4,
      'resolved': 78,
      'recurring': 1,
      'waste': 79,
      'water': 88,
      'energy': 86,
      'greenery': 95,
      'insightTitle': 'Food waste diversion.',
      'insightDesc': 'Composting bins operating at 92% compliance.',
    },
  };

  @override
  Widget build(BuildContext context) {
    final selected = _buildingData[_selectedBuilding]!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Controls (Search & Filters)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF144D37).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.inkSecondary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search buildings or issues',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.inkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filter Pills Row
                  Row(
                    children: [
                      _buildFilterPill('Good', const Color(0xFF1EA05A)),
                      const SizedBox(width: 8),
                      _buildFilterPill('Fair', const Color(0xFFD98327)),
                      const SizedBox(width: 8),
                      _buildFilterPill('Needs care', const Color(0xFFD65236)),
                    ],
                  ),
                ],
              ),
            ),

            // 2D Interactive Map Layout
            Expanded(
              child: Stack(
                children: [
                  // Campus Grid / Paths Background
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CampusPathPainter(),
                      ),
                    ),
                  ),

                  // Building Cards
                  Positioned(
                    top: 20,
                    left: 24,
                    child: _buildBuildingCard('Library', 91, const Color(0xFF1EA05A)),
                  ),
                  Positioned(
                    top: 20,
                    right: 24,
                    child: _buildBuildingCard('Block A', 82, const Color(0xFFD98327)),
                  ),
                  Positioned(
                    top: 155,
                    left: 24,
                    child: _buildBuildingCard('Block B', 61, const Color(0xFFD65236), hasAlertRipple: true),
                  ),
                  Positioned(
                    top: 155,
                    right: 24,
                    child: _buildBuildingCard('Canteen', 87, const Color(0xFF1EA05A)),
                  ),
                ],
              ),
            ),

            // Bottom Building Detail Card
            _buildBuildingDetailSheet(selected),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, Color dotColor) {
    final bool isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = isSelected ? 'All' : label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? dotColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingCard(String name, int score, Color ringColor, {bool hasAlertRipple = false}) {
    final bool isSelected = _selectedBuilding == name;

    return GestureDetector(
      onTap: () => setState(() => _selectedBuilding = name),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasAlertRipple)
            Container(
              width: 154,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFDECE8).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          Container(
            width: 136,
            height: 104,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Score Ring
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 3.5),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingDetailSheet(Map<String, dynamic> data) {
    final int score = data['score'];
    final Color scoreColor = score >= 85
        ? const Color(0xFF1EA05A)
        : score >= 70
            ? const Color(0xFFD98327)
            : const Color(0xFFD65236);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedBuilding,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${data['active']} active · ${data['resolved']} resolved · ${data['recurring']} recurring',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Circular score widget
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 4),
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.inkPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2x2 Metrics Progress Bars
          Row(
            children: [
              Expanded(
                child: _buildMetricBar('Waste', data['waste'], const Color(0xFFD65236)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildMetricBar('Water', data['water'], const Color(0xFFD65236)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricBar('Energy', data['energy'], const Color(0xFFD98327)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildMetricBar('Greenery', data['greenery'], const Color(0xFF1EA05A)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Warm Insights Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF7E6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['insightTitle'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['insightDesc'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Monthly Trend mini bars (Jun -> Oct)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMiniBar('Jun', 10, const Color(0xFFF3C644)),
                    const SizedBox(width: 4),
                    _buildMiniBar('Jul', 14, const Color(0xFFF1B738)),
                    const SizedBox(width: 4),
                    _buildMiniBar('Aug', 20, const Color(0xFFE8942A)),
                    const SizedBox(width: 4),
                    _buildMiniBar('Sep', 26, const Color(0xFFDE6D2E)),
                    const SizedBox(width: 4),
                    _buildMiniBar('Oct', 34, const Color(0xFFD65236)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            Text('$value', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.inkPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: const Color(0xFFE6EFEA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBar(String month, double height, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          month,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.inkSecondary),
        ),
      ],
    );
  }
}

class _CampusPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw dashed pathways connecting buildings
    const dashWidth = 8.0;
    const dashSpace = 6.0;

    // Vertical central path
    double startY = 0;
    final centerX = size.width / 2;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, startY + dashWidth),
        dashedPaint,
      );
      startY += dashWidth + dashSpace;
    }

    // Horizontal central crossroad
    double startX = 0;
    final centerY = 135.0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(startX + dashWidth, centerY),
        dashedPaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
