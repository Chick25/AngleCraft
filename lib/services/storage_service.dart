import 'package:hive_flutter/hive_flutter.dart';

class StorageService{
  static const String boxName = 'angle_data';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  static Future<void> saveAngleConfig(String key, Map<String, dynamic> data) async {
    var box = Hive.box(boxName);
    await box.put(key, data);
  }

  static List<dynamic> getAllSavedAngles(){
    var box = Hive.box(boxName);
    return box.values.toList();
  }

}