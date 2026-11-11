import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pose_item.dart';

class PoseSilhouettePainter extends CustomPainter {
  final PoseItem pose;
  final Color color;
  final String? highlightedJoint;

  const PoseSilhouettePainter({
    required this.pose,
    this.color = Colors.yellowAccent,
    this.highlightedJoint,
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

    final customLandmarks = pose.customLandmarks;
    if (customLandmarks != null) {
      _drawCustomPose(canvas, paint, customLandmarks);
      canvas.restore();
      return;
    }

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

  void _drawCustomPose(
    Canvas canvas,
    Paint paint,
    Map<String, Offset> landmarks,
  ) {
    Offset toCanvas(Offset point) => Offset(point.dx * 100, point.dy * 150);
    Offset? joint(String name) {
      final point = landmarks[name];
      return point == null ? null : toCanvas(point);
    }

    final armPaint = Paint()
      ..color = color
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final legPaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final torsoPaint = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;

    final leftShoulder = joint('leftShoulder');
    final rightShoulder = joint('rightShoulder');
    final leftHip = joint('leftHip');
    final rightHip = joint('rightHip');
    final shoulders = [leftShoulder, rightShoulder];
    final hips = [leftHip, rightHip];
    if (shoulders.every((point) => point != null) &&
        hips.every((point) => point != null)) {
      final leftTop = leftShoulder!;
      final rightTop = rightShoulder!;
      final leftBottom = leftHip!;
      final rightBottom = rightHip!;
      final torso = Path()
        ..moveTo(leftTop.dx, leftTop.dy)
        ..quadraticBezierTo(
          (leftTop.dx + rightTop.dx) / 2,
          (leftTop.dy + rightTop.dy) / 2 - 3,
          rightTop.dx,
          rightTop.dy,
        )
        ..lineTo(rightBottom.dx + 2, rightBottom.dy)
        ..quadraticBezierTo(
          (leftBottom.dx + rightBottom.dx) / 2,
          (leftBottom.dy + rightBottom.dy) / 2 + 2,
          leftBottom.dx - 2,
          leftBottom.dy,
        )
        ..close();
      canvas.drawPath(torso, torsoPaint);
    }

    void drawLimb(List<String> names, Paint limbPaint) {
      final points = names.map(joint).toList();
      for (var index = 0; index < points.length - 1; index++) {
        final start = points[index];
        final end = points[index + 1];
        if (start != null && end != null) {
          canvas.drawLine(start, end, limbPaint);
        }
      }
      for (final point in points.skip(1).take(points.length - 2)) {
        if (point != null) {
          canvas.drawCircle(point, limbPaint.strokeWidth / 2, limbPaint);
        }
      }
    }

    drawLimb(['leftShoulder', 'leftElbow', 'leftWrist'], armPaint);
    drawLimb(['rightShoulder', 'rightElbow', 'rightWrist'], armPaint);
    drawLimb(['leftHip', 'leftKnee', 'leftAnkle'], legPaint);
    drawLimb(['rightHip', 'rightKnee', 'rightAnkle'], legPaint);

    final nose = joint('nose');
    if (nose != null) {
      canvas
        ..drawOval(
          Rect.fromCenter(center: nose, width: 13, height: 17),
          Paint()..color = color,
        )
        ..drawArc(
          Rect.fromCenter(
            center: nose.translate(0, -1.5),
            width: 13,
            height: 11,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }

    for (final entry in landmarks.entries) {
      final point = toCanvas(entry.value);
      final isHighlighted = entry.key == highlightedJoint;
      if (isHighlighted) {
        canvas.drawCircle(
          point,
          5.2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      final jointPaint = Paint()
        ..color = isHighlighted ? Colors.white : color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, isHighlighted ? 3.8 : 2, jointPaint);
    }
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
    canvas.save();
    canvas
      ..translate(centerX, top)
      ..scale(scale);

    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final detailPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final hairPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(0, 11), width: 13, height: 16),
        bodyPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-3.2, 18, 3.2, 25),
          const Radius.circular(2),
        ),
        bodyPaint,
      );

    final shirt = Path()
      ..moveTo(-5, 23)
      ..quadraticBezierTo(-9, 23, -12, 27)
      ..lineTo(-17, 38)
      ..lineTo(-12, 41)
      ..lineTo(-9, 36)
      ..lineTo(-8, 52)
      ..quadraticBezierTo(0, 56, 8, 52)
      ..lineTo(9, 36)
      ..lineTo(12, 41)
      ..lineTo(17, 38)
      ..lineTo(12, 27)
      ..quadraticBezierTo(9, 23, 5, 23)
      ..lineTo(0, 27)
      ..close();
    canvas.drawPath(shirt, bodyPaint);

    final leftHip = Offset(-5, 51);
    final rightHip = Offset(5, 51);
    final leftShoulder = const Offset(-10, 27);
    final rightShoulder = const Offset(10, 27);
    final limbPaint = Paint()
      ..color = color
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final legPaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawLimb(Paint limb, List<Offset> points) {
      for (var index = 0; index < points.length - 1; index++) {
        canvas.drawLine(points[index], points[index + 1], limb);
      }
      for (final joint in points.skip(1).take(points.length - 2)) {
        canvas.drawCircle(joint, limb.strokeWidth / 2, limb);
      }
    }

    if (sitting) {
      drawLimb(limbPaint, [
        leftShoulder,
        const Offset(-15, 39),
        const Offset(-4, 47),
      ]);
      drawLimb(limbPaint, [
        rightShoulder,
        const Offset(15, 36),
        const Offset(5, 47),
      ]);
      drawLimb(legPaint, [
        leftHip,
        const Offset(-18, 65),
        const Offset(12, 65),
        const Offset(20, 82),
      ]);
      drawLimb(legPaint, [
        rightHip,
        const Offset(13, 64),
        const Offset(-4, 76),
        const Offset(-20, 76),
      ]);
      canvas
        ..drawLine(const Offset(20, 82), const Offset(7, 82), limbPaint)
        ..drawLine(const Offset(-20, 76), const Offset(-30, 76), limbPaint);
    } else {
      drawLimb(
        limbPaint,
        handOnHip
            ? [leftShoulder, const Offset(-15, 40), const Offset(-9, 51)]
            : [leftShoulder, const Offset(-15, 40), const Offset(-12, 52)],
      );
      drawLimb(
        limbPaint,
        handOnHip
            ? [rightShoulder, const Offset(16, 39), const Offset(7, 49)]
            : [rightShoulder, const Offset(15, 40), const Offset(12, 52)],
      );

      final leftKnee = walking ? const Offset(-15, 70) : const Offset(-7, 74);
      final rightKnee = walking ? const Offset(16, 68) : const Offset(7, 74);
      final leftAnkle = walking ? const Offset(-24, 91) : const Offset(-10, 96);
      final rightAnkle = walking ? const Offset(9, 91) : const Offset(10, 96);
      drawLimb(legPaint, [leftHip, leftKnee, leftAnkle]);
      drawLimb(legPaint, [rightHip, rightKnee, rightAnkle]);

      canvas
        ..drawLine(leftAnkle, leftAnkle.translate(-5, 1), limbPaint)
        ..drawLine(rightAnkle, rightAnkle.translate(5, 1), limbPaint);
    }

    final shirtSeam = Path()
      ..moveTo(0, 28)
      ..lineTo(0, 50)
      ..moveTo(-8, 52)
      ..quadraticBezierTo(0, 55, 8, 52);
    final hair = Path()
      ..moveTo(-6, 8)
      ..quadraticBezierTo(-5, 1, 1, 3)
      ..quadraticBezierTo(7, 3, 6, 9)
      ..quadraticBezierTo(1, 6, -6, 8)
      ..close();
    canvas
      ..drawPath(shirtSeam, detailPaint)
      ..drawPath(hair, hairPaint)
      ..restore();
  }

  void _drawBackpack(Canvas canvas, Paint paint) {
    final backpack = RRect.fromRectAndRadius(
      const Rect.fromLTRB(63, 45, 72, 66),
      const Radius.circular(4),
    );
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    canvas
      ..drawRRect(backpack, fillPaint)
      ..drawRRect(backpack, paint)
      ..drawLine(const Offset(63, 49), const Offset(59, 57), paint);
  }

  @override
  bool shouldRepaint(covariant PoseSilhouettePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.color != color ||
      oldDelegate.highlightedJoint != highlightedJoint;
}
