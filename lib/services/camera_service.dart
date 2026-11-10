import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

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
    controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller!.initialize();
    } catch (_) {
      await controller!.dispose();
      controller = null;
      rethrow;
    }
  }

  // Hàm chụp và lưu thẳng vào thư viện ảnh của điện thoại
  Future<bool> takeAndSavePicture() async {
    if (controller == null || !controller!.value.isInitialized) return false;

    try {
      // 1. Tiến hành chụp ảnh (trả về file tạm trên thiết bị)
      XFile capturedImage = await controller!.takePicture();

      // 2. Lưu file ảnh đó trực tiếp vào bộ sưu tập (Gallery) của máy Android
      await Gal.putImage(capturedImage.path);

      return true; // Lưu thành công
    } catch (e) {
      debugPrint('Lỗi khi chụp hoặc lưu ảnh: $e');
      return false;
    }
  }

  void dispose() {
    controller?.dispose();
  }
}
