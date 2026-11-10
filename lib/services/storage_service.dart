import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/saved_angle.dart';

class StorageService {
  static const String boxName = 'angle_vault';

  static Box<dynamic> get _box => Hive.box<dynamic>(boxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<dynamic>(boxName);
    }
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
