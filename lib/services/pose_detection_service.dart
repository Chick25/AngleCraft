import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class DetectedPoseFrame {
  final Pose? pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  const DetectedPoseFrame({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });
}

class PoseDetectionService {
  PoseDetector? _detector;
  Future<void>? _activeProcessing;
  bool _isClosed = false;

  Future<DetectedPoseFrame?> processImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    if (_isClosed || _activeProcessing != null) return null;

    final processing = _processImage(image, camera, deviceOrientation);
    _activeProcessing = processing.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    try {
      return await processing;
    } finally {
      _activeProcessing = null;
    }
  }

  Future<Pose?> detectPoseInFile(String filePath) async {
    if (_isClosed) {
      throw StateError('Bộ nhận diện dáng đã được đóng.');
    }
    if (_activeProcessing != null) {
      throw StateError('Bộ nhận diện dáng đang xử lý khung hình camera.');
    }

    final processing = _processFile(filePath);
    _activeProcessing = processing.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    try {
      return await processing;
    } finally {
      _activeProcessing = null;
    }
  }

  Future<Pose?> _processFile(String filePath) async {
    final detector = _detector ??= _createDetector();
    final poses = await detector.processImage(
      InputImage.fromFilePath(filePath),
    );
    return poses.isEmpty ? null : poses.first;
  }

  Future<DetectedPoseFrame> _processImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    if (image.planes.isEmpty) {
      throw StateError('Camera không cung cấp dữ liệu ảnh để nhận diện.');
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        format != InputImageFormat.nv21 ||
        image.planes.length != 1) {
      throw UnsupportedError(
        'Khung hình Android phải ở định dạng NV21 một mặt phẳng để nhận diện.',
      );
    }

    final rotation = _rotationForCamera(camera, deviceOrientation);
    final plane = image.planes.first;
    final inputImage = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
    final detector = _detector ??= _createDetector();
    final poses = await detector.processImage(inputImage);

    return DetectedPoseFrame(
      pose: poses.isEmpty ? null : poses.first,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      lensDirection: camera.lensDirection,
    );
  }

  PoseDetector _createDetector() => PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );

  InputImageRotation _rotationForCamera(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final deviceRotation = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation) ??
        InputImageRotation.rotation0deg;
  }

  Future<void> close() async {
    _isClosed = true;
    await _activeProcessing;
    await _detector?.close();
    _detector = null;
  }
}
