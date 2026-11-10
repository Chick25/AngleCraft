import 'dart:io';

import 'package:flutter/material.dart';

import '../models/saved_angle.dart';
import '../services/storage_service.dart';

class AngleVaultScreen extends StatefulWidget {
  const AngleVaultScreen({super.key});

  @override
  State<AngleVaultScreen> createState() => _AngleVaultScreenState();
}

class _AngleVaultScreenState extends State<AngleVaultScreen> {
  late Future<List<SavedAngle>> _anglesFuture;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _anglesFuture = Future.sync(StorageService.getAllSavedAngles);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _anglesFuture = Future.sync(StorageService.getAllSavedAngles);
    });
  }

  Future<void> _toggleFavorite(SavedAngle angle) async {
    try {
      await StorageService.toggleFavorite(angle);
      _reload();
    } catch (error) {
      _showError('Không thể cập nhật yêu thích: $error');
    }
  }

  Future<void> _deleteAngle(SavedAngle angle) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa góc chụp?'),
        content: Text('“${angle.name}” sẽ bị xóa khỏi Angle Vault.'),
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
    if (shouldDelete != true) return;

    try {
      await StorageService.deleteAngle(angle);
      _reload();
    } catch (error) {
      _showError('Không thể xóa góc chụp: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPreview(SavedAngle angle) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF202020),
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _angleImage(
                angle.photoPath,
                height: MediaQuery.sizeOf(context).height * 0.62,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          angle.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(angle.createdAt),
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng ảnh',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: const Text('Angle Vault'),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Hiện tất cả' : 'Chỉ xem yêu thích',
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            icon: Icon(
              _favoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _favoritesOnly ? Colors.pinkAccent : Colors.white,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<SavedAngle>>(
        future: _anglesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              message: 'Không thể tải Angle Vault: ${snapshot.error}',
              actionLabel: 'Thử lại',
              onAction: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellowAccent),
            );
          }

          final angles = snapshot.data!
              .where((angle) => !_favoritesOnly || angle.isFavorite)
              .toList();
          if (angles.isEmpty) {
            return _MessageState(
              message: _favoritesOnly
                  ? 'Chưa có góc chụp yêu thích.'
                  : 'Chưa có góc chụp nào được lưu.\nChụp ảnh và chọn “Lưu góc” để thêm vào đây.',
              actionLabel: _favoritesOnly ? 'Xem tất cả' : null,
              onAction: _favoritesOnly
                  ? () => setState(() => _favoritesOnly = false)
                  : null,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: angles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final angle = angles[index];
              return _AngleCard(
                angle: angle,
                onPreview: () => _showPreview(angle),
                onFavorite: () => _toggleFavorite(angle),
                onDelete: () => _deleteAngle(angle),
                onLoad: () => Navigator.pop(context, angle),
              );
            },
          );
        },
      ),
    );
  }
}

class _AngleCard extends StatelessWidget {
  final SavedAngle angle;
  final VoidCallback onPreview;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onLoad;

  const _AngleCard({
    required this.angle,
    required this.onPreview,
    required this.onFavorite,
    required this.onDelete,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onPreview,
            child: Stack(
              children: [
                _angleImage(angle.photoPath, height: 190),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: angle.isFavorite
                          ? 'Bỏ yêu thích'
                          : 'Đánh dấu yêu thích',
                      onPressed: onFavorite,
                      icon: Icon(
                        angle.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: angle.isFavorite
                            ? Colors.pinkAccent
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'XEM ẢNH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  angle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(angle.createdAt),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onLoad,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Dùng cấu hình'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.yellowAccent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Xóa góc chụp',
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _angleImage(
  String imagePath, {
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(
    File(imagePath),
    height: height,
    width: double.infinity,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => Container(
      height: height,
      color: const Color(0xFF292929),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white54, size: 36),
          SizedBox(height: 8),
          Text('Ảnh không khả dụng', style: TextStyle(color: Colors.white54)),
        ],
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border,
              color: Colors.yellowAccent,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
