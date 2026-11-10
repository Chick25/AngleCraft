import 'package:angle_craft/widgets/ghost_overlay.dart';
import 'package:angle_craft/models/pose_item.dart';
import 'package:angle_craft/widgets/pose_silhouette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fits the sample image without changing its aspect ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 400,
              child: GhostOverlayWidget(
                imagePath: 'missing_sample_image.jpg',
                isAsset: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.width, 240);
    expect(image.height, 400);
  });

  testWidgets('supports dragging the ghost image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 400,
              child: GhostOverlayWidget(
                imagePath: 'missing_sample_image.jpg',
                isAsset: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('ghostOverlayGesture')),
      const Offset(30, 20),
    );
    await tester.pump();

    final transforms = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byKey(const ValueKey('ghostOverlayGesture')),
            matching: find.byType(Transform),
          ),
        )
        .toList();
    expect(transforms.first.transform.storage[12], closeTo(30, 0.1));
    expect(transforms.first.transform.storage[13], closeTo(20, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a selected offline pose as an interactive overlay', (
    tester,
  ) async {
    const pose = PoseItem(
      id: 'test-pose',
      title: 'Test pose',
      description: 'Offline silhouette',
      category: PoseCategory.individualFemale,
      style: PoseStyle.handOnHip,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 400,
            child: GhostOverlayWidget(pose: pose, opacity: 0.5),
          ),
        ),
      ),
    );

    final customPaint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is PoseSilhouettePainter,
      ),
    );
    expect((customPaint.painter! as PoseSilhouettePainter).pose.id, pose.id);
    expect(find.byKey(const ValueKey('ghostOverlayGesture')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
