import 'package:flutter/material.dart';

class GhostOverlayWidget extends StatefulWidget {
  final String imagePath; // Đường dẫn ảnh mẫu (Asset hoặc File)
  final double opacity;   // Độ mờ từ 0.0 đến 1.0
  final bool isAsset;

  const GhostOverlayWidget({
    Key? key,
    required this.imagePath,
    this.opacity = 0.4,
    this.isAsset = true,
  }) : super(key: key);

  @override
  State<GhostOverlayWidget> createState() => _GhostOverlayState();
}

class _GhostOverlayState extends State<GhostOverlayWidget> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
            _offset += details.focalPointDelta;
          });
        },
        child: Stack(
          children: [
            Transform(
              transform: Matrix4.identity()
                ..translate(_offset.dx, _offset.dy)
                ..scale(_scale),
              alignment: Alignment.center,
              child: Opacity(
                opacity: widget.opacity,
                child: Center(
                  child: widget.isAsset
                      ? Image.asset(widget.imagePath, fit: BoxFit.contain)
                      : Image.network(widget.imagePath, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}