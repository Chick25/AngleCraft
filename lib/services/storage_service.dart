import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/pose_item.dart';
import '../models/saved_angle.dart';

class StorageService {
  static const String boxName = 'angle_vault';
  static const String customPosesBoxName = 'custom_poses';

  static Box<dynamic> get _box => Hive.box<dynamic>(boxName);
  static Box<dynamic> get _customPosesBox =>
      Hive.box<dynamic>(customPosesBoxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<dynamic>(boxName);
    }
    if (!Hive.isBoxOpen(customPosesBoxName)) {
      await Hive.openBox<dynamic>(customPosesBoxName);
    }
  }

  static List<PoseItem> getCustomPoses() {
    if (!Hive.isBoxOpen(customPosesBoxName)) {
      throw StateError('StorageService.init() must run before reading poses.');
    }
    return _customPosesBox.values
        .whereType<Map<dynamic, dynamic>>()
        .map(PoseItem.fromMap)
        .toList()
      ..sort((first, second) => first.title.compareTo(second.title));
  }

  static Future<void> saveCustomPose(PoseItem pose) async {
    if (!pose.isCustom) {
      throw ArgumentError.value(pose.id, 'pose', 'Dáng cần có khung xương.');
    }
    if (pose.customLandmarks!.length < 6 ||
        pose.customLandmarks!.values.any(
          (point) =>
              !point.dx.isFinite ||
              !point.dy.isFinite ||
              point.dx < 0 ||
              point.dx > 1 ||
              point.dy < 0 ||
              point.dy > 1,
        )) {
      throw ArgumentError.value(
        pose.id,
        'pose',
        'Tọa độ khung xương không hợp lệ.',
      );
    }
    await _customPosesBox.put(pose.id, pose.toMap());
  }

  static Future<void> deleteCustomPose(PoseItem pose) async {
    if (!pose.isCustom) {
      throw ArgumentError.value(pose.id, 'pose', 'Không phải dáng tùy chỉnh.');
    }
    await _customPosesBox.delete(pose.id);
  }

  static List<SavedAngle> getAllSavedAngles() {
    return _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map(SavedAngle.fromMap)
        .toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
  }

  static Future<SavedAngle> saveAngle(SavedAngle angle) async {
    final savedPhotoPath = await _copyToVault(
      angle.photoPath,
      '${angle.id}-photo',
    );
    String? savedGhostPath;
    try {
      final ghostPath = angle.ghostImagePath;
      if (ghostPath != null) {
        savedGhostPath = await _copyToVault(ghostPath, '${angle.id}-overlay');
      }

      final savedAngle = angle.copyWith(
        photoPath: savedPhotoPath,
        ghostImagePath: savedGhostPath,
      );
      await _box.put(savedAngle.id, savedAngle.toMap());
      return savedAngle;
    } catch (_) {
      await File(savedPhotoPath).delete();
      if (savedGhostPath != null) await File(savedGhostPath).delete();
      rethrow;
    }
  }

  static Future<void> toggleFavorite(SavedAngle angle) async {
    await _box.put(
      angle.id,
      angle.copyWith(isFavorite: !angle.isFavorite).toMap(),
    );
  }

  static Future<void> deleteAngle(SavedAngle angle) async {
    await _box.delete(angle.id);
    for (final imagePath in [angle.photoPath, angle.ghostImagePath]) {
      if (imagePath != null) {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) await imageFile.delete();
      }
    }
  }

  static Future<String> _copyToVault(
    String sourcePath,
    String filePrefix,
  ) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Không tìm thấy ảnh góc chụp', sourcePath);
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final vaultDirectory = Directory(
      path.join(documentsDirectory.path, 'angle_vault'),
    );
    await vaultDirectory.create(recursive: true);

    final extension = path.extension(sourcePath);
    final destinationPath = path.join(
      vaultDirectory.path,
      '$filePrefix${extension.isEmpty ? '.jpg' : extension}',
    );
    await source.copy(destinationPath);
    return destinationPath;
  }
}
