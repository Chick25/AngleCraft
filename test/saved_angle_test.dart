import 'package:angle_craft/models/saved_angle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved angle configuration survives local-map serialization', () {
    final createdAt = DateTime(2026, 11, 10, 14, 30);
    final angle = SavedAngle(
      id: 'angle-1',
      name: 'Hoàng hôn',
      createdAt: createdAt,
      photoPath: '/private/angle.jpg',
      ghostImagePath: '/private/pose.png',
      poseId: 'female-elegant',
      gridType: 'goldenRatio',
      isGridVisible: false,
      gridOpacity: 0.6,
      ghostOpacity: 0.35,
      ghostTransform: const GhostTransform(
        offsetX: 24,
        offsetY: -12,
        scale: 1.4,
        rotation: 0.2,
      ),
      isFavorite: true,
    );

    final restored = SavedAngle.fromMap(angle.toMap());

    expect(restored.id, angle.id);
    expect(restored.name, angle.name);
    expect(restored.createdAt, createdAt);
    expect(restored.photoPath, angle.photoPath);
    expect(restored.ghostImagePath, angle.ghostImagePath);
    expect(restored.poseId, angle.poseId);
    expect(restored.gridType, angle.gridType);
    expect(restored.isGridVisible, isFalse);
    expect(restored.gridOpacity, angle.gridOpacity);
    expect(restored.ghostOpacity, angle.ghostOpacity);
    expect(restored.ghostTransform.offsetX, 24);
    expect(restored.ghostTransform.offsetY, -12);
    expect(restored.ghostTransform.scale, 1.4);
    expect(restored.ghostTransform.rotation, 0.2);
    expect(restored.isFavorite, isTrue);
  });

  test('old or partial values get safe visual defaults', () {
    final restored = SavedAngle.fromMap({
      'id': 'legacy-angle',
      'photoPath': '/private/legacy.jpg',
    });

    expect(restored.gridType, 'thirds');
    expect(restored.isGridVisible, isTrue);
    expect(restored.ghostTransform.scale, 1);
    expect(restored.isFavorite, isFalse);
  });
}
