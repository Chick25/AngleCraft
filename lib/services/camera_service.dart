import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import 'media_gallery_service.dart';

class GalleryExportException implements Exception {
  final String localPath;
  final Object cause;

  const GalleryExportException(this.localPath, this.cause);

  @override
  String toString() => 'Không thể lưu ảnh vào thư viện thiết bị: $cause';
}

class CameraService {
  CameraController? controller;
  List<CameraDescription>? cameras;

  // Khởi tạo camera
  Future<void> initializeCamera() async {
    final available = await availableCameras();
    cameras = available;
    if (available.isEmpty) {
      throw StateError('Không tìm thấy camera trên thiết bị.');
    }

    final camera = available.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => available.first,
    );
    final cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    controller = cameraController;
    try {
      await cameraController.initialize();
    } catch (_) {
      await cameraController.dispose();
      if (identical(controller, cameraController)) controller = null;
      rethrow;
    }
  }

  // Hàm chụp và lưu thẳng vào thư viện ảnh của điện thoại
  Future<bool> takeAndSavePicture() async {
    try {
      return await captureAndSavePicture() != null;
    } catch (e) {
      debugPrint('Lỗi khi chụp hoặc lưu ảnh: $e');
      return false;
    }
  }

  Future<String?> captureAndSavePicture() async {
    final temporaryPath = await capturePicture();
    if (temporaryPath == null) return null;
    return saveCapturedPicture(temporaryPath);
  }

  Future<String?> capturePicture() async {
    final activeController = controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return null;
    }
    final capturedImage = await activeController.takePicture();
    return capturedImage.path;
  }

  Future<String> saveCapturedPicture(String sourcePath) async {
    final savedPhoto = await MediaGalleryService.saveCapture(sourcePath);
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw StateError('Bạn chưa cấp quyền lưu ảnh vào thư viện thiết bị.');
      }
      await Gal.putImage(savedPhoto.path);
    } catch (error) {
      throw GalleryExportException(savedPhoto.path, error);
    }
    return savedPhoto.path;
  }

  Future<void> dispose() async {
    final activeController = controller;
    controller = null;
    await activeController?.dispose();
  }
}
