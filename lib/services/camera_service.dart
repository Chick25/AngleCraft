import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;
  List<CameraDescription>? cameras;

  Future<void> initialize() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      controller = CameraController(cameras![0], ResolutionPreset.high, enableAudio: false);
      await controller!.initialize();
    }
  }

  Future<XFile?> takePicture() async {
    if (controller == null && controller!.value.isInitialized) return null;
    try {
      final image = await controller!.takePicture();
      return image;
    } catch (e) {
      print('Error taking picture: $e');
      return null;
    }
  }

  void dispose() {
    controller?.dispose();
  }


}