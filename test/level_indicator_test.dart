import 'package:angle_craft/widgets/level_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows green status within the balance threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LevelIndicatorWidget(roll: 1, pitch: -2)),
      ),
    );

    expect(find.text('Đã cân bằng'), findsOneWidget);
    expect(find.text('Ngang  +1.0°'), findsOneWidget);
    expect(find.text('Dọc     -2.0°'), findsOneWidget);
  });

  testWidgets('shows a red warning for severe tilt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LevelIndicatorWidget(roll: 10, pitch: 0)),
      ),
    );

    expect(find.text('Lệch góc nghiêm trọng'), findsOneWidget);
  });

  testWidgets('does not report balanced before sensor data is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LevelIndicatorWidget(
            isAvailable: false,
            errorMessage: 'Đang đọc cảm biến',
          ),
        ),
      ),
    );

    expect(find.text('Đang đọc cảm biến'), findsOneWidget);
    expect(find.text('Đã cân bằng'), findsNothing);
  });
}
