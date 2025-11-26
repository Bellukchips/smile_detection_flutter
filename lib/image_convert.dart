import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ImageConvert {
  static InputImage? convertImage(CameraImage image, CameraDescription camera) {
    final sensorDesc = camera.sensorOrientation;
    InputImageRotation? rotate;

    if (Platform.isIOS) {
      rotate = InputImageRotationValue.fromRawValue(sensorDesc);
    } else if (Platform.isAndroid) {
      var rotationCompensation = sensorDesc;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorDesc + 90) % 360;
      } else {
        rotationCompensation = (sensorDesc - 90 + 360) % 360;
      }

      rotate = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotate == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotate,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
