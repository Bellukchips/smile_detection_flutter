// import 'dart:math' as math;
// import 'dart:typed_data';

// // ignore: depend_on_referenced_packages
// import 'package:image/image.dart' as img;
// import 'package:tflite_flutter/tflite_flutter.dart';

// class TfliteService {
//   static late Interpreter _interpreter;
//   static final int inputSize = 112;
//   static final int embeddingSize = 128;

//   static Future<void> loadModel() async {
//     _interpreter = await Interpreter.fromAsset(
//       'assets/custom_ssd_mobilenet_v2.tflite',
//     );
//   }

//   static Future<Float32List> preprocess(Uint8List imageBytes) async {
//     // Decode JPEG/PNG
//     img.Image? image = img.decodeImage(imageBytes);
//     if (image == null) throw Exception("Failed to decode image");

//     // Resize to 112×112 (MobileFaceNet input)
//     final resized = img.copyResize(image, width: 112, height: 112);

//     // Create model input buffer
//     final input = Float32List(112 * 112 * 3);
//     int index = 0;

//     // MobileFaceNet preprocessing → normalized to [-1,1]
//     for (int y = 0; y < 112; y++) {
//       for (int x = 0; x < 112; x++) {
//         final pixel = resized.getPixel(x, y);

//         final r = img.getRed(pixel);
//         final g = img.getGreen(pixel);
//         final b = img.getBlue(pixel);

//         input[index++] = (r - 127.5) / 128.0;
//         input[index++] = (g - 127.5) / 128.0;
//         input[index++] = (b - 127.5) / 128.0;
//       }
//     }

//     return input;
//   }

//   static Future<List<double>> generateEmbedding(Uint8List bytes) async {
//     final input = await preprocess(bytes);

//     // Output buffer (embedding size = 128)
//     final output = List.filled(128, 0.0).reshape([1, 128]);

//     _interpreter.run(input.reshape([1, 112, 112, 3]), output);

//     List<double> emb = List<double>.from(output[0]);

//     // L2 normalize
//     final norm = math.sqrt(emb.fold(0, (p, e) => p + e * e));
//     return emb.map((e) => e / norm).toList();
//   }
// }
