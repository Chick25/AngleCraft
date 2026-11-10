import 'dart:io';

import 'package:flutter/material.dart';

import '../models/pose_item.dart';
import 'pose_silhouette.dart';

class GhostOverlayWidget extends StatefulWidget {
  final String? imagePath;
  final double opacity;
  final bool isAsset;
  final PoseItem? pose;

  const GhostOverlayWidget({
    super.key,
    this.imagePath,
    this.opacity = 0.4,
    this.isAsset = true,
    this.pose,
  });

  @override
  State<GhostOverlayWidget> createState() => _GhostOverlayWidgetState();
}

class _GhostOverlayWidgetState extends State<GhostOverlayWidget> {
  double _scale = 1;
  double _rotation = 0;
  Offset _offset = Offset.zero;
  double _startingScale = 1;
  double _startingRotation = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final image = widget.pose != null
            ? CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: PoseSilhouettePainter(
                  pose: widget.pose!,
                  color: Colors.yellowAccent,
                ),
              )
            : widget.imagePath == null
            ? const SizedBox.expand()
            : widget.isAsset
            ? Image.asset(
                widget.imagePath!,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const _GhostImageError(),
              )
            : Image.file(
                File(widget.imagePath!),
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const _GhostImageError(),
              );

        return GestureDetector(
          key: const ValueKey('ghostOverlayGesture'),
          behavior: HitTestBehavior.translucent,
          onScaleStart: (_) {
            _startingScale = _scale;
            _startingRotation = _rotation;
          },
          onScaleUpdate: (details) {
            setState(() {
              _scale = (_startingScale * details.scale).clamp(0.5, 4.0);
              _rotation = _startingRotation + details.rotation;
              _offset += details.focalPointDelta;
            });
          },
          child: RepaintBoundary(
            child: Transform.translate(
              offset: _offset,
              child: Transform.rotate(
                angle: _rotation,
                child: Transform.scale(
                  scale: _scale,
                  child: Opacity(
                    opacity: widget.opacity.clamp(0.0, 1.0),
                    child: image,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GhostImageError extends StatelessWidget {
  const _GhostImageError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Không thể tải ảnh mẫu',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
