import 'package:angle_craft/screens/custom_pose_editor_screen.dart';
import 'package:angle_craft/widgets/pose_silhouette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scene suggestions can be customized by dragging joints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CustomPoseEditorScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Đặt một tay lên lan can'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dựa tường'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thả lỏng vai'), findsOneWidget);

    final canvas = find.byKey(const ValueKey('custom-pose-canvas'));
    final rect = tester.getRect(canvas);
    final initialNose =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is PoseSilhouettePainter,
                  ),
                )
                .painter!
            as PoseSilhouettePainter;
    final initialX = initialNose.pose.customLandmarks!['nose']!.dx;

    await tester.dragFrom(
      Offset(rect.left + rect.width * 0.53, rect.top + rect.height * 0.1),
      const Offset(24, 20),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final movedNose =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is PoseSilhouettePainter,
                  ),
                )
                .painter!
            as PoseSilhouettePainter;
    expect(movedNose.pose.customLandmarks!['nose']!.dx, greaterThan(initialX));
  });
}
