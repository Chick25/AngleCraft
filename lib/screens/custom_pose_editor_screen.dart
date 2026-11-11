import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pose_item.dart';
import '../services/storage_service.dart';
import '../widgets/pose_silhouette.dart';

class CustomPoseEditorScreen extends StatefulWidget {
  const CustomPoseEditorScreen({super.key});

  @override
  State<CustomPoseEditorScreen> createState() => _CustomPoseEditorScreenState();
}

class _CustomPoseEditorScreenState extends State<CustomPoseEditorScreen> {
  static const _scenes = ['Tựa lan can', 'Dựa tường', 'Ngồi', 'Tự do'];
  static const _sceneHints = {
    'Tựa lan can':
        'Đặt một tay lên lan can, nghiêng người nhẹ và giữ dáng '
        'thoải mái. Bối cảnh do bạn chọn; app chưa tự nhận diện lan can.',
    'Dựa tường':
        'Thả lỏng vai, nghiêng nhẹ người và đặt một chân làm điểm tựa.',
    'Ngồi': 'Giữ lưng thoải mái, tạo góc tự nhiên ở hông và đầu gối.',
    'Tự do': 'Kéo các khớp để tạo dáng bất kỳ theo ý bạn.',
  };
  static const _suggestions = {
    'Tựa lan can': <String, Offset>{
      'nose': Offset(0.50, 0.10),
      'leftShoulder': Offset(0.40, 0.23),
      'rightShoulder': Offset(0.60, 0.25),
      'leftElbow': Offset(0.34, 0.37),
      'leftWrist': Offset(0.35, 0.49),
      'rightElbow': Offset(0.73, 0.29),
      'rightWrist': Offset(0.88, 0.29),
      'leftHip': Offset(0.44, 0.52),
      'rightHip': Offset(0.58, 0.54),
      'leftKnee': Offset(0.42, 0.73),
      'rightKnee': Offset(0.63, 0.73),
      'leftAnkle': Offset(0.40, 0.94),
      'rightAnkle': Offset(0.66, 0.94),
    },
    'Dựa tường': <String, Offset>{
      'nose': Offset(0.53, 0.10),
      'leftShoulder': Offset(0.42, 0.23),
      'rightShoulder': Offset(0.61, 0.25),
      'leftElbow': Offset(0.34, 0.37),
      'leftWrist': Offset(0.36, 0.49),
      'rightElbow': Offset(0.69, 0.36),
      'rightWrist': Offset(0.76, 0.46),
      'leftHip': Offset(0.44, 0.52),
      'rightHip': Offset(0.59, 0.54),
      'leftKnee': Offset(0.40, 0.72),
      'rightKnee': Offset(0.65, 0.75),
      'leftAnkle': Offset(0.36, 0.93),
      'rightAnkle': Offset(0.68, 0.91),
    },
    'Ngồi': <String, Offset>{
      'nose': Offset(0.50, 0.10),
      'leftShoulder': Offset(0.40, 0.23),
      'rightShoulder': Offset(0.60, 0.23),
      'leftElbow': Offset(0.32, 0.36),
      'leftWrist': Offset(0.39, 0.48),
      'rightElbow': Offset(0.68, 0.36),
      'rightWrist': Offset(0.61, 0.48),
      'leftHip': Offset(0.44, 0.51),
      'rightHip': Offset(0.57, 0.51),
      'leftKnee': Offset(0.32, 0.68),
      'rightKnee': Offset(0.72, 0.68),
      'leftAnkle': Offset(0.23, 0.84),
      'rightAnkle': Offset(0.81, 0.84),
    },
    'Tự do': <String, Offset>{
      'nose': Offset(0.50, 0.10),
      'leftShoulder': Offset(0.40, 0.23),
      'rightShoulder': Offset(0.60, 0.23),
      'leftElbow': Offset(0.34, 0.38),
      'leftWrist': Offset(0.34, 0.50),
      'rightElbow': Offset(0.66, 0.38),
      'rightWrist': Offset(0.66, 0.50),
      'leftHip': Offset(0.44, 0.52),
      'rightHip': Offset(0.56, 0.52),
      'leftKnee': Offset(0.42, 0.73),
      'rightKnee': Offset(0.58, 0.73),
      'leftAnkle': Offset(0.40, 0.94),
      'rightAnkle': Offset(0.60, 0.94),
    },
  };

