// import 'package:hive/hive.dart';

// class StorageService {
//   static const String boxName = 'faces_box';
//   static Box? _box;

//   static Future<void> init() async {
//     _box = await Hive.openBox(boxName);
//   }

//   static Future<void> saveEmbedding(String key, List<double> emb) async {
//     await _box!.put(key, emb);
//   }

//   static List<double>? getEmbedding(String key) {
//     final raw = _box!.get(key);
//     if (raw == null) return null;
//     return List<double>.from(raw.cast<double>());
//   }
// }
  