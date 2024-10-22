import 'package:flutter/material.dart';

enum DashedLineStyle {
  solid(dashW: 1, spaceW: 0),
  dash(dashW: 6, spaceW: 4),
  dot(dashW: 2, spaceW: 2);

  const DashedLineStyle({required this.dashW, required this.spaceW});
  final double dashW;
  final double spaceW;
}

class DashedLinePainter extends CustomPainter {
  final bool isVertical;
  final Color color;
  final double thickness;
  final DashedLineStyle style;

  DashedLinePainter({
      required this.isVertical,
      required this.color,
      required this.thickness,
      required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
    ..color = color
    ..strokeWidth = thickness;

    double start = 0;

    // Draw the dashed line
    if (isVertical) {
      // Vertical line
      while (start < size.height) {
        canvas.drawLine(Offset(0, start), Offset(0, start + style.dashW), paint);
        start += style.dashW + style.spaceW;
      }
    } else {
      // Horizontal line
      while (start < size.width) {
        canvas.drawLine(Offset(start, 0), Offset(start + style.dashW, 0), paint);
        start += style.dashW + style.spaceW;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class DashedLine extends StatelessWidget {
  final double length;
  final DashedLineStyle style;
  final double thickness;
  final bool isVertical;
  final Color color;

  const DashedLine({
      super.key,
      required this.length,
      this.style = DashedLineStyle.solid,
      this.thickness = 1,
      this.isVertical = false, // Default is horizontal
      this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: isVertical ? Size(2, length) : Size(length, 2), // Adjust size based on orientation
      painter: DashedLinePainter(
        isVertical: isVertical,
        color: color,
        thickness: thickness,
        style: style,
      ),
    );
  }
}