  final TextEditingController _nameController = TextEditingController();
  String _selectedScene = _scenes.first;
  late Map<String, Offset> _landmarks = Map.of(_suggestions[_selectedScene]!);
  String? _activeJoint;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  PoseItem get _previewPose => PoseItem(
    id: 'custom-preview',
    title: 'Dáng xem trước',
    description: _sceneHints[_selectedScene]!,
    category: PoseCategory.travel,
    style: PoseStyle.standing,
    customLandmarks: _landmarks,
  );

  void _selectScene(String scene) {
    setState(() {
      _selectedScene = scene;
      _landmarks = Map.of(_suggestions[scene]!);
    });
  }

  Rect _drawingRect(Size size) {
    final scale = math.min(size.width / 100, size.height / 150);
    final drawnSize = Size(100 * scale, 150 * scale);
    return Rect.fromLTWH(
      (size.width - drawnSize.width) / 2,
      (size.height - drawnSize.height) / 2,
      drawnSize.width,
      drawnSize.height,
    );
  }

  String? _jointAt(Offset position, Size size) {
    final rect = _drawingRect(size);
    String? closest;
    var closestDistance = 24.0;
    for (final entry in _landmarks.entries) {
      final joint = Offset(
        rect.left + entry.value.dx * rect.width,
        rect.top + entry.value.dy * rect.height,
      );
      final distance = (joint - position).distance;
      if (distance < closestDistance) {
        closest = entry.key;
        closestDistance = distance;
      }
    }
    return closest;
  }

  void _moveActiveJoint(Offset position, Size size) {
    final joint = _activeJoint;
    if (joint == null) return;
    final rect = _drawingRect(size);
    final point = Offset(
      ((position.dx - rect.left) / rect.width).clamp(0.04, 0.96),
      ((position.dy - rect.top) / rect.height).clamp(0.03, 0.98),
    );
    setState(() => _landmarks = {..._landmarks, joint: point});
  }

  Future<void> _savePose() async {
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy đặt tên cho dáng chụp.')),
      );
      return;
    }

    final pose = PoseItem(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: _sceneHints[_selectedScene]!,
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: Map.of(_landmarks),
    );

    setState(() => _isSaving = true);
    try {
      await StorageService.saveCustomPose(pose);
      if (mounted) Navigator.pop(context, pose);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu dáng tùy chỉnh: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: const Text('Tạo dáng tùy chỉnh'),
      ),
      body: SafeArea(
        child: ListView(
          physics: _activeJoint == null
              ? null
              : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Chọn gợi ý rồi kéo các khớp để tạo dáng. Mẫu được hiển thị dạng '
              'vector và chỉ lưu tọa độ, không lưu ảnh.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final scene in _scenes)
                  ChoiceChip(
                    label: Text(scene),
                    selected: _selectedScene == scene,
                    onSelected: (_) => _selectScene(scene),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _sceneHints[_selectedScene]!,
              style: const TextStyle(color: Colors.yellowAccent),
            ),
            const SizedBox(height: 12),
            Center(
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Listener(
                      key: const ValueKey('custom-pose-canvas'),
                      onPointerDown: (event) {
                        final joint = _jointAt(event.localPosition, size);
                        if (joint != null) {
                          setState(() => _activeJoint = joint);
                        }
                      },
                      onPointerMove: (event) =>
                          _moveActiveJoint(event.localPosition, size),
                      onPointerUp: (_) => setState(() => _activeJoint = null),
                      onPointerCancel: (_) =>
                          setState(() => _activeJoint = null),
                      child: CustomPaint(
                        painter: PoseSilhouettePainter(
                          pose: _previewPose,
                          highlightedJoint: _activeJoint,
                        ),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),
              ),
            ),
            const Center(
              child: Text(
                'Kéo từng điểm để chỉnh khớp',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 40,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tên dáng',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isSaving ? null : _savePose,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu và dùng dáng này'),
            ),
          ],
        ),
      ),
    );
  }
}
