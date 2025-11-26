import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceImageHelper {
  FaceDetector? _faceDetector;
  double smileThreshould = 0.5;

  Function(int? smileCount, double? smileProb)? onDebugInfo;

  Future<void> initializeFaceDetector() async {
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<bool> detectSmile(InputImage inputImage) async {
    if (_faceDetector == null) {
      debugPrint('FaceDetector is not initialized.');
      return false;
    }

    try {
      final faces = await _faceDetector!.processImage(inputImage);

      debugPrint('Faces detected: ${faces.length}');
      if (faces.isNotEmpty) {
        final face = faces.first;
        final smilingProb = face.smilingProbability ?? 0;
        debugPrint(
          '😊 Smile probability: ${(smilingProb * 100).toStringAsFixed(1)}% (threshold: ${(smileThreshould * 100).toStringAsFixed(0)}%)',
        );

        // Kirim debug info ke UI
        onDebugInfo?.call(faces.length, smilingProb);

        return smilingProb > smileThreshould;
      }else{
        onDebugInfo?.call(0, 0);
        debugPrint('😊 Smile probability: 0% (threshold: ${(smileThreshould * 100).toStringAsFixed(0)}%)');
      }

      return false;
    } catch (e) {
      debugPrint('Error during face detection: $e');
      return false;
    }
  }

  void dispose() {
    _faceDetector?.close();
  }
}
