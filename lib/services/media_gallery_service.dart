import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MediaGalleryService {
  static const _directoryName = 'captured_photos';
  static const _supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
  };

  static Future<Directory> _galleryDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      path.join(documentsDirectory.path, _directoryName),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static Future<File> saveCapture(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Không tìm thấy ảnh vừa chụp', sourcePath);
    }

    final directory = await _galleryDirectory();
    final extension = path.extension(sourcePath);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}'
        '${extension.isEmpty ? '.jpg' : extension}';
    return source.copy(path.join(directory.path, fileName));
  }

  static Future<List<File>> listCaptures() async {
    final directory = await _galleryDirectory();
    final photos = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          _supportedExtensions.contains(
            path.extension(entity.path).toLowerCase(),
          )) {
        photos.add(entity);
      }
    }
    final modifiedDates = await Future.wait(
      photos.map((photo) => photo.lastModified()),
    );
    final indexedPhotos = List.generate(photos.length, (index) => index)
      ..sort(
        (first, second) =>
            modifiedDates[second].compareTo(modifiedDates[first]),
      );
    return indexedPhotos.map((index) => photos[index]).toList();
  }

  static Future<void> deleteCapture(File photo) async {
    final directory = await _galleryDirectory();
    final root = path.canonicalize(directory.path);
    final target = path.canonicalize(photo.path);
    if (path.dirname(target) != root) {
      throw ArgumentError.value(
        photo.path,
        'photo',
        'Ảnh không thuộc bộ sưu tập.',
      );
    }
    if (await photo.exists()) await photo.delete();
  }
}
