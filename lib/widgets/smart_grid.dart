import 'package:flutter/material.dart';

class SmartGridWidget extends StatelessWidget {
  final double opacity;
  final bool showGrid;

  const SmartGridWidget({Key? key, this.opacity = 0.6, this.showGrid = true}) : super(key: key);

  @override
  Widget build(BuildContext context){
    if(!showGrid) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size.infinite,
          painter: RuleOfThirdPainter(),
        )
      ),
    );
  }
}

class RuleOfThirdPainter extends CustomPainter{
  @override
  void paint(Canvas canvas, Size size){
    final paint = Paint()
    ..color = Colors.yellowAccent.withValues(alpha: 0.8)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

    double thirdWidth = size.width/3;
    canvas.drawLine(Offset(thirdWidth, 0), Offset(thirdWidth, size.height), paint);
    canvas.drawLine(Offset(thirdWidth * 2, 0), Offset(thirdWidth * 2, size.height), paint);

    double thirdHeight = size.height / 3;
    canvas.drawLine(Offset(0, thirdHeight), Offset(size.width, thirdHeight), paint);
    canvas.drawLine(Offset(0, thirdHeight * 2), Offset(size.width, thirdHeight * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}