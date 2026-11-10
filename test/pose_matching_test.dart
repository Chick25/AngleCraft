import 'package:angle_craft/data/sample_poses.dart';
import 'package:angle_craft/models/pose_item.dart';
import 'package:angle_craft/services/pose_matching_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() {
  final standingPose = _createPose({
    PoseLandmarkType.leftShoulder: const (40, 40),
    PoseLandmarkType.rightShoulder: const (60, 40),
    PoseLandmarkType.leftElbow: const (35, 60),
    PoseLandmarkType.rightElbow: const (65, 60),
    PoseLandmarkType.leftWrist: const (35, 80),
    PoseLandmarkType.rightWrist: const (65, 80),
    PoseLandmarkType.leftHip: const (44, 100),
    PoseLandmarkType.rightHip: const (56, 100),
    PoseLandmarkType.leftKnee: const (44, 130),
    PoseLandmarkType.rightKnee: const (56, 130),
    PoseLandmarkType.leftAnkle: const (44, 160),
    PoseLandmarkType.rightAnkle: const (56, 160),
  });
  final handOnHipPose = _createPose({
    PoseLandmarkType.leftShoulder: const (40, 40),
    PoseLandmarkType.rightShoulder: const (60, 40),
    PoseLandmarkType.leftElbow: const (34, 55),
    PoseLandmarkType.rightElbow: const (66, 55),
    PoseLandmarkType.leftWrist: const (40, 85),
    PoseLandmarkType.rightWrist: const (66, 85),
    PoseLandmarkType.leftHip: const (44, 100),
    PoseLandmarkType.rightHip: const (56, 100),
  });

  test('matches a relaxed standing pose', () {
    final result = PoseMatchingService.evaluate(
      standingPose,
      samplePoses.firstWhere((pose) => pose.style == PoseStyle.standing),
    );

    expect(result.isSupported, isTrue);
    expect(result.isMatched, isTrue);
    expect(result.score, greaterThanOrEqualTo(80));
  });

  test('matches a hand placed near the hip with a bent elbow', () {
    final result = PoseMatchingService.evaluate(
      handOnHipPose,
      samplePoses.firstWhere((pose) => pose.style == PoseStyle.handOnHip),
    );

    expect(result.isMatched, isTrue);
    expect(result.feedback, contains('Giữ tay ở hông'));
  });

  test('does not match straight arms to the hand-on-hip target', () {
    final result = PoseMatchingService.evaluate(
      standingPose,
      samplePoses.firstWhere((pose) => pose.style == PoseStyle.handOnHip),
    );

    expect(result.isMatched, isFalse);
    expect(result.feedback, contains('đưa bàn tay về phía hông'));
  });

  test('reports unsupported styles instead of pretending they match', () {
    final result = PoseMatchingService.evaluate(
      standingPose,
      samplePoses.firstWhere((pose) => pose.style == PoseStyle.couple),
    );

    expect(result.isSupported, isFalse);
    expect(result.isMatched, isFalse);
  });

  test('asks the user to enter the frame when no pose is detected', () {
    final result = PoseMatchingService.evaluate(
      null,
      samplePoses.firstWhere((pose) => pose.style == PoseStyle.standing),
    );

    expect(result.isMatched, isFalse);
    expect(result.feedback, contains('Đưa người mẫu vào khung hình'));
  });
}

Pose _createPose(Map<PoseLandmarkType, (double, double)> points) => Pose(
  landmarks: {
    for (final entry in points.entries)
      entry.key: PoseLandmark(
        type: entry.key,
        x: entry.value.$1,
        y: entry.value.$2,
        z: 0,
        likelihood: 0.9,
      ),
  },
);
