import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../widgets/smart_grid_painter.dart';
import 'pose_detection_service.dart';

class GridCompositionService {
  static const _confidenceThreshold = 0.5;
  static const _alignmentThreshold = 0.12;

  static String evaluate(DetectedPoseFrame? frame, GridType gridType) {
    if (frame == null) return 'Đang tìm người trong khung hình...';
    final focus = _focusPoint(frame);
    if (focus == null) {
      return frame.pose == null
          ? 'Chưa nhận diện được người. Hãy đưa người rõ hơn vào khung hình.'
          : 'Chưa xác định được điểm căn; hãy để mặt hoặc thân trên rõ hơn.';
    }

    final isPointGrid =
        gridType == GridType.thirds || gridType == GridType.goldenRatio;
    final target = _nearestTarget(focus, frame, gridType);
    final aspectRatio = _previewAspectRatio(frame);
    if (_screenDistance(target, focus, aspectRatio) <= _alignmentThreshold) {
      return 'Điểm nhấn của người đang gần vùng căn gợi ý; hãy kiểm tra khoảng thở.';
    }

    final delta = target - focus;
    final directions = <String>[];
    if (delta.dx.abs() >= 0.06) {
      directions.add(delta.dx < 0 ? 'sang trái' : 'sang phải');
    }
    if (delta.dy.abs() >= 0.06) {
      directions.add(delta.dy < 0 ? 'lên' : 'xuống');
    }
    final targetName = isPointGrid ? 'giao điểm lưới' : 'đường lưới';
    return 'Dịch người ${directions.join(' và ')} để đưa điểm nhấn gần $targetName.';
  }

  static Offset? _focusPoint(DetectedPoseFrame frame) {
    final pose = frame.pose;
    if (pose == null ||
        frame.imageSize.width <= 0 ||
        frame.imageSize.height <= 0) {
      return null;
    }

    final nose = pose.landmarks[PoseLandmarkType.nose];
    if (nose != null && nose.likelihood >= _confidenceThreshold) {
      return _toPreviewPoint(Offset(nose.x, nose.y), frame);
    }

    const torsoLandmarks = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    final torsoPoints = <Offset>[];
    for (final type in torsoLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark != null && landmark.likelihood >= _confidenceThreshold) {
        torsoPoints.add(Offset(landmark.x, landmark.y));
      }
    }
    if (torsoPoints.length < 2) return null;

    final minX = torsoPoints.map((point) => point.dx).reduce(math.min);
    final maxX = torsoPoints.map((point) => point.dx).reduce(math.max);
    final minY = torsoPoints.map((point) => point.dy).reduce(math.min);
    final maxY = torsoPoints.map((point) => point.dy).reduce(math.max);
    return _toPreviewPoint(Offset((minX + maxX) / 2, (minY + maxY) / 2), frame);
  }

  static Offset _toPreviewPoint(Offset point, DetectedPoseFrame frame) {
    final imageSize = frame.imageSize;
    final isRotated =
        frame.rotation == InputImageRotation.rotation90deg ||
        frame.rotation == InputImageRotation.rotation270deg;
    final x = switch (frame.rotation) {
      InputImageRotation.rotation90deg => point.dx / imageSize.height,
      InputImageRotation.rotation270deg => 1 - point.dx / imageSize.height,
      InputImageRotation.rotation0deg || InputImageRotation.rotation180deg =>
        frame.lensDirection == CameraLensDirection.front
            ? 1 - point.dx / imageSize.width
            : point.dx / imageSize.width,
    };
    final y = isRotated
        ? point.dy / imageSize.width
        : point.dy / imageSize.height;
    return Offset(x.clamp(0.0, 1.0).toDouble(), y.clamp(0.0, 1.0).toDouble());
  }

  static Offset _nearestTarget(
    Offset point,
    DetectedPoseFrame frame,
    GridType gridType,
  ) {
    final aspectRatio = _previewAspectRatio(frame);
    final squaredAspectRatio = aspectRatio * aspectRatio;
    final upperProjection = squaredAspectRatio / (squaredAspectRatio + 1);
    final lowerProjection = 1 - upperProjection;
    final targets = switch (gridType) {
      GridType.thirds => [
        const Offset(1 / 3, 1 / 3),
        const Offset(2 / 3, 1 / 3),
        const Offset(1 / 3, 2 / 3),
        const Offset(2 / 3, 2 / 3),
      ],
      GridType.goldenRatio => [
        const Offset(0.382, 0.382),
        const Offset(0.618, 0.382),
        const Offset(0.382, 0.618),
        const Offset(0.618, 0.618),
      ],
      GridType.goldenTriangle => [
        _projectToSegment(point, Offset.zero, const Offset(1, 1), aspectRatio),
        _projectToSegment(
          point,
          const Offset(1, 0),
          Offset(upperProjection, upperProjection),
          aspectRatio,
        ),
        _projectToSegment(
          point,
          const Offset(0, 1),
          Offset(lowerProjection, lowerProjection),
          aspectRatio,
        ),
      ],
      GridType.diagonal => [
        _projectToSegment(point, Offset.zero, const Offset(1, 1), aspectRatio),
        _projectToSegment(
          point,
          const Offset(1, 0),
          const Offset(0, 1),
          aspectRatio,
        ),
      ],
    };
    return targets.reduce(
      (nearest, candidate) =>
          _screenDistance(candidate, point, aspectRatio) <
              _screenDistance(nearest, point, aspectRatio)
          ? candidate
          : nearest,
    );
  }

  static double _previewAspectRatio(DetectedPoseFrame frame) {
    final isRotated =
        frame.rotation == InputImageRotation.rotation90deg ||
        frame.rotation == InputImageRotation.rotation270deg;
    return isRotated
        ? frame.imageSize.height / frame.imageSize.width
        : frame.imageSize.width / frame.imageSize.height;
  }

  static double _screenDistance(Offset first, Offset second, double aspect) =>
      Offset((first.dx - second.dx) * aspect, first.dy - second.dy).distance;

  static Offset _projectToSegment(
    Offset point,
    Offset start,
    Offset end,
    double aspectRatio,
  ) {
    final scaledPoint = Offset(point.dx * aspectRatio, point.dy);
    final scaledStart = Offset(start.dx * aspectRatio, start.dy);
    final scaledEnd = Offset(end.dx * aspectRatio, end.dy);
    final segment = scaledEnd - scaledStart;
    final projection =
        ((scaledPoint - scaledStart).dx * segment.dx +
            (scaledPoint - scaledStart).dy * segment.dy) /
        segment.distanceSquared;
    final projected = scaledStart + segment * projection.clamp(0.0, 1.0);
    return Offset(projected.dx / aspectRatio, projected.dy);
  }
}
