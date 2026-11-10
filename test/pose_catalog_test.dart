import 'package:angle_craft/data/sample_poses.dart';
import 'package:angle_craft/models/pose_item.dart';
import 'package:angle_craft/screens/pose_catalog_screen.dart';
import 'package:angle_craft/widgets/pose_silhouette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline pose catalog covers every requested category', () {
    expect(
      samplePoses.map((pose) => pose.category).toSet(),
      containsAll(PoseCategory.values),
    );
    expect(samplePoses, isNotEmpty);
    expect(
      samplePoses.map((pose) => pose.id).toSet().length,
      samplePoses.length,
    );
  });

  testWidgets('catalog filters by category and returns the selected pose', (
    tester,
  ) async {
    PoseItem? selectedPose;
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedPose = await Navigator.of(context).push<PoseItem>(
                  MaterialPageRoute(builder: (_) => const PoseCatalogScreen()),
                );
              },
              child: const Text('Open catalog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Tự tin'), findsOneWidget);
    expect(find.text('Kề vai'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cá nhân · Nam'));
    await tester.pumpAndSettle();
    expect(find.text('Tự tin'), findsOneWidget);
    expect(find.text('Kề vai'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pose-card-male-confident')));
    await tester.pumpAndSettle();
    expect(selectedPose?.id, 'male-confident');
  });

  testWidgets(
    'every offline silhouette style paints without distortion errors',
    (tester) async {
      for (final pose in samplePoses) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 140,
                height: 190,
                child: CustomPaint(painter: PoseSilhouettePainter(pose: pose)),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
