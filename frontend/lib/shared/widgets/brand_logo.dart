import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
    this.showBackground = true,
  });

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: showBackground ? AppColors.surfaceHigh : Colors.transparent,
          border: showBackground ? Border.all(color: AppColors.line) : null,
          borderRadius: BorderRadius.circular(size * 0.24),
          boxShadow: showBackground
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          painter: _BrandLogoPainter(),
        ),
      ),
    );
  }
}

class _BrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 72;
    final stroke = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = AppColors.primarySoft
      ..style = PaintingStyle.fill;

    final leafFill = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(18 * scale, 32 * scale, 36 * scale, 24 * scale),
      Radius.circular(6 * scale),
    );
    canvas.drawRRect(box, fill);
    canvas.drawRRect(box, stroke);

    final baseLine = Path()
      ..moveTo(18 * scale, 40 * scale)
      ..lineTo(36 * scale, 49 * scale)
      ..lineTo(54 * scale, 40 * scale);
    canvas.drawPath(baseLine, stroke);

    final stem = Path()
      ..moveTo(36 * scale, 44 * scale)
      ..cubicTo(35 * scale, 35 * scale, 35 * scale, 27 * scale, 36 * scale,
          18 * scale);
    canvas.drawPath(stem, stroke);

    final leftLeaf = Path()
      ..moveTo(36 * scale, 25 * scale)
      ..cubicTo(24 * scale, 17 * scale, 18 * scale, 18 * scale, 16 * scale,
          28 * scale)
      ..cubicTo(25 * scale, 32 * scale, 32 * scale, 31 * scale, 36 * scale,
          25 * scale);
    canvas.drawPath(leftLeaf, leafFill);

    final rightLeaf = Path()
      ..moveTo(37 * scale, 21 * scale)
      ..cubicTo(43 * scale, 10 * scale, 54 * scale, 10 * scale, 58 * scale,
          19 * scale)
      ..cubicTo(52 * scale, 27 * scale, 44 * scale, 28 * scale, 37 * scale,
          21 * scale);
    canvas.drawPath(rightLeaf, leafFill);

    final vein = Paint()
      ..color = AppColors.text.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(22 * scale, 27 * scale),
      Offset(33 * scale, 25 * scale),
      vein,
    );
    canvas.drawLine(
      Offset(41 * scale, 21 * scale),
      Offset(54 * scale, 18 * scale),
      vein,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
