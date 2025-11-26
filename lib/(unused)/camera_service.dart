import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

typedef FrameCallback =
    void Function(Uint8List bytes, Size imageSize, int rotation);

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;
  CameraDescription? _cameraDescription;
  StreamSubscription? _streamSubscription;

  Future<void> init() async {
    final cameras = await availableCameras();
    _cameraDescription = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      _cameraDescription!,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  void startImageStream(FrameCallback onFrame) {
    if (_controller == null) return;
    _controller!.startImageStream((CameraImage image) async {
      try {
        final bytes = _concanatePlanes(image.planes);
        final size = Size(image.width.toDouble(), image.height.toDouble());
        final rotation = 0;
        onFrame(bytes, size, rotation);
      } catch (e) {
        throw Exception(e);
      }
    });
  }

  Future<void> stopImageStream() async {
    if (_controller == null) return;
    await _controller?.stopImageStream();
  }

  Future<Uint8List> captureCropFaces() async {
    if (_controller == null && _controller!.value.isInitialized) {
      return Uint8List(0);
    }

    try {
      final file = await _controller!.takePicture();
      final bytes = await File(file.path).readAsBytes();
      return bytes;
    } catch (e) {
      throw Exception(e);
    }
  }

  Uint8List _concanatePlanes(List<Plane> plane) {
    final allBytes = BytesBuilder();

    for (final planes in plane) {
      allBytes.add(planes.bytes);
    }
    return allBytes.toBytes();
  }

  void dispose() {
    _streamSubscription?.cancel();
    _controller?.dispose();
  }
}
