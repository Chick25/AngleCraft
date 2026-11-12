import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/media_gallery_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<File>> _photosFuture;

  @override
  void initState() {
    super.initState();
    _photosFuture = MediaGalleryService.listCaptures();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _photosFuture = MediaGalleryService.listCaptures();
    });
  }

  Future<void> _openViewer(List<File> photos, int initialIndex) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
      ),
    );
    if (deleted == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: const Text('Ảnh đã chụp'),
      ),
      body: FutureBuilder<List<File>>(
        future: _photosFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _GalleryMessage(
              icon: Icons.error_outline,
              message: 'Không thể tải bộ sưu tập: ${snapshot.error}',
              actionLabel: 'Thử lại',
              onAction: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellowAccent),
            );
          }

          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return const _GalleryMessage(
              icon: Icons.photo_library_outlined,
              message: 'Ảnh bạn chụp sẽ xuất hiện tại đây.',
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(3),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) => _PhotoThumbnail(
              photo: photos[index],
              onTap: () => _openViewer(photos, index),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final File photo;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF242424),
      child: InkWell(
        onTap: onTap,
        child: Image.file(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

class PhotoViewerScreen extends StatefulWidget {
  final List<File> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late final List<TransformationController> _photoTransforms;
  late int _currentIndex;
  _PhotoFilter _filter = _PhotoFilter.neutral;
  bool _isDeleting = false;
  bool _isPhotoZoomed = false;

  File get _currentPhoto => widget.photos[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _photoTransforms = List.generate(widget.photos.length, (index) {
      final controller = TransformationController();
      controller.addListener(() => _onPhotoTransformChanged(index));
      return controller;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _photoTransforms) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPhotoTransformChanged(int index) {
    if (!mounted || index != _currentIndex) return;
    final isZoomed = _photoTransforms[index].value.getMaxScaleOnAxis() > 1.01;
    if (isZoomed != _isPhotoZoomed) {
      setState(() => _isPhotoZoomed = isZoomed);
    }
  }

  void _resetPhotoZoom() {
    _photoTransforms[_currentIndex].value = Matrix4.identity();
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202020),
      builder: (context) {
        var draft = _filter;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateFilter(_PhotoFilter filter) {
              setSheetState(() => draft = filter);
              setState(() => _filter = filter);
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tone màu và ánh sáng',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => updateFilter(_PhotoFilter.neutral),
                          child: const Text('Đặt lại'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _PhotoFilter.presets
                          .map(
                            (preset) => ChoiceChip(
                              label: Text(preset.name),
                              selected: draft.name == preset.name,
                              onSelected: (_) => updateFilter(preset),
                            ),
                          )
                          .toList(),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Chỉ áp dụng cho bản xem trước. Ảnh gốc và ảnh chia sẻ '
                        'vẫn được giữ nguyên.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterSlider(
                      label: 'Độ sáng',
                      value: draft.brightness,
                      min: -0.3,
                      max: 0.3,
                      onChanged: (value) =>
                          updateFilter(draft.copyWith(brightness: value)),
                    ),
                    _buildFilterSlider(
                      label: 'Tương phản',
                      value: draft.contrast,
                      min: 0.5,
                      max: 1.5,
                      onChanged: (value) =>
                          updateFilter(draft.copyWith(contrast: value)),
                    ),
                    _buildFilterSlider(
                      label: 'Bão hòa',
                      value: draft.saturation,
                      min: 0,
                      max: 2,
                      onChanged: (value) =>
                          updateFilter(draft.copyWith(saturation: value)),
                    ),
                    _buildFilterSlider(
                      label: 'Ấm / lạnh',
                      value: draft.warmth,
                      min: -1,
                      max: 1,
                      onChanged: (value) =>
                          updateFilter(draft.copyWith(warmth: value)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hoàn tất'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70)),
            ),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Future<void> _sharePhoto() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_currentPhoto.path)],
          subject: 'Ảnh từ AngleCraft',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể chia sẻ ảnh: $error')));
    }
  }

  Future<void> _deletePhoto() async {
    final photo = _currentPhoto;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ảnh?'),
        content: const Text(
          'Ảnh sẽ bị xóa khỏi AngleCraft. Bản đã xuất sang thư viện thiết bị '
          'không bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await MediaGalleryService.deleteCapture(photo);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa ảnh: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
        actions: [
          if (_isPhotoZoomed)
            IconButton(
              key: const ValueKey('photo-zoom-reset'),
              tooltip: 'Đặt lại mức zoom ảnh',
              onPressed: _resetPhotoZoom,
              icon: const Icon(Icons.zoom_out_map),
            ),
          IconButton(
            tooltip: 'Chỉnh tone màu và ánh sáng',
            onPressed: _isDeleting ? null : _showFilters,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Chia sẻ ảnh',
            onPressed: _isDeleting ? null : _sharePhoto,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Xóa ảnh',
            onPressed: _isDeleting ? null : _deletePhoto,
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: _isPhotoZoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.photos.length,
        onPageChanged: (index) {
          final previousIndex = _currentIndex;
          _currentIndex = index;
          _filter = _PhotoFilter.neutral;
          _photoTransforms[previousIndex].value = Matrix4.identity();
          _photoTransforms[index].value = Matrix4.identity();
          if (mounted) setState(() => _isPhotoZoomed = false);
        },
        itemBuilder: (context, index) => Center(
          child: ColorFiltered(
            colorFilter: _filter.colorFilter,
            child: InteractiveViewer(
              key: ValueKey('photo-viewer-$index'),
              transformationController: _photoTransforms[index],
              minScale: 1,
              maxScale: 5,
              boundaryMargin: const EdgeInsets.all(80),
              child: Image.file(
                widget.photos[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoFilter {
  final String name;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  const _PhotoFilter({
    required this.name,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
  });

  static const neutral = _PhotoFilter(name: 'Gốc');
  static const presets = [
    neutral,
    _PhotoFilter(name: 'Ấm', brightness: 0.04, contrast: 1.05, warmth: 0.55),
    _PhotoFilter(name: 'Lạnh', contrast: 1.04, warmth: -0.55),
    _PhotoFilter(
      name: 'Sống động',
      contrast: 1.08,
      saturation: 1.35,
      warmth: 0.08,
    ),
    _PhotoFilter(name: 'Đen trắng', contrast: 1.05, saturation: 0),
  ];

  _PhotoFilter copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) {
    return _PhotoFilter(
      name: 'Tùy chỉnh',
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
    );
  }

  ColorFilter get colorFilter {
    const redLuminance = 0.2126;
    const greenLuminance = 0.7152;
    const blueLuminance = 0.0722;
    final desaturation = 1 - saturation;
    final contrastOffset = 128 * (1 - contrast) + brightness * 255;
    final redOffset = contrastOffset + warmth * 24;
    final blueOffset = contrastOffset - warmth * 24;

    return ColorFilter.matrix([
      contrast * (desaturation * redLuminance + saturation),
      contrast * desaturation * greenLuminance,
      contrast * desaturation * blueLuminance,
      0,
      redOffset,
      contrast * desaturation * redLuminance,
      contrast * (desaturation * greenLuminance + saturation),
      contrast * desaturation * blueLuminance,
      0,
      contrastOffset,
      contrast * desaturation * redLuminance,
      contrast * desaturation * greenLuminance,
      contrast * (desaturation * blueLuminance + saturation),
      0,
      blueOffset,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

class _GalleryMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _GalleryMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.yellowAccent, size: 54),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
