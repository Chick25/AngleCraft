import 'package:angle_craft/widgets/ghost_overlay.dart';
import 'package:angle_craft/models/pose_item.dart';
import 'package:angle_craft/models/saved_angle.dart';
import 'package:angle_craft/widgets/pose_silhouette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pinchOverlay(WidgetTester tester, Finder overlay) async {
  final rect = tester.getRect(overlay);
  final first = await tester.startGesture(
    rect.center - const Offset(20, 0),
    pointer: 1,
  );
  final second = await tester.startGesture(
    rect.center + const Offset(20, 0),
    pointer: 2,
  );
  await first.moveTo(rect.center - const Offset(50, 0));
  await second.moveTo(rect.center + const Offset(50, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pump();
}

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

  testWidgets('restores and reports the ghost transform', (tester) async {
    GhostTransform? finalTransform;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 400,
            child: GhostOverlayWidget(
              imagePath: 'missing_sample_image.jpg',
              isAsset: false,
              initialTransform: const GhostTransform(offsetX: 10, offsetY: 5),
              onTransformEnd: (transform) => finalTransform = transform,
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

    expect(finalTransform, isNotNull);
    expect(finalTransform!.offsetX, closeTo(40, 0.1));
    expect(finalTransform!.offsetY, closeTo(25, 0.1));
  });

  testWidgets('forwards preview taps and pinch updates', (tester) async {
    Offset? cameraTap;
    final cameraPointerCounts = <int>[];
    GhostTransform? finalTransform;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 400,
            child: GhostOverlayWidget(
              imagePath: 'missing_sample_image.jpg',
              isAsset: false,
              onCameraTap: (position) => cameraTap = position,
              onCameraScaleUpdate: (details) =>
                  cameraPointerCounts.add(details.pointerCount),
              onTransformEnd: (transform) => finalTransform = transform,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final overlay = find.byKey(const ValueKey('ghostOverlayGesture'));
    await tester.tapAt(tester.getTopLeft(overlay) + const Offset(30, 45));
    expect(cameraTap, const Offset(30, 45));

    await _pinchOverlay(tester, overlay);

    expect(cameraPointerCounts, contains(2));
    expect(finalTransform, isNotNull);
    expect(finalTransform!.scale, closeTo(1, 0.1));
  });

  testWidgets('keeps ghost scaling when camera pinch zoom is disabled', (
    tester,
  ) async {
    GhostTransform? finalTransform;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 400,
            child: GhostOverlayWidget(
              imagePath: 'missing_sample_image.jpg',
              isAsset: false,
              onTransformEnd: (transform) => finalTransform = transform,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await _pinchOverlay(
      tester,
      find.byKey(const ValueKey('ghostOverlayGesture')),
    );

    expect(finalTransform, isNotNull);
    expect(finalTransform!.scale, greaterThan(1));
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
