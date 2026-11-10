import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pose_item.dart';

class PoseSilhouettePainter extends CustomPainter {
  final PoseItem pose;
  final Color color;

  const PoseSilhouettePainter({
    required this.pose,
    this.color = Colors.yellowAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scale = math.min(size.width / 100, size.height / 150);
    final drawnSize = Size(100 * scale, 150 * scale);
    canvas.save();
    canvas.translate(
      (size.width - drawnSize.width) / 2,
      (size.height - drawnSize.height) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (pose.style) {
      case PoseStyle.couple:
        _drawPerson(canvas, paint, centerX: 36, top: 16, scale: 0.88);
        _drawPerson(canvas, paint, centerX: 64, top: 16, scale: 0.88);
      case PoseStyle.family:
        _drawPerson(canvas, paint, centerX: 25, top: 18, scale: 0.78);
        _drawPerson(canvas, paint, centerX: 50, top: 36, scale: 0.58);
        _drawPerson(canvas, paint, centerX: 75, top: 18, scale: 0.78);
      case PoseStyle.group:
        _drawPerson(canvas, paint, centerX: 20, top: 27, scale: 0.67);
        _drawPerson(canvas, paint, centerX: 40, top: 16, scale: 0.82);
        _drawPerson(canvas, paint, centerX: 60, top: 16, scale: 0.82);
        _drawPerson(canvas, paint, centerX: 80, top: 27, scale: 0.67);
      case PoseStyle.walking:
        _drawPerson(
          canvas,
          paint,
          centerX: 50,
          top: 14,
          scale: 0.92,
          walking: true,
        );
      case PoseStyle.travel:
        _drawPerson(
          canvas,
          paint,
          centerX: 50,
          top: 14,
          scale: 0.92,
          walking: true,
          handOnHip: true,
        );
        _drawBackpack(canvas, paint);
      case PoseStyle.sitting:
        _drawPerson(
          canvas,
          paint,
          centerX: 50,
          top: 14,
          scale: 0.92,
          sitting: true,
        );
      case PoseStyle.handOnHip:
        _drawPerson(
          canvas,
          paint,
          centerX: 50,
          top: 14,
          scale: 0.92,
          handOnHip: true,
        );
      case PoseStyle.standing:
        _drawPerson(canvas, paint, centerX: 50, top: 14, scale: 0.92);
    }

    canvas.restore();
  }

  void _drawPerson(
    Canvas canvas,
    Paint paint, {
    required double centerX,
    required double top,
    required double scale,
    bool handOnHip = false,
    bool sitting = false,
    bool walking = false,
  }) {
    final headCenter = Offset(centerX, top + 11 * scale);
    final headRadius = 6 * scale;
    final neck = Offset(centerX, top + 19 * scale);
    final leftShoulder = Offset(centerX - 10 * scale, top + 25 * scale);
    final rightShoulder = Offset(centerX + 10 * scale, top + 25 * scale);
    final chest = Offset(centerX, top + 27 * scale);
    final waist = Offset(centerX, top + 52 * scale);
    final leftHip = Offset(centerX - 6 * scale, top + 53 * scale);
    final rightHip = Offset(centerX + 6 * scale, top + 53 * scale);

    canvas.drawCircle(headCenter, headRadius, paint);
    canvas
      ..drawLine(Offset(centerX, headCenter.dy + headRadius), neck, paint)
      ..drawLine(neck, chest, paint)
      ..drawLine(leftShoulder, rightShoulder, paint)
      ..drawLine(leftShoulder, chest, paint)
      ..drawLine(rightShoulder, chest, paint)
      ..drawLine(chest, waist, paint)
      ..drawLine(leftHip, rightHip, paint);

    if (sitting) {
      canvas
        ..drawLine(leftShoulder, Offset(centerX - 14 * scale, top + 39 * scale), paint)
        ..drawLine(
          Offset(centerX - 14 * scale, top + 39 * scale),
          Offset(centerX - 4 * scale, top + 47 * scale),
          paint,
        )
        ..drawLine(rightShoulder, Offset(centerX + 15 * scale, top + 36 * scale), paint)
        ..drawLine(
          Offset(centerX + 15 * scale, top + 36 * scale),
          Offset(centerX + 5 * scale, top + 47 * scale),
          paint,
        )
        ..drawLine(leftHip, Offset(centerX - 18 * scale, top + 65 * scale), paint)
        ..drawLine(
          Offset(centerX - 18 * scale, top + 65 * scale),
          Offset(centerX + 12 * scale, top + 65 * scale),
          paint,
        )
        ..drawLine(
          Offset(centerX + 12 * scale, top + 65 * scale),
          Offset(centerX + 20 * scale, top + 82 * scale),
          paint,
        )
        ..drawLine(
          Offset(centerX + 20 * scale, top + 82 * scale),
          Offset(centerX + 7 * scale, top + 82 * scale),
          paint,
        )
        ..drawLine(rightHip, Offset(centerX + 13 * scale, top + 64 * scale), paint)
        ..drawLine(
          Offset(centerX + 13 * scale, top + 64 * scale),
          Offset(centerX - 4 * scale, top + 76 * scale),
          paint,
        )
        ..drawLine(
          Offset(centerX - 4 * scale, top + 76 * scale),
          Offset(centerX - 20 * scale, top + 76 * scale),
          paint,
        );
      return;
    }

    if (handOnHip) {
      canvas
        ..drawLine(
          leftShoulder,
          Offset(centerX - 15 * scale, top + 40 * scale),
          paint,
        )
        ..drawLine(
          Offset(centerX - 15 * scale, top + 40 * scale),
          Offset(centerX - 9 * scale, top + 51 * scale),
          paint,
        )
        ..drawLine(rightShoulder, Offset(centerX + 16 * scale, top + 39 * scale), paint)
        ..drawLine(
          Offset(centerX + 16 * scale, top + 39 * scale),
          Offset(centerX + 7 * scale, top + 49 * scale),
          paint,
        );
    } else {
      canvas
        ..drawLine(
          leftShoulder,
          Offset(centerX - 15 * scale, top + 40 * scale),
          paint,
        )
        ..drawLine(
          Offset(centerX - 15 * scale, top + 40 * scale),
          Offset(centerX - 12 * scale, top + 52 * scale),
          paint,
        )
        ..drawLine(
          rightShoulder,
          Offset(centerX + 15 * scale, top + 40 * scale),
          paint,
        )
        ..drawLine(
          Offset(centerX + 15 * scale, top + 40 * scale),
          Offset(centerX + 12 * scale, top + 52 * scale),
          paint,
        );
    }

    if (walking) {
      canvas
        ..drawLine(leftHip, Offset(centerX - 15 * scale, top + 70 * scale), paint)
        ..drawLine(
          Offset(centerX - 15 * scale, top + 70 * scale),
          Offset(centerX - 24 * scale, top + 91 * scale),
          paint,
        )
        ..drawLine(rightHip, Offset(centerX + 16 * scale, top + 68 * scale), paint)
        ..drawLine(
          Offset(centerX + 16 * scale, top + 68 * scale),
          Offset(centerX + 9 * scale, top + 91 * scale),
          paint,
        );
    } else {
      canvas
        ..drawLine(leftHip, Offset(centerX - 8 * scale, top + 74 * scale), paint)
        ..drawLine(
          Offset(centerX - 8 * scale, top + 74 * scale),
          Offset(centerX - 10 * scale, top + 96 * scale),
          paint,
        )
        ..drawLine(rightHip, Offset(centerX + 8 * scale, top + 74 * scale), paint)
        ..drawLine(
          Offset(centerX + 8 * scale, top + 74 * scale),
          Offset(centerX + 10 * scale, top + 96 * scale),
          paint,
        );
    }
  }

  void _drawBackpack(Canvas canvas, Paint paint) {
    final backpack = RRect.fromRectAndRadius(
      const Rect.fromLTRB(63, 45, 72, 66),
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(backpack, paint)
      ..drawLine(const Offset(63, 49), const Offset(59, 57), paint);
  }

  @override
  bool shouldRepaint(covariant PoseSilhouettePainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.color != color;
}
