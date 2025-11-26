import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  Future<Face?> processImage(
    Uint8List bytes,
    Size imageSize,
    int rotation,
  ) async {
    final inputRange = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: imageSize.width.toInt(),
      ),
    );

    final faces = await _detector.processImage(inputRange);

    if(faces.isNotEmpty) return faces.first;

    return null;
  }


  void dispose(){
    _detector.close();
  }
}
