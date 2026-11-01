import 'package:flutter/material.dart';
import '../services/update_service.dart'; // Import service cập nhật vừa viết

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _statusMessage = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Cài đặt ứng dụng", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nút bấm kiểm tra cập nhật
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellowAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                UpdateService.checkForUpdates(context, onStatus: (status) {
                  setState(() {
                    _statusMessage = status;
                  });
                });
              },
              icon: const Icon(Icons.system_update),
              label: const Text("Kiểm tra phiên bản mới", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            
            // Hiển thị trạng thái kiểm tra/tải về
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}