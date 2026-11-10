import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/sample_poses.dart';
import '../models/saved_angle.dart';
import '../widgets/ghost_overlay.dart';
import '../widgets/level_indicator.dart';
import '../widgets/pose_skeleton_overlay.dart';
import 'angle_vault_screen.dart';
import 'gallery_screen.dart';
import 'pose_catalog_screen.dart';
import '../widgets/smart_grid.dart';
import '../widgets/smart_grid_painter.dart';
import '../models/pose_item.dart';
import '../services/camera_service.dart';
import '../services/pose_detection_service.dart';
import '../services/pose_matching_service.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  final SensorService _sensorService = SensorService();
  final ValueNotifier<({double roll, double pitch})?> _levelReading =
      ValueNotifier(null);
  String? _sensorError;
  // Khởi tạo các trạng thái hiển thị
  double _ghostOpacity = 0.4;
  double _gridOpacity = 0.72;
  bool _isGridVisible = true;
  GridType _gridType = GridType.thirds;
  String? _selectedPosePath;
  PoseItem? _selectedCatalogPose;
  GhostTransform _ghostTransform = const GhostTransform();
  bool _isPickingPose = false;
  int _ghostRevision = 0;

  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isCaptureInProgress = false;
  String? _cameraError;
  bool _isPoseAssistEnabled = false;
  int _poseMatchStreak = 0;
  DetectedPoseFrame? _detectedPoseFrame;
  PoseMatchResult? _poseMatchResult;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _sensorService.startListening(
      (roll, pitch) {
        _levelReading.value = (roll: roll, pitch: pitch);
        if (_sensorError != null && mounted) {
          setState(() => _sensorError = null);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _sensorError = 'Không thể đọc cảm biến';
          _levelReading.value = null;
        });
      },
    );
  }

  @override
  void dispose() {
    unawaited(_releaseCameraResources());
    _sensorService.stopListening();
    _levelReading.dispose();
    super.dispose();
  }

  Future<void> _releaseCameraResources() async {
    final controller = _cameraService.controller;
    if (controller != null) await _stopImageStream(controller);
    await _poseDetectionService.close();
    await _cameraService.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.initializeCamera();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Không thể khởi tạo camera: $error';
      });
    }
  }

  String _gridLabel(GridType type) {
    switch (type) {
      case GridType.thirds:
        return 'Quy tắc 1/3';
      case GridType.goldenRatio:
        return 'Tỷ lệ vàng';
      case GridType.goldenTriangle:
        return 'Tam giác vàng';
      case GridType.diagonal:
        return 'Đường chéo';
    }
  }

  Future<void> _showGridSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Độ mờ lớp phủ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.grid_on, color: Colors.white70),
                    Expanded(
                      child: Slider(
                        value: _gridOpacity,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: '${(_gridOpacity * 100).round()}%',
                        activeColor: Colors.yellowAccent,
                        onChanged: (value) {
                          setState(() => _gridOpacity = value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(_gridOpacity * 100).round()}%',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Độ mờ ảnh mẫu',
                  style: TextStyle(color: Colors.white),
                ),
                Row(
                  children: [
                    const Icon(Icons.image_outlined, color: Colors.white70),
                    Expanded(
                      child: Slider(
                        value: _ghostOpacity,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: '${(_ghostOpacity * 100).round()}%',
                        activeColor: Colors.yellowAccent,
                        onChanged: (value) {
                          setState(() => _ghostOpacity = value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(_ghostOpacity * 100).round()}%',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickGhostImage() async {
    if (_isPickingPose) return;

    final messenger = ScaffoldMessenger.of(context);
    if (_isPoseAssistEnabled) await _stopPoseAssist();
    if (!mounted) return;
    setState(() => _isPickingPose = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _selectedPosePath = image.path;
        _selectedCatalogPose = null;
        _ghostTransform = const GhostTransform();
        _ghostRevision++;
      });
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh mẫu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingPose = false);
      }
    }
  }

  void _resetGhostTransform() {
    setState(() {
      _ghostTransform = const GhostTransform();
      _ghostRevision++;
    });
  }

  void _removeGhostImage() {
    if (_isPoseAssistEnabled) unawaited(_stopPoseAssist());
    setState(() {
      _selectedPosePath = null;
      _selectedCatalogPose = null;
      _ghostTransform = const GhostTransform();
    });
  }

  Future<void> _selectCatalogPose() async {
    if (_isPoseAssistEnabled) await _stopPoseAssist();
    if (!mounted) return;
    final pose = await Navigator.of(context).push<PoseItem>(
      MaterialPageRoute(builder: (_) => const PoseCatalogScreen()),
    );
    if (!mounted || pose == null) return;
    setState(() {
      _selectedCatalogPose = pose;
      _selectedPosePath = null;
      _ghostTransform = const GhostTransform();
      _ghostRevision++;
      _poseMatchStreak = 0;
      _detectedPoseFrame = null;
      _poseMatchResult =
          pose.style == PoseStyle.standing || pose.style == PoseStyle.handOnHip
          ? null
          : PoseMatchingService.evaluate(null, pose);
    });
  }

  Future<void> _openAngleVault() async {
    if (_isPoseAssistEnabled) await _stopPoseAssist();
    if (!mounted) return;
    final angle = await Navigator.of(context).push<SavedAngle>(
      MaterialPageRoute(builder: (_) => const AngleVaultScreen()),
    );
    if (!mounted || angle == null) return;

    PoseItem? pose;
    for (final item in samplePoses) {
      if (item.id == angle.poseId) {
        pose = item;
        break;
      }
    }
    final gridType = GridType.values.firstWhere(
      (type) => type.name == angle.gridType,
      orElse: () => GridType.thirds,
    );
    setState(() {
      _selectedCatalogPose = pose;
      _selectedPosePath = pose == null ? angle.ghostImagePath : null;
      _ghostTransform = angle.ghostTransform;
      _ghostOpacity = angle.ghostOpacity;
      _gridOpacity = angle.gridOpacity;
      _isGridVisible = angle.isGridVisible;
      _gridType = gridType;
      _ghostRevision++;
      _poseMatchStreak = 0;
      _detectedPoseFrame = null;
      _poseMatchResult = pose == null
          ? null
          : PoseMatchingService.evaluate(null, pose);
    });
  }

  SavedAngle _newAngleSnapshot() {
    final now = DateTime.now();
    return SavedAngle(
      id: now.microsecondsSinceEpoch.toString(),
      name: 'Góc chụp',
      createdAt: now,
      photoPath: '',
      ghostImagePath: _selectedPosePath,
      poseId: _selectedCatalogPose?.id,
      gridType: _gridType.name,
      isGridVisible: _isGridVisible,
      gridOpacity: _gridOpacity,
      ghostOpacity: _ghostOpacity,
      ghostTransform: _ghostTransform,
    );
  }

  Future<void> _saveCapturedAngle(String photoPath, SavedAngle snapshot) async {
    final nameController = TextEditingController(
      text: 'Góc chụp ${snapshot.createdAt.day}/${snapshot.createdAt.month}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu vào Angle Vault'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Tên góc chụp',
            hintText: 'Ví dụ: Hoàng hôn bên biển',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (!mounted || name == null) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên góc chụp.')),
      );
      return;
    }

    try {
      await StorageService.saveAngle(
        snapshot.copyWith(name: name, photoPath: photoPath),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu góc chụp vào Angle Vault.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu góc chụp: $error')));
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCaptureInProgress) return;
    final snapshot = _newAngleSnapshot();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isCapturing = true;
      _isCaptureInProgress = true;
    });
    String? capturedPath;
    String? galleryWarning;
    Object? captureError;
    try {
      if (_isPoseAssistEnabled) await _stopPoseAssist();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      final temporaryPath = await _cameraService.capturePicture();
      if (temporaryPath == null) {
        throw StateError('Camera chưa sẵn sàng.');
      }

      if (mounted) setState(() => _isCapturing = false);
      capturedPath = await _cameraService.saveCapturedPicture(temporaryPath);
    } on GalleryExportException catch (error) {
      capturedPath = error.localPath;
      galleryWarning = error.toString();
    } catch (error) {
      captureError = error;
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isCaptureInProgress = false;
        });
      }
    }

    if (!mounted) return;
    if (capturedPath == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            captureError == null
                ? 'Camera chưa sẵn sàng.'
                : captureError is StateError
                ? captureError.message.toString()
                : 'Chụp ảnh thất bại: $captureError',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          galleryWarning == null
              ? 'Đã lưu ảnh vào bộ sưu tập.'
              : 'Ảnh đã lưu trong ứng dụng. $galleryWarning',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'LƯU GÓC',
          onPressed: () =>
              unawaited(_saveCapturedAngle(capturedPath!, snapshot)),
        ),
      ),
    );
  }

  Future<void> _openGallery() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const GalleryScreen()));
  }

  Future<void> _togglePoseAssist() async {
    if (_isPoseAssistEnabled) {
      await _stopPoseAssist();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (_selectedCatalogPose == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn một dáng trong thư viện trước.'),
        ),
      );
      return;
    }
    if (!PoseMatchingService.supports(_selectedCatalogPose!)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'AI thử nghiệm hiện hỗ trợ dáng đứng và tay đặt bên hông.',
          ),
        ),
      );
      return;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Hướng dẫn dáng bằng AI hiện hỗ trợ Android.'),
        ),
      );
      return;
    }

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Camera chưa sẵn sàng.')),
      );
      return;
    }

    setState(() {
      _isPoseAssistEnabled = true;
      _poseMatchStreak = 0;
      _detectedPoseFrame = null;
      _poseMatchResult = null;
    });
    try {
      await controller.startImageStream((image) {
        _processPoseFrame(image, controller);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPoseAssistEnabled = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể bật nhận diện dáng: $error')),
      );
    }
  }

  Future<void> _stopPoseAssist() async {
    final controller = _cameraService.controller;
    if (mounted) {
      setState(() {
        _isPoseAssistEnabled = false;
        _poseMatchStreak = 0;
        _detectedPoseFrame = null;
        _poseMatchResult = null;
      });
    }
    if (controller != null) await _stopImageStream(controller);
  }

  Future<void> _stopImageStream(CameraController controller) async {
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  Future<void> _processPoseFrame(
    CameraImage image,
    CameraController controller,
  ) async {
    if (!_isPoseAssistEnabled || _selectedCatalogPose == null) return;
    try {
      final frame = await _poseDetectionService.processImage(
        image,
        controller.description,
        controller.value.deviceOrientation,
      );
      if (!mounted || !_isPoseAssistEnabled || frame == null) return;
      final result = PoseMatchingService.evaluate(
        frame.pose,
        _selectedCatalogPose!,
      );
      setState(() {
        _detectedPoseFrame = frame;
        _poseMatchResult = result;
        _poseMatchStreak = result.isMatched
            ? (_poseMatchStreak + 1).clamp(0, 3).toInt()
            : 0;
      });
    } catch (error) {
      if (!mounted || !_isPoseAssistEnabled) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isPoseAssistEnabled = false);
      await _stopImageStream(controller);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi nhận diện dáng: $error')),
      );
    }
  }

  Widget _buildPoseAssistStatus() {
    final isMatched = _poseMatchStreak >= 3;
    final color = isMatched ? Colors.greenAccent : Colors.yellowAccent;
    final result = _poseMatchResult;
    final message =
        result?.feedback ??
        (_detectedPoseFrame == null
            ? 'Đang tìm người trong khung hình...'
            : 'Đang phân tích tư thế...');

    return Container(
      key: const ValueKey('poseAssistStatus'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(
            isMatched ? Icons.check_circle : Icons.accessibility_new,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMatched ? 'ĐÃ KHỚP' : 'ĐANG CĂN DÁNG',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          if (result != null && result.isSupported) ...[
            const SizedBox(width: 8),
            Text(
              '${result.score}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraFrame() {
    final controller = _cameraService.controller;
    if (!_isInitialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: _cameraError != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _cameraError!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
            : const CircularProgressIndicator(color: Colors.yellowAccent),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final cameraAspectRatio = controller.value.aspectRatio;
        final frameAspectRatio = isLandscape
            ? cameraAspectRatio
            : 1 / cameraAspectRatio;

        return Center(
          child: AspectRatio(
            aspectRatio: frameAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                if (!_isCapturing) ...[
                  SmartGridWidget(
                    showGrid: _isGridVisible,
                    gridType: _gridType,
                    opacity: _gridOpacity,
                  ),
                  if (_selectedPosePath != null || _selectedCatalogPose != null)
                    GhostOverlayWidget(
                      key: ValueKey(
                        '${_selectedCatalogPose?.id ?? _selectedPosePath}-$_ghostRevision',
                      ),
                      imagePath: _selectedPosePath,
                      pose: _selectedCatalogPose,
                      opacity: _ghostOpacity,
                      isAsset: false,
                      initialTransform: _ghostTransform,
                      onTransformEnd: (transform) {
                        _ghostTransform = transform;
                      },
                    ),
                  if (_isPoseAssistEnabled &&
                      _detectedPoseFrame?.pose != null &&
                      _detectedPoseFrame != null)
                    Positioned.fill(
                      child: PoseSkeletonOverlay(
                        pose: _detectedPoseFrame!.pose!,
                        imageSize: _detectedPoseFrame!.imageSize,
                        rotation: _detectedPoseFrame!.rotation,
                        lensDirection: _detectedPoseFrame!.lensDirection,
                        isMatched: _poseMatchStreak >= 3,
                      ),
                    ),
                  if (_selectedPosePath != null || _selectedCatalogPose != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _GhostActionButton(
                            tooltip: 'Đặt lại vị trí ảnh mẫu',
                            icon: Icons.restart_alt,
                            onPressed: _resetGhostTransform,
                          ),
                          const SizedBox(width: 8),
                          _GhostActionButton(
                            tooltip: 'Gỡ ảnh mẫu',
                            icon: Icons.close,
                            onPressed: _removeGhostImage,
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Keep the preview at the sensor aspect ratio so it is never stretched.
          Positioned.fill(child: _buildCameraFrame()),

          // 4. Tầng giao diện điều khiển (Control Panel & Thước cân bằng ở trên cùng)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header thanh công cụ trên (Tỷ lệ ảnh, bật tắt flash, v.v.)
                if (!_isCapturing)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "AngleCraft",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: _isPoseAssistEnabled
                                      ? 'Tắt hướng dẫn dáng bằng AI'
                                      : 'Bật hướng dẫn dáng bằng AI',
                                  icon: Icon(
                                    Icons.center_focus_strong,
                                    color: _isPoseAssistEnabled
                                        ? (_poseMatchStreak >= 3
                                              ? Colors.greenAccent
                                              : Colors.yellowAccent)
                                        : Colors.white,
                                  ),
                                  onPressed: _togglePoseAssist,
                                ),
                                IconButton(
                                  tooltip: 'Mở thư viện dáng chụp',
                                  icon: const Icon(
                                    Icons.accessibility_new,
                                    color: Colors.white,
                                  ),
                                  onPressed: _selectCatalogPose,
                                ),
                                PopupMenuButton<GridType>(
                                  tooltip: 'Chọn kiểu lưới',
                                  initialValue: _gridType,
                                  onSelected: (type) =>
                                      setState(() => _gridType = type),
                                  itemBuilder: (context) => GridType.values
                                      .map(
                                        (type) => PopupMenuItem<GridType>(
                                          value: type,
                                          child: Text(_gridLabel(type)),
                                        ),
                                      )
                                      .toList(),
                                  icon: const Icon(
                                    Icons.grid_4x4,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  tooltip: _isGridVisible
                                      ? 'Ẩn lưới'
                                      : 'Hiện lưới',
                                  icon: Icon(
                                    _isGridVisible
                                        ? Icons.grid_on
                                        : Icons.grid_off,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => setState(
                                    () => _isGridVisible = !_isGridVisible,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Mở bộ sưu tập ảnh',
                              onPressed: _openGallery,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Mở Angle Vault',
                              onPressed: _openAngleVault,
                              icon: const Icon(
                                Icons.bookmarks_outlined,
                                color: Colors.yellowAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<({double roll, double pitch})?>(
                          valueListenable: _levelReading,
                          builder: (context, reading, child) =>
                              LevelIndicatorWidget(
                                roll: reading?.roll ?? 0,
                                pitch: reading?.pitch ?? 0,
                                isAvailable:
                                    reading != null && _sensorError == null,
                                errorMessage:
                                    _sensorError ?? 'Đang đọc cảm biến',
                              ),
                        ),
                      ],
                    ),
                  ),

                if (!_isCapturing && _isPoseAssistEnabled)
                  _buildPoseAssistStatus(),

                // Footer nút chụp ảnh và chọn dáng
                if (!_isCapturing)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Nút mở bộ sưu tập chọn dáng
                        IconButton(
                          icon: _isPickingPose
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.yellowAccent,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.white,
                                  size: 32,
                                ),
                          tooltip: _selectedPosePath == null
                              ? 'Chọn ảnh mẫu từ thư viện'
                              : 'Đổi ảnh mẫu',
                          onPressed: _isPickingPose ? null : _pickGhostImage,
                        ),
                        // Nút chụp ảnh chính
                        FloatingActionButton(
                          backgroundColor: Colors.yellowAccent,
                          onPressed: _isCaptureInProgress
                              ? null
                              : _capturePhoto,
                          child: _isCaptureInProgress
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera,
                                  color: Colors.black,
                                  size: 36,
                                ),
                        ),
                        // Nút cài đặt/thêm hiệu ứng
                        IconButton(
                          icon: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 32,
                          ),
                          tooltip: 'Điều chỉnh độ mờ',
                          onPressed: _showGridSettings,
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

class _GhostActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _GhostActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
