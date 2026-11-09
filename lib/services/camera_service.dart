import 'package:camera/camera.dart';
import 'package:gal/gal.dart'; // Import thư viện lưu ảnh vào thiết bị

class CameraService {
  CameraController? controller;
  List<CameraDescription>? cameras;

  // Khởi tạo camera
  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      controller = CameraController(
        cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller!.initialize();
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
      print("Lỗi khi chụp hoặc lưu ảnh: $e");
      return false;
    }
  }

  void dispose() {
    controller?.dispose();
  }
}

