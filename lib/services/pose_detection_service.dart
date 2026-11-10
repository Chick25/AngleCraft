import 'dart:typed_data';

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

  Future<DetectedPoseFrame> _processImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    if (image.planes.isEmpty) {
      throw StateError('Camera không cung cấp dữ liệu ảnh để nhận diện.');
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      throw UnsupportedError(
        'Định dạng khung hình camera không được ML Kit hỗ trợ.',
      );
    }

    final rotation = _rotationForCamera(camera, deviceOrientation);
    final bytes = BytesBuilder(copy: false);
    for (final plane in image.planes) {
      bytes.add(plane.bytes);
    }

    final inputImage = InputImage.fromBytes(
      bytes: bytes.takeBytes(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
    final detector = _detector ??= PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
    final poses = await detector.processImage(inputImage);

    return DetectedPoseFrame(
      pose: poses.isEmpty ? null : poses.first,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      lensDirection: camera.lensDirection,
    );
  }

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
