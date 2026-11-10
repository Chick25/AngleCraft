import 'dart:math' as math;

import 'package:flutter/material.dart';

class LevelIndicatorWidget extends StatelessWidget {
  static const double balancedThreshold = 2;
  static const double severeTiltThreshold = 8;

  final double roll;
  final double pitch;
  final bool isAvailable;
  final String? errorMessage;

  const LevelIndicatorWidget({
    super.key,
    this.roll = 0,
    this.pitch = 0,
    this.isAvailable = true,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final maximumTilt = math.max(roll.abs(), pitch.abs());
    final isBalanced = isAvailable && maximumTilt <= balancedThreshold;
    final isSeverelyTilted = isAvailable && maximumTilt > severeTiltThreshold;
    final statusColor = !isAvailable
        ? Colors.white54
        : isBalanced
        ? Colors.greenAccent
        : isSeverelyTilted
        ? Colors.redAccent
        : Colors.orangeAccent;
    final statusText = !isAvailable
        ? errorMessage ?? 'Đang đọc cảm biến'
        : isBalanced
        ? 'Đã cân bằng'
        : isSeverelyTilted
        ? 'Lệch góc nghiêm trọng'
        : 'Máy đang nghiêng';

    return Semantics(
      label: isAvailable
          ? '$statusText. Roll ${roll.toStringAsFixed(1)} độ, pitch ${pitch.toStringAsFixed(1)} độ.'
          : statusText,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: CustomPaint(
                painter: _LevelBubblePainter(
                  roll: roll,
                  pitch: pitch,
                  color: statusColor,
                  enabled: isAvailable,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        !isAvailable
                            ? Icons.sensors_off
                            : isBalanced
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isAvailable ? 'Ngang  ${_formatAngle(roll)}°' : 'Ngang  --',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isAvailable
                        ? 'Dọc     ${_formatAngle(pitch)}°'
                        : 'Dọc     --',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAngle(double angle) =>
      '${angle > 0 ? '+' : ''}${angle.toStringAsFixed(1)}';
}

class _LevelBubblePainter extends CustomPainter {
  final double roll;
  final double pitch;
  final Color color;
  final bool enabled;

  const _LevelBubblePainter({
    required this.roll,
    required this.pitch,
    required this.color,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas
      ..drawCircle(center, radius, backgroundPaint)
      ..drawCircle(center, radius, outlinePaint)
      ..drawCircle(center, radius * 0.55, guidePaint)
      ..drawCircle(center, radius * 0.12, guidePaint)
      ..drawLine(
        Offset(center.dx - radius * 0.72, center.dy),
        Offset(center.dx + radius * 0.72, center.dy),
        guidePaint,
      )
      ..drawLine(
        Offset(center.dx, center.dy - radius * 0.72),
        Offset(center.dx, center.dy + radius * 0.72),
        guidePaint,
      );

    if (!enabled) return;

    final maximumOffset = radius * 0.7;
    final rollOffset = _mapAngleToOffset(roll, maximumOffset);
    final pitchOffset = _mapAngleToOffset(pitch, maximumOffset);
    final bubbleOffset = Offset(rollOffset, pitchOffset);
    final bubblePaint = Paint()
      ..color = color.withValues(alpha: 0.86)
      ..style = PaintingStyle.fill;
    final bubbleHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    final bubbleCenter = center + bubbleOffset;

    canvas
      ..drawCircle(bubbleCenter, radius * 0.2, bubblePaint)
      ..drawCircle(
        bubbleCenter.translate(-radius * 0.055, -radius * 0.06),
        radius * 0.045,
        bubbleHighlight,
      );
  }

  double _mapAngleToOffset(double angle, double maximumOffset) {
    final effectiveAngle =
        (angle.abs() - LevelIndicatorWidget.balancedThreshold).clamp(0.0, 10.0);
    if (effectiveAngle == 0) return 0;
    return angle.sign * (effectiveAngle / 10) * maximumOffset;
  }

  @override
  bool shouldRepaint(covariant _LevelBubblePainter oldDelegate) =>
      oldDelegate.roll != roll ||
      oldDelegate.pitch != pitch ||
      oldDelegate.color != color ||
      oldDelegate.enabled != enabled;
}
