import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import '../widgets/ghost_overlay.dart';
import '../widgets/smart_grid.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Khởi tạo các trạng thái hiển thị
  double _ghostOpacity = 0.4;
  bool _isGridVisible = true;
  String? _selectedPosePath; // Ảnh mẫu đang chọn

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Tầng dưới cùng: Camera Preview (Giả lập hoặc từ camera_service)
          const Positioned.fill(
            child: Center(child: Text("Camera Preview Stream", style: TextStyle(color: Colors.white))),
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
                        onPressed: () {
                          // TODO: Gọi hàm chụp ảnh từ camera_service
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