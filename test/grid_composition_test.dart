import 'dart:ui';

import 'package:angle_craft/services/grid_composition_service.dart';
import 'package:angle_craft/services/pose_detection_service.dart';
import 'package:angle_craft/widgets/smart_grid_painter.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() {
  test('asks the user to enter the frame when no person is detected', () {
    final advice = GridCompositionService.evaluate(
      const DetectedPoseFrame(
        pose: null,
        imageSize: Size(100, 100),
        rotation: InputImageRotation.rotation0deg,
        lensDirection: CameraLensDirection.back,
      ),
      GridType.thirds,
    );

    expect(advice, contains('Chưa nhận diện được người'));
  });

  test('suggests a direction toward the nearest rule-of-thirds point', () {
    final advice = GridCompositionService.evaluate(
      _frameWithNose(80, 40),
      GridType.thirds,
    );

    expect(advice, contains('sang trái'));
    expect(advice, contains('lên'));
    expect(advice, contains('giao điểm lưới'));
  });

  test('recognizes when the focal point is near a golden-ratio target', () {
    final advice = GridCompositionService.evaluate(
      _frameWithNose(38.2, 38.2),
      GridType.goldenRatio,
    );

    expect(advice, contains('gần vùng căn gợi ý'));
  });

  test('uses the selected diagonal grid lines for alignment advice', () {
    final advice = GridCompositionService.evaluate(
      _frameWithNose(75, 25),
      GridType.diagonal,
    );

    expect(advice, contains('gần vùng căn gợi ý'));
  });

  test('uses the golden-triangle lines for alignment advice', () {
    final advice = GridCompositionService.evaluate(
      _frameWithNose(25, 20),
      GridType.goldenTriangle,
    );

    expect(advice, contains('gần vùng căn gợi ý'));
  });

  test('mirrors front-camera coordinates to match the preview', () {
    final advice = GridCompositionService.evaluate(
      _frameWithNose(80, 40, lensDirection: CameraLensDirection.front),
      GridType.thirds,
    );

    expect(advice, contains('sang phải'));
  });
}

DetectedPoseFrame _frameWithNose(
  double x,
  double y, {
  CameraLensDirection lensDirection = CameraLensDirection.back,
}) => DetectedPoseFrame(
  pose: Pose(
    landmarks: {
      PoseLandmarkType.nose: PoseLandmark(
        type: PoseLandmarkType.nose,
        x: x,
        y: y,
        z: 0,
        likelihood: 0.9,
      ),
    },
  ),
  imageSize: const Size(100, 100),
  rotation: InputImageRotation.rotation0deg,
  lensDirection: lensDirection,
);
