import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

class UpdateService {
  // Thay thế bằng đường dẫn Repository GitHub của bạn (Ví dụ: owner/repo)
  static const String repoOwner = 'Chicky25'; 
  static const String repoName = 'AngleCraft';

  static Future<void> checkForUpdates(context, {required Function(String) onStatus}) async {
    try {
      onStatus("Đang kiểm tra phiên bản mới...");
      
      // 1. Lấy thông tin version hiện tại của app
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // Ví dụ: "1.0.0"

      // 2. Gọi API GitHub Releases lấy bản mới nhất
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestVersion = data['tag_name'] ?? ""; // Ví dụ: "v1.1.0"
        
        // Lấy link tải file .apk từ phần assets của release trên GitHub
        List assets = data['assets'];
        String apkUrl = "";
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'];
            break;
          }
        }

        // 3. So sánh version (bỏ chữ 'v' nếu có)
        String cleanCurrent = currentVersion.replaceAll('v', '');
        String cleanLatest = latestVersion.replaceAll('v', '');

        if (cleanLatest.compareTo(cleanCurrent) > 0 && apkUrl.isNotEmpty) {
          // Có bản mới -> Tiến hành tải về
          onStatus("Đang tải phiên bản $latestVersion...");
          await _downloadAndInstallApk(apkUrl, onStatus);
        } else {
          onStatus("Ứng dụng của bạn đã là phiên bản mới nhất.");
        }
      } else {
        onStatus("Không thể kết nối đến máy chủ cập nhật.");
      }
    } catch (e) {
      onStatus("Lỗi cập nhật: $e");
    }
  }

  static Future<void> _downloadAndInstallApk(String url, Function(String) onStatus) async {
    try {
      // Tải file APK vào thư mục tạm của điện thoại
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';

      final client = http.Client();
      final request = await client.send(http.Request('GET', Uri.parse(url)));
      final file = File(filePath);

      final sink = file.openWrite();
      await request.stream.pipe(sink);
      await sink.close();

      onStatus("Tải xong! Đang mở trình cài đặt...");

      // Mở file APK để hệ thống Android hiển thị bảng cài đặt đè
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        onStatus("Không thể mở trình cài đặt: ${result.message}");
      }
    } catch (e) {
      onStatus("Lỗi khi tải file APK: $e");
    }
  }
}