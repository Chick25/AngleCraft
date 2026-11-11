import 'package:flutter/material.dart';

import '../data/sample_poses.dart';
import '../models/pose_item.dart';
import '../services/storage_service.dart';
import '../widgets/pose_silhouette.dart';
import 'custom_pose_editor_screen.dart';

class PoseCatalogScreen extends StatefulWidget {
  const PoseCatalogScreen({super.key});

  @override
  State<PoseCatalogScreen> createState() => _PoseCatalogScreenState();
}

class _PoseCatalogScreenState extends State<PoseCatalogScreen> {
  PoseCategory? _selectedCategory;

  Future<void> _createCustomPose() async {
    final pose = await Navigator.of(context).push<PoseItem>(
      MaterialPageRoute(builder: (_) => const CustomPoseEditorScreen()),
    );
    if (!mounted || pose == null) return;
    Navigator.pop(context, pose);
  }

  Future<void> _deleteCustomPose(PoseItem pose) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dáng tùy chỉnh?'),
        content: Text('“${pose.title}” sẽ bị xóa khỏi thiết bị.'),
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
    try {
      await StorageService.deleteCustomPose(pose);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa dáng tùy chỉnh: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final poses = [...samplePoses, ...StorageService.getCustomPoses()]
        .where(
          (pose) =>
              _selectedCategory == null || pose.category == _selectedCategory,
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: const Text('Thư viện dáng chụp'),
        actions: [
          IconButton(
            tooltip: 'Tạo dáng tùy chỉnh',
            onPressed: _createCustomPose,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Đóng thư viện',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Chọn dáng để phủ phác thảo lên khung camera',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _categoryChip(null, 'Tất cả'),
                for (final category in PoseCategory.values)
                  _categoryChip(category, category.label),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: poses.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 250,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final pose = poses[index];
                return _PoseCard(
                  pose: pose,
                  onTap: () => Navigator.pop(context, pose),
                  onDelete: pose.isCustom
                      ? () => _deleteCustomPose(pose)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(PoseCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: Colors.yellowAccent,
        backgroundColor: const Color(0xFF252525),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
      ),
    );
  }
}

class _PoseCard extends StatelessWidget {
  final PoseItem pose;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PoseCard({required this.pose, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF202020),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pose-card-${pose.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CustomPaint(
                        painter: PoseSilhouettePainter(
                          pose: pose,
                          color: Colors.yellowAccent,
                        ),
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip: 'Xóa dáng ${pose.title}',
                        onPressed: onDelete,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pose.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pose.category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pose.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
