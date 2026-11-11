import 'dart:io';

import 'package:angle_craft/data/sample_poses.dart';
import 'package:angle_craft/models/pose_item.dart';
import 'package:angle_craft/screens/pose_catalog_screen.dart';
import 'package:angle_craft/services/storage_service.dart';
import 'package:angle_craft/widgets/pose_silhouette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'angle_craft_pose_catalog_test_',
    );
    Hive.init(storageDirectory.path);
    await Hive.openBox<dynamic>(StorageService.customPosesBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await storageDirectory.delete(recursive: true);
  });

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

  test('custom poses are stored separately from captured angles', () async {
    const pose = PoseItem(
      id: 'custom-test',
      title: 'Tựa lan can',
      description: 'Custom skeleton',
      category: PoseCategory.travel,
      style: PoseStyle.standing,
      customLandmarks: {
        'nose': Offset(0.5, 0.1),
        'leftShoulder': Offset(0.4, 0.2),
        'rightShoulder': Offset(0.6, 0.2),
        'leftElbow': Offset(0.3, 0.4),
        'leftWrist': Offset(0.3, 0.5),
        'leftHip': Offset(0.4, 0.5),
      },
    );

    await StorageService.saveCustomPose(pose);
    final storedPoses = StorageService.getCustomPoses();
    expect(storedPoses.single.id, pose.id);
    expect(storedPoses.single.customLandmarks, pose.customLandmarks);

    await StorageService.deleteCustomPose(pose);
    expect(StorageService.getCustomPoses(), isEmpty);
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
