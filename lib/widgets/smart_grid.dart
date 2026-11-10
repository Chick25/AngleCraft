import 'package:flutter/material.dart';
import 'smart_grid_painter.dart';

class SmartGridWidget extends StatelessWidget {
  final double opacity;
  final bool showGrid;
  final GridType gridType;

  const SmartGridWidget({
    super.key,
    this.opacity = 0.6,
    this.showGrid = true,
    this.gridType = GridType.thirds,
  });

  @override
  Widget build(BuildContext context) {
    if (!showGrid) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: SmartGridPainter(gridType: gridType, opacity: opacity),
        ),
      ),
    );
  }
}