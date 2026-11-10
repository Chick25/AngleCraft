import 'package:flutter/material.dart';

enum GridType { thirds, goldenRatio, goldenTriangle, diagonal }

class SmartGridPainter extends CustomPainter {
  final GridType gridType;
  final double opacity;

  SmartGridPainter({required this.gridType, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final visibleOpacity = opacity.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: visibleOpacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final paintAccent = Paint()
      ..color = Colors.yellowAccent.withValues(alpha: visibleOpacity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    switch (gridType) {
      case GridType.thirds:
        _drawRuleOfThirds(canvas, size, paint);
        break;
      case GridType.goldenRatio:
        _drawGoldenRatio(canvas, size, paint);
        break;
      case GridType.goldenTriangle:
        _drawGoldenTriangle(canvas, size, paint, paintAccent);
        break;
      case GridType.diagonal:
        _drawDiagonal(canvas, size, paint);
        break;
    }
  }

  void _drawRuleOfThirds(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    // 2 đường dọc
    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), paint);
    canvas.drawLine(Offset(2 * w / 3, 0), Offset(2 * w / 3, h), paint);

    // 2 đường ngang
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), paint);
    canvas.drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), paint);
  }

  void _drawGoldenRatio(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    // Tỷ lệ vàng ~ 0.382 và 0.618
    final x1 = w * 0.382;
    final x2 = w * 0.618;
    final y1 = h * 0.382;
    final y2 = h * 0.618;

    canvas.drawLine(Offset(x1, 0), Offset(x1, h), paint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, h), paint);
    canvas.drawLine(Offset(0, y1), Offset(w, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(w, y2), paint);
  }

  void _drawGoldenTriangle(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint paintAccent,
  ) {
    final w = size.width;
    final h = size.height;
    final diagonalLengthSquared = w * w + h * h;
    if (diagonalLengthSquared == 0) return;

    final diagonal = Offset(w, h);
    final topRightProjection = diagonal * (w * w / diagonalLengthSquared);
    final bottomLeftProjection = diagonal * (h * h / diagonalLengthSquared);

    canvas
      ..drawLine(Offset.zero, diagonal, paint)
      ..drawLine(Offset(w, 0), topRightProjection, paintAccent)
      ..drawLine(Offset(0, h), bottomLeftProjection, paintAccent);
  }

  void _drawDiagonal(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(0, 0), Offset(w, h), paint);
    canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
  }

  @override
  bool shouldRepaint(covariant SmartGridPainter oldDelegate) {
    return oldDelegate.gridType != gridType || oldDelegate.opacity != opacity;
  }
}
