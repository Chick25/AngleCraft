import 'package:flutter/material.dart';

class LevelIndicatorWidget extends StatelessWidget{
  final double roll;
  final double pitch;

  const LevelIndicatorWidget({Key? key, required this.roll, required this.pitch}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isBalanced = (roll.abs() <= 2.0 && pitch.abs() <= 2.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isBalanced ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: isBalanced ? Colors.greenAccent : Colors.redAccent, width: 2.0),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isBalanced ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 8.0),
          Text(
            isBalanced ? "Đã cân bằng · 0°" : "Máy đang lệch · Cần cân lại",
            style: TextStyle(
              color: isBalanced ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      )

    );

  }


}