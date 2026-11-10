import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_item.dart';

class PoseMatchResult {
  final bool isSupported;
  final bool isMatched;
  final int score;
  final String feedback;

  const PoseMatchResult({
    required this.isSupported,
    required this.isMatched,
    required this.score,
    required this.feedback,
  });
}

class PoseMatchingService {
  static const _confidenceThreshold = 0.35;

  static bool supports(PoseItem pose) =>
      pose.style == PoseStyle.standing || pose.style == PoseStyle.handOnHip;

  static PoseMatchResult evaluate(Pose? pose, PoseItem target) {
    if (!supports(target)) {
      return const PoseMatchResult(
        isSupported: false,
        isMatched: false,
        score: 0,
        feedback: 'AI thử nghiệm hiện hỗ trợ dáng đứng và tay đặt bên hông.',
      );
    }
    if (pose == null) {
      return const PoseMatchResult(
        isSupported: true,
        isMatched: false,
        score: 0,
        feedback: 'Đưa người mẫu vào khung hình để bắt đầu căn dáng.',
      );
    }

    final landmarks = pose.landmarks;
    final leftElbow = _jointAngle(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
    final rightElbow = _jointAngle(
      landmarks,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    );

    if (target.style == PoseStyle.handOnHip) {
      return _evaluateHandOnHip(landmarks, leftElbow, rightElbow);
    }
    return _evaluateStanding(landmarks, leftElbow, rightElbow);
  }

  static PoseMatchResult _evaluateStanding(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    double? leftElbow,
    double? rightElbow,
  ) {
    final elbows = [leftElbow, rightElbow].whereType<double>().toList();
    if (elbows.isEmpty) {
      return const PoseMatchResult(
        isSupported: true,
        isMatched: false,
        score: 0,
        feedback: 'Đưa vai, khuỷu tay và cổ tay vào khung hình.',
      );
    }

    final knees = [
      _jointAngle(
        landmarks,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      ),
      _jointAngle(
        landmarks,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      ),
    ].whereType<double>().toList();
    final armsStraight = elbows.every((angle) => angle >= 135);
    final legsStraight = knees.isEmpty || knees.every((angle) => angle >= 140);
    final elbowScore = _angleScore(elbows, 165, 35);
    final kneeScore = knees.isEmpty ? 100 : _angleScore(knees, 170, 35);
    final score = ((elbowScore + kneeScore) / 2).round();

    return PoseMatchResult(
      isSupported: true,
      isMatched: armsStraight && legsStraight,
      score: score,
      feedback: armsStraight
          ? legsStraight
                ? 'Giữ dáng, gần khớp rồi!'
                : 'Duỗi chân nhẹ và giữ người thẳng.'
          : 'Thả hai tay tự nhiên dọc theo thân người.',
    );
  }

  static PoseMatchResult _evaluateHandOnHip(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    double? leftElbow,
    double? rightElbow,
  ) {
    final torsoLengths = [
      _distance(
        _point(landmarks, PoseLandmarkType.leftShoulder),
        _point(landmarks, PoseLandmarkType.leftHip),
      ),
      _distance(
        _point(landmarks, PoseLandmarkType.rightShoulder),
        _point(landmarks, PoseLandmarkType.rightHip),
      ),
    ].whereType<double>().toList();
    final torsoLength = torsoLengths.isEmpty
        ? null
        : torsoLengths.reduce((first, second) => first + second) /
              torsoLengths.length;
    final leftWristNearHip = _isWristNearHip(
      landmarks,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftHip,
      torsoLength,
    );
    final rightWristNearHip = _isWristNearHip(
      landmarks,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightHip,
      torsoLength,
    );
    final leftHandOnHip =
        leftElbow != null &&
        leftElbow >= 90 &&
        leftElbow <= 155 &&
        leftWristNearHip;
    final rightHandOnHip =
        rightElbow != null &&
        rightElbow >= 90 &&
        rightElbow <= 155 &&
        rightWristNearHip;
    final validArms = [leftElbow, rightElbow].whereType<double>().toList();

    if (validArms.isEmpty || torsoLength == null || torsoLength == 0) {
      return const PoseMatchResult(
        isSupported: true,
        isMatched: false,
        score: 0,
        feedback: 'Đưa thân trên và hai tay vào khung hình.',
      );
    }

    final matched = leftHandOnHip || rightHandOnHip;
    final scores = [
      _handPositionScore(
        landmarks,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.leftHip,
        torsoLength,
        leftElbow,
      ),
      _handPositionScore(
        landmarks,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.rightHip,
        torsoLength,
        rightElbow,
      ),
    ];
    final score = matched
        ? 100
        : scores
              .reduce((first, second) => math.max(first, second).toDouble())
              .round();

    return PoseMatchResult(
      isSupported: true,
      isMatched: matched,
      score: score,
      feedback: matched
          ? 'Đẹp rồi! Giữ tay ở hông.'
          : 'Gập một tay và đưa bàn tay về phía hông.',
    );
  }

  static double _handPositionScore(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType wristType,
    PoseLandmarkType hipType,
    double torsoLength,
    double? elbowAngle,
  ) {
    final wristDistance = _distance(
      _point(landmarks, wristType),
      _point(landmarks, hipType),
    );
    if (wristDistance == null || elbowAngle == null) return 0;
    final distanceScore = (100 - wristDistance / torsoLength * 200)
        .clamp(0, 100)
        .toDouble();
    final bendScore = (100 - (elbowAngle - 125).abs() * 2)
        .clamp(0, 100)
        .toDouble();
    return (distanceScore + bendScore) / 2;
  }

  static bool _isWristNearHip(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType wristType,
    PoseLandmarkType hipType,
    double? torsoLength,
  ) {
    if (torsoLength == null || torsoLength == 0) return false;
    final distance = _distance(
      _point(landmarks, wristType),
      _point(landmarks, hipType),
    );
    return distance != null && distance <= torsoLength * 0.35;
  }

  static double _angleScore(List<double> angles, double target, double range) {
    final averageError =
        angles.fold<double>(
          0,
          (total, angle) => total + (angle - target).abs(),
        ) /
        angles.length;
    return (100 - averageError / range * 100).clamp(0, 100).toDouble();
  }

  static double? _jointAngle(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType firstType,
    PoseLandmarkType jointType,
    PoseLandmarkType lastType,
  ) {
    final first = _point(landmarks, firstType);
    final joint = _point(landmarks, jointType);
    final last = _point(landmarks, lastType);
    if (first == null || joint == null || last == null) return null;

    final firstVector = first - joint;
    final lastVector = last - joint;
    final denominator = firstVector.distance * lastVector.distance;
    if (denominator == 0) return null;
    final cosine =
        (firstVector.dx * lastVector.dx + firstVector.dy * lastVector.dy) /
        denominator;
    return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  static Offset? _point(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType type,
  ) {
    final landmark = landmarks[type];
    if (landmark == null || landmark.likelihood < _confidenceThreshold) {
      return null;
    }
    return Offset(landmark.x, landmark.y);
  }

  static double? _distance(Offset? first, Offset? second) =>
      first == null || second == null ? null : (first - second).distance;
}
