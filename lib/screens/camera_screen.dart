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
  static const _poseFrameInterval = Duration(milliseconds: 100);

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
  PoseItem? _selectedUploadedPose;
  String? _uploadedPoseError;
  final ValueNotifier<GhostTransform> _ghostTransform = ValueNotifier(
    const GhostTransform(),
  );
  bool _isPickingPose = false;
  int _ghostRevision = 0;

  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isCaptureInProgress = false;
  String? _cameraError;
  final GlobalKey _cameraPreviewKey = GlobalKey();
  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  double _zoomLevel = 1;
  double _appliedZoomLevel = 1;
  int _zoomRequestId = 0;
  Timer? _zoomDebounce;
  double _minExposureOffset = 0;
  double _maxExposureOffset = 0;
  double _exposureOffset = 0;
  double _appliedExposureOffset = 0;
  String? _exposureError;
  int _exposureRequestId = 0;
  Timer? _exposureDebounce;
  ({double value, int requestId})? _pendingExposureRequest;
  bool _isApplyingExposureRequest = false;
  Offset? _focusPoint;
  bool _isExposureControlVisible = false;
  bool _isFocusIndicatorVisible = false;
  Timer? _focusIndicatorTimer;
  double _pinchStartZoom = 1;
  bool _isCameraPinchZoomEnabled = false;
  bool _isZoomControlVisible = false;
  bool _isPoseAssistEnabled = false;
  bool _areCameraSlidersSuspended = false;
  DateTime? _lastPoseFrameStartedAt;
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
    _zoomDebounce?.cancel();
    _exposureDebounce?.cancel();
    _focusIndicatorTimer?.cancel();
    unawaited(_releaseCameraResources());
    _sensorService.stopListening();
    _levelReading.dispose();
    _ghostTransform.dispose();
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
      final controller = _cameraService.controller!;
      final minimumZoom = await controller.getMinZoomLevel();
      final maximumZoom = await controller.getMaxZoomLevel();
      var minimumExposure = 0.0;
      var maximumExposure = 0.0;
      String? exposureError;
      try {
        final supportedMinimum = await controller.getMinExposureOffset();
        final supportedMaximum = await controller.getMaxExposureOffset();
        if (supportedMinimum > supportedMaximum) {
          throw StateError('Camera trả về dải phơi sáng không hợp lệ.');
        }
        minimumExposure = supportedMinimum;
        maximumExposure = supportedMaximum;
        if (minimumExposure == maximumExposure) {
          exposureError = 'Camera không hỗ trợ điều chỉnh phơi sáng.';
        }
      } catch (error) {
        exposureError = 'Không thể đọc dải phơi sáng: $error';
      }
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _minZoomLevel = minimumZoom;
        _maxZoomLevel = maximumZoom;
        _zoomLevel = minimumZoom;
        _appliedZoomLevel = minimumZoom;
        _minExposureOffset = minimumExposure;
        _maxExposureOffset = maximumExposure;
        _exposureOffset = 0.clamp(minimumExposure, maximumExposure).toDouble();
        _appliedExposureOffset = _exposureOffset;
        _exposureError = exposureError;
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
    setState(() {
      _isPickingPose = true;
      _areCameraSlidersSuspended = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _selectedPosePath = image.path;
        _selectedCatalogPose = null;
        _selectedUploadedPose = null;
        _uploadedPoseError = null;
        _ghostTransform.value = const GhostTransform();
        _ghostRevision++;
      });
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        const message =
            'AI phân tích ảnh mẫu hiện chỉ hỗ trợ Android. '
            'Ảnh vẫn dùng được để căn thủ công.';
        setState(() => _uploadedPoseError = message);
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      try {
        final detectedPose = await _poseDetectionService.detectPoseInFile(
          image.path,
        );
        final landmarks = detectedPose == null
            ? null
            : PoseMatchingService.customLandmarksFromPose(detectedPose);
        if (!mounted) return;
        if (landmarks == null) {
          const message =
              'Không tìm thấy đủ khớp cơ thể trong ảnh mẫu. '
              'Ảnh vẫn dùng được để căn thủ công.';
          setState(() => _uploadedPoseError = message);
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        setState(() {
          _selectedUploadedPose = PoseItem(
            id: 'uploaded-${DateTime.now().microsecondsSinceEpoch}',
            title: 'Dáng từ ảnh mẫu',
            description: 'Dáng được nhận diện từ ảnh đã chọn.',
            category: PoseCategory.travel,
            style: PoseStyle.standing,
            customLandmarks: landmarks,
          );
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Đã phân tích dáng ảnh mẫu. Bật hướng dẫn AI để căn theo dáng.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        final message =
            'Không thể phân tích dáng trong ảnh mẫu: $error. '
            'Ảnh vẫn dùng được để căn thủ công.';
        setState(() => _uploadedPoseError = message);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh mẫu: $error')),
      );
    } finally {
      if (mounted) {
        await WidgetsBinding.instance.endOfFrame;
        setState(() {
          _isPickingPose = false;
          _areCameraSlidersSuspended = false;
        });
      }
    }
  }

  void _resetGhostTransform() {
    setState(() {
      _ghostTransform.value = const GhostTransform();
      _ghostRevision++;
    });
  }

  void _setGhostScale(double scale) {
    _ghostTransform.value = GhostTransform(
      offsetX: _ghostTransform.value.offsetX,
      offsetY: _ghostTransform.value.offsetY,
      scale: scale,
      rotation: _ghostTransform.value.rotation,
    );
  }

  void _removeGhostImage() {
    if (_isPoseAssistEnabled) unawaited(_stopPoseAssist());
    setState(() {
      _selectedPosePath = null;
      _selectedCatalogPose = null;
      _selectedUploadedPose = null;
      _uploadedPoseError = null;
      _ghostTransform.value = const GhostTransform();
    });
  }

  Future<T?> _withCameraSlidersSuspended<T>(
    Future<T?> Function() action,
  ) async {
    setState(() => _areCameraSlidersSuspended = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _areCameraSlidersSuspended = false);
      }
    }
  }

  Future<void> _selectCatalogPose() async {
    if (_isPoseAssistEnabled) await _stopPoseAssist();
    if (!mounted) return;
    final pose = await _withCameraSlidersSuspended(
      () => Navigator.of(context).push<PoseItem>(
        MaterialPageRoute(builder: (_) => const PoseCatalogScreen()),
      ),
    );
    if (!mounted || pose == null) return;
    setState(() {
      _selectedCatalogPose = pose;
      _selectedPosePath = null;
      _selectedUploadedPose = null;
      _uploadedPoseError = null;
      _ghostTransform.value = const GhostTransform();
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
    final angle = await _withCameraSlidersSuspended(
      () => Navigator.of(context).push<SavedAngle>(
        MaterialPageRoute(builder: (_) => const AngleVaultScreen()),
      ),
    );
    if (!mounted || angle == null) return;

    PoseItem? pose;
    for (final item in [...samplePoses, ...StorageService.getCustomPoses()]) {
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
      _selectedUploadedPose = null;
      _uploadedPoseError = null;
      _ghostTransform.value = angle.ghostTransform;
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
      ghostTransform: _ghostTransform.value,
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
    await _withCameraSlidersSuspended(
      () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const GalleryScreen())),
    );
  }

  Future<void> _togglePoseAssist() async {
    if (_isPoseAssistEnabled) {
      await _stopPoseAssist();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final targetPose = _selectedCatalogPose ?? _selectedUploadedPose;
    if (targetPose == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _uploadedPoseError ??
                'Hãy chọn một dáng trong thư viện hoặc ảnh mẫu có người.',
          ),
        ),
      );
      return;
    }
    if (!PoseMatchingService.supports(targetPose)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'AI hiện hỗ trợ dáng đứng, tay đặt bên hông và dáng tùy chỉnh.',
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
      _lastPoseFrameStartedAt = null;
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

  void _scheduleZoom(double value) {
    _zoomRequestId++;
    setState(() => _zoomLevel = value);
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(
      const Duration(milliseconds: 100),
      () => _applyZoom(value),
    );
  }

  void _startCameraZoomGesture(ScaleStartDetails details) {
    _pinchStartZoom = _zoomLevel;
  }

  void _updateCameraZoomGesture(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final zoom = (_pinchStartZoom * details.scale)
        .clamp(_minZoomLevel, _maxZoomLevel)
        .toDouble();
    _scheduleZoom(zoom);
  }

  Future<void> _applyZoom(double value) async {
    _zoomDebounce?.cancel();
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;
    final requestId = ++_zoomRequestId;
    try {
      await controller.setZoomLevel(value);
      if (!mounted || requestId != _zoomRequestId) return;
      setState(() {
        _zoomLevel = value;
        _appliedZoomLevel = value;
      });
    } catch (error) {
      if (!mounted || requestId != _zoomRequestId) return;
      setState(() => _zoomLevel = _appliedZoomLevel);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thay đổi mức zoom: $error')),
      );
    }
  }

  Future<void> _focusAt(Offset localPosition) async {
    final renderObject = _cameraPreviewKey.currentContext?.findRenderObject();
    final controller = _cameraService.controller;
    if (renderObject is! RenderBox ||
        controller == null ||
        !controller.value.isInitialized ||
        renderObject.size.isEmpty) {
      return;
    }

    final displayPoint = Offset(
      (localPosition.dx / renderObject.size.width).clamp(0.0, 1.0).toDouble(),
      (localPosition.dy / renderObject.size.height).clamp(0.0, 1.0).toDouble(),
    );
    final cameraPoint =
        controller.description.lensDirection == CameraLensDirection.front
        ? Offset(1 - displayPoint.dx, displayPoint.dy)
        : displayPoint;
    _focusIndicatorTimer?.cancel();
    setState(() {
      _focusPoint = displayPoint;
      _isFocusIndicatorVisible = true;
    });
    _focusIndicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isFocusIndicatorVisible = false);
    });

    final errors = <String>[];
    try {
      await controller.setFocusPoint(cameraPoint);
    } catch (error) {
      errors.add('lấy nét: $error');
    }
    try {
      await controller.setExposurePoint(cameraPoint);
    } catch (error) {
      errors.add('đo sáng: $error');
    }
    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể ${errors.join(' hoặc ')} tại điểm chạm.'),
        ),
      );
    }
  }

  void _toggleExposureControl() {
    setState(() => _isExposureControlVisible = !_isExposureControlVisible);
  }

  void _scheduleExposureOffset(double value) {
    final boundedValue = value
        .clamp(_minExposureOffset, _maxExposureOffset)
        .toDouble();
    _exposureRequestId++;
    setState(() => _exposureOffset = boundedValue);
    _exposureDebounce?.cancel();
    final requestId = _exposureRequestId;
    _exposureDebounce = Timer(
      const Duration(milliseconds: 50),
      () => _queueExposureOffset(boundedValue, requestId),
    );
  }

  void _applyExposureOffset(double value) {
    _exposureDebounce?.cancel();
    _queueExposureOffset(
      value.clamp(_minExposureOffset, _maxExposureOffset).toDouble(),
      _exposureRequestId,
    );
  }

  void _queueExposureOffset(double value, int requestId) {
    _pendingExposureRequest = (value: value, requestId: requestId);
    if (_isApplyingExposureRequest) return;
    unawaited(_drainExposureRequests());
  }

  Future<void> _drainExposureRequests() async {
    _isApplyingExposureRequest = true;
    try {
      while (mounted && _pendingExposureRequest != null) {
        final request = _pendingExposureRequest!;
        _pendingExposureRequest = null;
        final controller = _cameraService.controller;
        if (controller == null || !controller.value.isInitialized) return;

        try {
          final appliedValue = await controller.setExposureOffset(
            request.value,
          );
          _appliedExposureOffset = appliedValue;
          if (!mounted || request.requestId != _exposureRequestId) continue;
          setState(() => _exposureError = null);
        } catch (error) {
          if (!mounted || request.requestId != _exposureRequestId) continue;
          setState(() {
            _exposureOffset = _appliedExposureOffset;
            _exposureError = 'Không thể thay đổi phơi sáng: $error';
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_exposureError!)));
        }
      }
    } finally {
      _isApplyingExposureRequest = false;
      if (mounted && _pendingExposureRequest != null) {
        unawaited(_drainExposureRequests());
      }
    }
  }

  Widget _buildExposureControl() {
    if (_maxExposureOffset <= _minExposureOffset) {
      return Tooltip(
        message: _exposureError ?? 'Camera không hỗ trợ điều chỉnh phơi sáng.',
        child: const Icon(Icons.exposure, color: Colors.white70),
      );
    }

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 136,
              height: 40,
              child: Slider(
                key: const ValueKey('camera-exposure-slider'),
                min: _minExposureOffset,
                max: _maxExposureOffset,
                value: _exposureOffset
                    .clamp(_minExposureOffset, _maxExposureOffset)
                    .toDouble(),
                activeColor: Colors.yellowAccent,
                onChanged: _scheduleExposureOffset,
                onChangeEnd: _applyExposureOffset,
              ),
            ),
          ),
          Text(
            '${_exposureOffset.toStringAsFixed(1)} EV',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          IconButton(
            key: const ValueKey('camera-exposure-reset'),
            tooltip: 'Đặt phơi sáng về 0 EV',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: () => _scheduleExposureOffset(
              0.clamp(_minExposureOffset, _maxExposureOffset).toDouble(),
            ),
            icon: const Icon(
              Icons.restart_alt,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusIndicator(Size size) {
    final point = _focusPoint;
    if (point == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: (point.dx * size.width - 24)
          .clamp(0.0, size.width > 48 ? size.width - 48 : 0.0)
          .toDouble(),
      top: (point.dy * size.height - 24)
          .clamp(0.0, size.height > 48 ? size.height - 48 : 0.0)
          .toDouble(),
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _isFocusIndicatorVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.yellowAccent, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.center_focus_weak,
              color: Colors.yellowAccent,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControl() {
    if (_maxZoomLevel <= _minZoomLevel) return const SizedBox.shrink();
    if (!_isZoomControlVisible) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
          child: Tooltip(
            message: 'Điều chỉnh zoom chính xác',
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                key: const ValueKey('camera-zoom-toggle'),
                borderRadius: BorderRadius.circular(24),
                onTap: () => setState(() => _isZoomControlVisible = true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_zoomLevel.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.zoom_out, color: Colors.white70),
          Expanded(
            child: Slider(
              key: const ValueKey('camera-zoom-slider'),
              min: _minZoomLevel,
              max: _maxZoomLevel,
              value: _zoomLevel.clamp(_minZoomLevel, _maxZoomLevel),
              activeColor: Colors.yellowAccent,
              onChanged: _scheduleZoom,
              onChangeEnd: _applyZoom,
            ),
          ),
          Text(
            '${_zoomLevel.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            key: const ValueKey('camera-zoom-collapse'),
            tooltip: 'Thu gọn thanh zoom',
            onPressed: () => setState(() => _isZoomControlVisible = false),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _stopPoseAssist() async {
    final controller = _cameraService.controller;
    if (mounted) {
      setState(() {
        _isPoseAssistEnabled = false;
        _lastPoseFrameStartedAt = null;
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
    final targetPose = _selectedCatalogPose ?? _selectedUploadedPose;
    if (!_isPoseAssistEnabled || targetPose == null) return;
    final now = DateTime.now();
    final lastFrameStartedAt = _lastPoseFrameStartedAt;
    if (lastFrameStartedAt != null &&
        now.difference(lastFrameStartedAt) < _poseFrameInterval) {
      return;
    }
    _lastPoseFrameStartedAt = now;

    try {
      final frame = await _poseDetectionService.processImage(
        image,
        controller.description,
        controller.value.deviceOrientation,
      );
      if (!mounted || !_isPoseAssistEnabled || frame == null) return;
      final result = PoseMatchingService.evaluate(frame.pose, targetPose);
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
            Tooltip(
              message: 'Điểm so khớp hình học ước tính, không phải xác suất.',
              child: Text(
                '${result.score}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
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

        final hasGhostOverlay =
            _selectedPosePath != null || _selectedCatalogPose != null;
        return Center(
          child: AspectRatio(
            aspectRatio: frameAspectRatio,
            child: GestureDetector(
              key: _cameraPreviewKey,
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _focusAt(details.localPosition),
              onDoubleTap: _toggleExposureControl,
              onScaleStart: hasGhostOverlay ? null : _startCameraZoomGesture,
              onScaleUpdate: hasGhostOverlay ? null : _updateCameraZoomGesture,
              child: LayoutBuilder(
                builder: (context, previewConstraints) {
                  final maxExposureTop = (previewConstraints.maxHeight - 160)
                      .clamp(8.0, double.infinity)
                      .toDouble();
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      if (!_isCapturing) ...[
                        SmartGridWidget(
                          showGrid: _isGridVisible,
                          gridType: _gridType,
                          opacity: _gridOpacity,
                        ),
                        if (_selectedPosePath != null ||
                            _selectedCatalogPose != null)
                          ValueListenableBuilder<GhostTransform>(
                            valueListenable: _ghostTransform,
                            builder: (context, transform, child) =>
                                GhostOverlayWidget(
                                  key: ValueKey(
                                    '${_selectedCatalogPose?.id ?? _selectedPosePath}-$_ghostRevision',
                                  ),
                                  imagePath: _selectedPosePath,
                                  pose: _selectedCatalogPose,
                                  opacity: _ghostOpacity,
                                  isAsset: false,
                                  initialTransform: transform,
                                  onCameraTap: _focusAt,
                                  onExposureDoubleTap: _toggleExposureControl,
                                  onCameraScaleStart: _isCameraPinchZoomEnabled
                                      ? _startCameraZoomGesture
                                      : null,
                                  onCameraScaleUpdate: _isCameraPinchZoomEnabled
                                      ? _updateCameraZoomGesture
                                      : null,
                                  onTransformEnd: (transform) {
                                    _ghostTransform.value = transform;
                                  },
                                ),
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
                        if (_focusPoint != null &&
                            _isExposureControlVisible &&
                            !_areCameraSlidersSuspended)
                          Positioned(
                            top:
                                (_focusPoint!.dy *
                                            previewConstraints.maxHeight -
                                        80)
                                    .clamp(8.0, maxExposureTop)
                                    .toDouble(),
                            left: _focusPoint!.dx < 0.5 ? null : 8.0,
                            right: _focusPoint!.dx < 0.5 ? 8.0 : null,
                            child: _buildExposureControl(),
                          ),
                        _buildFocusIndicator(
                          Size(
                            previewConstraints.maxWidth,
                            previewConstraints.maxHeight,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
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
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header thanh công cụ trên (Tỷ lệ ảnh, bật tắt flash, v.v.)
                  if (!_isCapturing)
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        itemBuilder: (context) => GridType
                                            .values
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
                                          () =>
                                              _isGridVisible = !_isGridVisible,
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
                              if (_selectedPosePath != null ||
                                  _selectedCatalogPose != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _GhostActionButton(
                                        tooltip: _isCameraPinchZoomEnabled
                                            ? 'Pinch đang zoom camera · Chạm để chỉnh mẫu'
                                            : 'Pinch đang chỉnh mẫu · Chạm để zoom camera',
                                        icon: _isCameraPinchZoomEnabled
                                            ? Icons.pan_tool_alt
                                            : Icons.camera_alt_outlined,
                                        label: _isCameraPinchZoomEnabled
                                            ? 'Chỉnh mẫu'
                                            : 'Zoom camera',
                                        onPressed: () => setState(
                                          () => _isCameraPinchZoomEnabled =
                                              !_isCameraPinchZoomEnabled,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _GhostActionButton(
                                        tooltip:
                                            'Đặt lại vị trí và kích thước mẫu',
                                        icon: Icons.restart_alt,
                                        onPressed: _resetGhostTransform,
                                      ),
                                      const SizedBox(width: 8),
                                      _GhostActionButton(
                                        tooltip: 'Gỡ mẫu',
                                        icon: Icons.close,
                                        onPressed: _removeGhostImage,
                                      ),
                                    ],
                                  ),
                                ),
                              if (!_areCameraSlidersSuspended &&
                                  !_isCameraPinchZoomEnabled &&
                                  (_selectedPosePath != null ||
                                      _selectedCatalogPose != null))
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.image_outlined,
                                        color: Colors.white70,
                                      ),
                                      Expanded(
                                        child:
                                            ValueListenableBuilder<
                                              GhostTransform
                                            >(
                                              valueListenable: _ghostTransform,
                                              builder:
                                                  (context, transform, child) =>
                                                      Slider(
                                                        key: const ValueKey(
                                                          'ghost-scale-slider',
                                                        ),
                                                        min: 0.5,
                                                        max: 4,
                                                        value: transform.scale
                                                            .clamp(0.5, 4)
                                                            .toDouble(),
                                                        activeColor:
                                                            Colors.yellowAccent,
                                                        onChanged:
                                                            _setGhostScale,
                                                      ),
                                            ),
                                      ),
                                      SizedBox(
                                        width: 42,
                                        child:
                                            ValueListenableBuilder<
                                              GhostTransform
                                            >(
                                              valueListenable: _ghostTransform,
                                              builder:
                                                  (
                                                    context,
                                                    transform,
                                                    child,
                                                  ) => Text(
                                                    '${transform.scale.toStringAsFixed(1)}x',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.end,
                                                  ),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<
                                ({double roll, double pitch})?
                              >(
                                valueListenable: _levelReading,
                                builder: (context, reading, child) =>
                                    LevelIndicatorWidget(
                                      roll: reading?.roll ?? 0,
                                      pitch: reading?.pitch ?? 0,
                                      isAvailable:
                                          reading != null &&
                                          _sensorError == null,
                                      errorMessage:
                                          _sensorError ?? 'Đang đọc cảm biến',
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (!_isCapturing && _isPoseAssistEnabled)
                    _buildPoseAssistStatus(),

                  if (!_isCapturing && !_areCameraSlidersSuspended)
                    _buildZoomControl(),

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
          ),
        ],
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;

  const _GhostActionButton({
    required this.tooltip,
    required this.icon,
    this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: label == null ? const CircleBorder() : const StadiumBorder(),
      child: Tooltip(
        message: tooltip,
        child: label == null
            ? IconButton(
                tooltip: tooltip,
                onPressed: onPressed,
                icon: Icon(icon, color: Colors.white),
              )
            : TextButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, color: Colors.white, size: 18),
                label: Text(label!),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
      ),
    );
  }
}
