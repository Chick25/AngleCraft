import 'package:flutter/material.dart';

import 'smart_grid_painter.dart';

class GridAlignmentGuide extends StatelessWidget {
  final GridType gridType;
  final String? liveAdvice;

  const GridAlignmentGuide({
    super.key,
    required this.gridType,
    this.liveAdvice,
  });

  String get _gridLabel {
    switch (gridType) {
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

  String get _hint {
    switch (gridType) {
      case GridType.thirds:
        return 'Đặt chủ thể gần giao điểm; có thể căn đường chân trời theo đường ngang.';
      case GridType.goldenRatio:
        return 'Đặt chủ thể hoặc điểm hút mắt gần vùng giao nhau của các đường lưới.';
      case GridType.goldenTriangle:
        return 'Căn chủ thể hoặc đường nét chính theo đường chéo và các cạnh tam giác.';
      case GridType.diagonal:
        return 'Đưa đường nét nổi bật theo một đường chéo để tạo cảm giác chuyển động.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.tips_and_updates_outlined,
              color: Colors.yellowAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${liveAdvice == null ? 'Gợi ý' : 'Gợi ý AI'} · $_gridLabel',
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    liveAdvice ?? _hint,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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
