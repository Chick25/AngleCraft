import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseSkeletonOverlay extends StatelessWidget {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final bool isMatched;

  const PoseSkeletonOverlay({
    super.key,
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    required this.isMatched,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PoseSkeletonPainter(
      pose: pose,
      imageSize: imageSize,
      rotation: rotation,
      lensDirection: lensDirection,
      isMatched: isMatched,
    ),
  );
}

class _PoseSkeletonPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final bool isMatched;

  const _PoseSkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    required this.isMatched,
  });

  static const _connections = <(PoseLandmarkType, PoseLandmarkType)>[
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final color = isMatched ? Colors.greenAccent : Colors.yellowAccent;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide * 0.008
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = color;

    for (final (firstType, secondType) in _connections) {
      final first = pose.landmarks[firstType];
      final second = pose.landmarks[secondType];
      if (first == null ||
          second == null ||
          first.likelihood < 0.35 ||
          second.likelihood < 0.35) {
        continue;
      }
      canvas.drawLine(
        _translate(Offset(first.x, first.y), size),
        _translate(Offset(second.x, second.y), size),
        linePaint,
      );
    }

    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < 0.35) continue;
      canvas.drawCircle(
        _translate(Offset(landmark.x, landmark.y), size),
        size.shortestSide * 0.012,
        pointPaint,
      );
    }
  }

  Offset _translate(Offset point, Size canvasSize) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final x = switch (rotation) {
      InputImageRotation.rotation90deg =>
        point.dx *
            canvasSize.width /
            (isIOS ? imageSize.width : imageSize.height),
      InputImageRotation.rotation270deg =>
        canvasSize.width -
            point.dx *
                canvasSize.width /
                (isIOS ? imageSize.width : imageSize.height),
      InputImageRotation.rotation0deg || InputImageRotation.rotation180deg =>
        lensDirection == CameraLensDirection.back
            ? point.dx * canvasSize.width / imageSize.width
            : canvasSize.width - point.dx * canvasSize.width / imageSize.width,
    };
    final y =
        rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg
        ? point.dy *
              canvasSize.height /
              (isIOS ? imageSize.height : imageSize.width)
        : point.dy * canvasSize.height / imageSize.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _PoseSkeletonPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.rotation != rotation ||
      oldDelegate.lensDirection != lensDirection ||
      oldDelegate.isMatched != isMatched;
}
