import 'dart:io';

import 'package:angle_craft/screens/gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('viewer opens tone and lighting controls and applies a preset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoViewerScreen(
          photos: [File('missing-photo.jpg')],
          initialIndex: 0,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Chỉnh tone màu và ánh sáng'));
    await tester.pumpAndSettle();

    expect(find.text('Độ sáng'), findsOneWidget);
    expect(find.text('Tương phản'), findsOneWidget);
    expect(find.text('Bão hòa'), findsOneWidget);
    expect(find.text('Ấm / lạnh'), findsOneWidget);

    await tester.tap(find.text('Đen trắng'));
    await tester.pump();
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();

    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
