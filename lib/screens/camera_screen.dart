import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import '../widgets/ghost_overlay.dart';
import '../widgets/smart_grid.dart';
import '../services/camera_service.dart';

import 'package:camera/camera.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

  final CameraService _cameraService = CameraService();
  // Khởi tạo các trạng thái hiển thị
  double _ghostOpacity = 0.4;
  bool _isGridVisible = true;
  String? _selectedPosePath; // Ảnh mẫu đang chọn

  @override
  void initState() {
    super.initState();
    _cameraService.initializeCamera();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    await _cameraService.initializeCamera();
    setState(() {}); // Cập nhật giao diện sau khi camera được khởi tạo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Tầng dưới cùng: Camera Preview (Giả lập hoặc từ camera_service)
          Positioned.fill(
            child: (_cameraService.controller != null && _cameraService.controller!.value.isInitialized)
                ? CameraPreview(_cameraService.controller!)
                : const Center(
                    child: CircularProgressIndicator(
                      color: Colors.yellowAccent,
                    ),
                  ),
          ),

          // 2. Tầng lưới bố cục thông minh
          SmartGridWidget(showGrid: _isGridVisible, opacity: 0.6),

          // 3. Tầng Ghost Overlay (Ảnh mẫu mờ căn góc)[cite: 1]
          if (_selectedPosePath != null)
            GhostOverlayWidget(
              imagePath: _selectedPosePath!,
              opacity: _ghostOpacity,
            ),

          // 4. Tầng giao diện điều khiển (Control Panel & Thước cân bằng ở trên cùng)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header thanh công cụ trên (Tỷ lệ ảnh, bật tắt flash, v.v.)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("AngleCraft", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.grid_on, color: Colors.white),
                        onPressed: () => setState(() => _isGridVisible = !_isGridVisible),
                      ),
                    ],
                  ),
                ),
                
                // Footer nút chụp ảnh và chọn dáng
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Nút mở bộ sưu tập chọn dáng
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                        onPressed: () {
                          // TODO: Mở màn hình chọn ảnh mẫu (pose_catalog_screen.dart)
                          setState(() {
                            _selectedPosePath = "assets/poses/sample_pose.png"; // Ví dụ minh họa
                          });
                        },
                      ),
                      // Nút chụp ảnh chính
                      FloatingActionButton(
                        backgroundColor: Colors.yellowAccent,
                        onPressed: () async {
                          // Gọi hàm chụp và lưu ảnh
                          bool success = await _cameraService.takeAndSavePicture();
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Đã lưu ảnh vào bộ sưu tập thành công!")),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Chụp ảnh thất bại. Vui lòng thử lại.")),
                            );
                          }
                        },
                        child: const Icon(Icons.camera, color: Colors.black, size: 36),
                      ),
                      // Nút cài đặt/thêm hiệu ứng
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.white, size: 32),
                        onPressed: () {
                          // TODO: Mở bảng điều khiển độ mờ ghost overlay
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}