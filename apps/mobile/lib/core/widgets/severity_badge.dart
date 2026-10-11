import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/report/domain/report_model.dart';

class SeverityBadge extends StatelessWidget {
  final IssueSeverity severity;
  final bool compact;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color bgColor;
    Color textColor;

    switch (severity) {
      case IssueSeverity.low:
        dotColor = AppColors.severityLow;
        bgColor = AppColors.severityLowBg;
        textColor = const Color(0xFF137A43);
        break;
      case IssueSeverity.medium:
        dotColor = AppColors.severityMedium;
        bgColor = AppColors.severityMediumBg;
        textColor = const Color(0xFF9E5C14);
        break;
      case IssueSeverity.high:
        dotColor = AppColors.severityHigh;
        bgColor = AppColors.severityHighBg;
        textColor = const Color(0xFFA33820);
        break;
      case IssueSeverity.critical:
        dotColor = AppColors.severityCritical;
        bgColor = AppColors.severityCriticalBg;
        textColor = const Color(0xFF961613);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
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
            severity.displayName,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
