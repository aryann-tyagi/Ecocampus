import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sprig is the EcoCampus AI guide mascot.
/// Custom-painted for crisp resolution, responsive scaling, and smooth micro-animations.
class SprigMascot extends StatefulWidget {
  final double size;
  final bool animated;
  final String? expression;

  const SprigMascot({
    super.key,
    this.size = 140,
    this.animated = true,
    this.expression,
  });

  @override
  State<SprigMascot> createState() => _SprigMascotState();
}

class _SprigMascotState extends State<SprigMascot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.animated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SprigMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double bobOffset = widget.animated
            ? math.sin(_controller.value * math.pi) * (widget.size * 0.03)
            : 0;

        return Transform.translate(
          offset: Offset(0, -bobOffset),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _SprigPainter(
              blinkValue: 0.0, // Stable friendly gaze
            ),
          ),
        );
      },
    );
  }
}

class _SprigPainter extends CustomPainter {
  final double blinkValue;

  _SprigPainter({required this.blinkValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.56);
    final double radius = w * 0.38;

    // 1. Sprout leaves at top
    final Paint leafPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF56D686), Color(0xFF38B868)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.35, h * 0.05, w * 0.3, h * 0.28))
      ..style = PaintingStyle.fill;

    // Sprout stem
    final Path stemPath = Path()
      ..moveTo(w * 0.5, center.dy - radius + 4)
      ..quadraticBezierTo(w * 0.5, h * 0.22, w * 0.49, h * 0.18);
    final Paint stemPaint = Paint()
      ..color = const Color(0xFF32A65C)
      ..strokeWidth = w * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stemPath, stemPaint);

    // Left leaf
    final Path leftLeaf = Path()
      ..moveTo(w * 0.49, h * 0.2)
      ..cubicTo(w * 0.32, h * 0.16, w * 0.34, h * 0.07, w * 0.46, h * 0.09)
      ..cubicTo(w * 0.5, h * 0.12, w * 0.5, h * 0.18, w * 0.49, h * 0.2);
    canvas.drawPath(leftLeaf, leafPaint);

    // Right leaf
    final Path rightLeaf = Path()
      ..moveTo(w * 0.49, h * 0.2)
      ..cubicTo(w * 0.64, h * 0.14, w * 0.68, h * 0.06, w * 0.54, h * 0.07)
      ..cubicTo(w * 0.49, h * 0.12, w * 0.49, h * 0.18, w * 0.49, h * 0.2);
    canvas.drawPath(rightLeaf, leafPaint);

    // Subtle drop shadow under body
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.94),
      width: radius * 1.6,
      height: radius * 0.3,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = const Color(0xFF144D37).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 2. Main round body
    final Paint bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.3),
        radius: 0.9,
        colors: [
          Color(0xFF6DE8A8),
          Color(0xFF38CC85),
          Color(0xFF1EA864),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bodyPaint);

    // Little round ear/cheek nubs on sides
    final Paint nubPaint = Paint()
      ..color = const Color(0xFF26B26E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - radius * 0.96, center.dy + radius * 0.1), radius * 0.2, nubPaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.96, center.dy + radius * 0.1), radius * 0.2, nubPaint);

    // Light tummy oval
    final Rect tummyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.38),
      width: radius * 1.25,
      height: radius * 0.72,
    );
    final Paint tummyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB4F7D3), Color(0xFF8CEAB9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(tummyRect);
    canvas.drawOval(tummyRect, tummyPaint);

    // 3. Eyes
    final double eyeRadiusX = radius * 0.26;
    final double eyeRadiusY = radius * 0.32;
    final Offset leftEyeCenter = Offset(center.dx - radius * 0.42, center.dy - radius * 0.05);
    final Offset rightEyeCenter = Offset(center.dx + radius * 0.42, center.dy - radius * 0.05);

    // Eye whites
    final Paint eyeWhitePaint = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: leftEyeCenter, width: eyeRadiusX * 2, height: eyeRadiusY * 2), eyeWhitePaint);
    canvas.drawOval(Rect.fromCenter(center: rightEyeCenter, width: eyeRadiusX * 2, height: eyeRadiusY * 2), eyeWhitePaint);

    // Eye pupils (deep glossy black-green)
    final Paint pupilPaint = Paint()..color = const Color(0xFF0E3824);
    final double pupilRadiusX = eyeRadiusX * 0.78;
    final double pupilRadiusY = eyeRadiusY * 0.85;
    final Offset leftPupil = Offset(leftEyeCenter.dx + 2, leftEyeCenter.dy + 1);
    final Offset rightPupil = Offset(rightEyeCenter.dx - 2, rightEyeCenter.dy + 1);

    canvas.drawOval(Rect.fromCenter(center: leftPupil, width: pupilRadiusX * 2, height: pupilRadiusY * 2), pupilPaint);
    canvas.drawOval(Rect.fromCenter(center: rightPupil, width: pupilRadiusX * 2, height: pupilRadiusY * 2), pupilPaint);

    // Pupil eye shine / sparkle highlights
    final Paint shinePaint = Paint()..color = Colors.white;
    // Primary big shine
    canvas.drawCircle(Offset(leftPupil.dx - pupilRadiusX * 0.32, leftPupil.dy - pupilRadiusY * 0.32), pupilRadiusX * 0.38, shinePaint);
    canvas.drawCircle(Offset(rightPupil.dx - pupilRadiusX * 0.32, rightPupil.dy - pupilRadiusY * 0.32), pupilRadiusX * 0.38, shinePaint);
    // Secondary mini shine
    canvas.drawCircle(Offset(leftPupil.dx + pupilRadiusX * 0.34, leftPupil.dy + pupilRadiusY * 0.32), pupilRadiusX * 0.18, shinePaint);
    canvas.drawCircle(Offset(rightPupil.dx + pupilRadiusX * 0.34, rightPupil.dy + pupilRadiusY * 0.32), pupilRadiusX * 0.18, shinePaint);

    // 4. Smile
    final Path mouthPath = Path()
      ..moveTo(center.dx - radius * 0.16, center.dy + radius * 0.14)
      ..quadraticBezierTo(center.dx, center.dy + radius * 0.28, center.dx + radius * 0.16, center.dy + radius * 0.14);
    final Paint mouthPaint = Paint()
      ..color = const Color(0xFF0F3E28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, w * 0.035)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(mouthPath, mouthPaint);

    // 5. Cute feet/base nubs
    final Paint feetPaint = Paint()..color = const Color(0xFF1E8F55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - radius * 0.55, center.dy + radius * 0.85, radius * 0.45, radius * 0.22),
        Radius.circular(radius * 0.12),
      ),
      feetPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + radius * 0.1, center.dy + radius * 0.85, radius * 0.45, radius * 0.22),
        Radius.circular(radius * 0.12),
      ),
      feetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SprigPainter oldDelegate) =>
      oldDelegate.blinkValue != blinkValue;
}
