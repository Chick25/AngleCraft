import 'dart:io';

import 'package:flutter/material.dart';

import '../models/pose_item.dart';
import '../models/saved_angle.dart';
import 'pose_silhouette.dart';

class GhostOverlayWidget extends StatefulWidget {
  final String? imagePath;
  final double opacity;
  final bool isAsset;
  final PoseItem? pose;
  final GhostTransform initialTransform;
  final ValueChanged<Offset>? onCameraTap;
  final GestureScaleStartCallback? onCameraScaleStart;
  final GestureScaleUpdateCallback? onCameraScaleUpdate;
  final ValueChanged<GhostTransform>? onTransformEnd;

  const GhostOverlayWidget({
    super.key,
    this.imagePath,
    this.opacity = 0.4,
    this.isAsset = true,
    this.pose,
    this.initialTransform = const GhostTransform(),
    this.onCameraTap,
    this.onCameraScaleStart,
    this.onCameraScaleUpdate,
    this.onTransformEnd,
  });

  @override
  State<GhostOverlayWidget> createState() => _GhostOverlayWidgetState();
}

class _GhostOverlayWidgetState extends State<GhostOverlayWidget> {
  late double _scale = widget.initialTransform.scale;
  late double _rotation = widget.initialTransform.rotation;
  late Offset _offset = Offset(
    widget.initialTransform.offsetX,
    widget.initialTransform.offsetY,
  );
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
          onTapUp: widget.onCameraTap == null
              ? null
              : (details) => widget.onCameraTap!(details.localPosition),
          onScaleStart: (details) {
            _startingScale = _scale;
            _startingRotation = _rotation;
            widget.onCameraScaleStart?.call(details);
          },
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2) {
              final onCameraScaleUpdate = widget.onCameraScaleUpdate;
              if (onCameraScaleUpdate != null) {
                onCameraScaleUpdate(details);
                return;
              }
            }
            setState(() {
              _scale = (_startingScale * details.scale).clamp(0.5, 4.0);
              _rotation = _startingRotation + details.rotation;
              _offset += details.focalPointDelta;
            });
          },
          onScaleEnd: (_) {
            widget.onTransformEnd?.call(
              GhostTransform(
                offsetX: _offset.dx,
                offsetY: _offset.dy,
                scale: _scale,
                rotation: _rotation,
              ),
            );
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
