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

  test('does not score a standing pose without both leg joint chains', () {
    final incompletePose = _createPose({
      PoseLandmarkType.leftShoulder: const (40, 40),
      PoseLandmarkType.rightShoulder: const (60, 40),
      PoseLandmarkType.leftElbow: const (35, 60),
      PoseLandmarkType.rightElbow: const (65, 60),
      PoseLandmarkType.leftWrist: const (35, 80),
      PoseLandmarkType.rightWrist: const (65, 80),
      PoseLandmarkType.leftHip: const (44, 100),
      PoseLandmarkType.rightHip: const (56, 100),
    });

    final result = PoseMatchingService.evaluate(
      incompletePose,
      samplePoses.firstWhere((pose) => pose.style == PoseStyle.standing),
    );

    expect(result.isMatched, isFalse);
    expect(result.score, 0);
    expect(result.feedback, contains('đầu gối'));
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

  test('matches a custom pose using normalized joint positions', () {
    const customPose = PoseItem(
      id: 'custom-rail',
      title: 'Tựa lan can',
      description: 'Custom skeleton',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: {
        'nose': Offset(0.5, 0.1),
        'leftShoulder': Offset(0.4, 0.23),
        'rightShoulder': Offset(0.6, 0.25),
        'leftElbow': Offset(0.34, 0.37),
        'leftWrist': Offset(0.35, 0.49),
        'rightElbow': Offset(0.73, 0.29),
        'rightWrist': Offset(0.88, 0.29),
        'leftHip': Offset(0.44, 0.52),
        'rightHip': Offset(0.58, 0.54),
        'leftKnee': Offset(0.42, 0.73),
        'rightKnee': Offset(0.63, 0.73),
        'leftAnkle': Offset(0.40, 0.94),
        'rightAnkle': Offset(0.66, 0.94),
      },
    );
    final detectedPose = _createPose({
      for (final entry in customPose.customLandmarks!.entries)
        PoseLandmarkType.values.byName(entry.key): (
          entry.value.dx * 100,
          entry.value.dy * 100,
        ),
    });

    final result = PoseMatchingService.evaluate(detectedPose, customPose);

    expect(PoseMatchingService.supports(customPose), isTrue);
    expect(result.isMatched, isTrue);
    expect(result.score, greaterThanOrEqualTo(95));
  });

  test('matches a custom pose when the person is scaled and repositioned', () {
    final target = PoseItem(
      id: 'uploaded-reference',
      title: 'Uploaded reference',
      description: 'Detected reference joints',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: PoseMatchingService.customLandmarksFromPose(
        standingPose,
      ),
    );
    final detectedPose = _createPose({
      for (final entry in target.customLandmarks!.entries)
        PoseLandmarkType.values.byName(entry.key): (
          entry.value.dx * 500 + 200,
          entry.value.dy * 500 + 350,
        ),
    });

    final result = PoseMatchingService.evaluate(detectedPose, target);

    expect(result.isMatched, isTrue);
    expect(result.score, 100);
  });

  test('does not match when the arms differ from the reference pose', () {
    final targetLandmarks = PoseMatchingService.customLandmarksFromPose(
      standingPose,
    )!;
    final target = PoseItem(
      id: 'uploaded-reference',
      title: 'Uploaded reference',
      description: 'Detected reference joints',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: targetLandmarks,
    );
    final detectedPoints = {
      for (final entry in targetLandmarks.entries)
        PoseLandmarkType.values.byName(entry.key): (
          entry.value.dx * 100,
          entry.value.dy * 100,
        ),
    };
    detectedPoints[PoseLandmarkType.leftWrist] = (
      targetLandmarks['leftHip']!.dx * 100,
      targetLandmarks['leftHip']!.dy * 100,
    );
    detectedPoints[PoseLandmarkType.rightWrist] = (
      targetLandmarks['rightHip']!.dx * 100,
      targetLandmarks['rightHip']!.dy * 100,
    );

    final result = PoseMatchingService.evaluate(
      _createPose(detectedPoints),
      target,
    );

    expect(result.isMatched, isFalse);
    expect(result.score, lessThan(80));
  });

  test('requires the target shoulder and hip landmarks for a custom match', () {
    final targetLandmarks = PoseMatchingService.customLandmarksFromPose(
      standingPose,
    )!;
    final target = PoseItem(
      id: 'uploaded-reference',
      title: 'Uploaded reference',
      description: 'Detected reference joints',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: targetLandmarks,
    );
    final incompletePose = _createPose({
      for (final entry in targetLandmarks.entries)
        if (entry.key != PoseLandmarkType.leftShoulder.name)
          PoseLandmarkType.values.byName(entry.key): (
            entry.value.dx * 100,
            entry.value.dy * 100,
          ),
    });

    final result = PoseMatchingService.evaluate(incompletePose, target);

    expect(result.isMatched, isFalse);
    expect(result.score, 0);
    expect(result.feedback, contains('khớp chính'));
  });

  test('extracts normalized body landmarks from an uploaded-image pose', () {
    final landmarks = PoseMatchingService.customLandmarksFromPose(standingPose);
    expect(landmarks, isNotNull);
    final uploadedPose = PoseItem(
      id: 'uploaded-reference',
      title: 'Uploaded reference',
      description: 'Detected reference joints',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: landmarks!,
    );

    expect(landmarks.length, 12);
    expect(landmarks['leftShoulder'], const Offset(1 / 24, 0));
    expect(landmarks['rightAnkle'], const Offset(7 / 40, 1));
    expect(
      PoseMatchingService.evaluate(standingPose, uploadedPose).isMatched,
      isTrue,
    );
  });

  test('rejects uploaded-image poses without enough confident body joints', () {
    final incompletePose = _createPose({
      PoseLandmarkType.leftShoulder: const (40, 40),
      PoseLandmarkType.rightShoulder: const (60, 40),
      PoseLandmarkType.leftElbow: const (35, 60),
      PoseLandmarkType.rightElbow: const (65, 60),
      PoseLandmarkType.leftWrist: const (35, 80),
    });

    expect(PoseMatchingService.customLandmarksFromPose(incompletePose), isNull);
  });

  test('requires shoulders and hips when importing a pose reference', () {
    final poseWithoutHips = _createPose({
      PoseLandmarkType.leftShoulder: const (40, 40),
      PoseLandmarkType.rightShoulder: const (60, 40),
      PoseLandmarkType.leftElbow: const (35, 60),
      PoseLandmarkType.rightElbow: const (65, 60),
      PoseLandmarkType.leftWrist: const (35, 80),
      PoseLandmarkType.rightWrist: const (65, 80),
      PoseLandmarkType.leftKnee: const (44, 130),
      PoseLandmarkType.rightKnee: const (56, 130),
      PoseLandmarkType.leftAnkle: const (44, 160),
      PoseLandmarkType.rightAnkle: const (56, 160),
    });

    expect(
      PoseMatchingService.customLandmarksFromPose(poseWithoutHips),
      isNull,
    );
  });

  test('custom pose coordinates survive local storage serialization', () {
    const customPose = PoseItem(
      id: 'custom-rail',
      title: 'Tựa lan can',
      description: 'Custom skeleton',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: {
        'nose': Offset(0.5, 0.1),
        'leftShoulder': Offset(0.4, 0.23),
        'rightShoulder': Offset(0.6, 0.25),
        'leftElbow': Offset(0.34, 0.37),
        'leftWrist': Offset(0.35, 0.49),
        'leftHip': Offset(0.44, 0.52),
      },
    );

    final restored = PoseItem.fromMap(customPose.toMap());

    expect(restored.id, customPose.id);
    expect(restored.title, customPose.title);
    expect(restored.customLandmarks, customPose.customLandmarks);
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
