
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraHelper {
  CameraController? _cameraController;
  CameraController get controller => _cameraController!;
  bool get init => _cameraController?.value.isInitialized ?? false;

  Future<void> initCamera(List<CameraDescription> cameras) async {
    await Permission.camera.request();

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController?.initialize();
  }

  void startStreamCamera(Function(CameraImage) onImage) {
    _cameraController?.startImageStream(onImage);
  }

  void stopStreamCamera() {
    _cameraController?.stopImageStream();
  }



  Future<String?> takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }

    try {
      final image = await _cameraController!.takePicture();

      final directory = await getApplicationDocumentsDirectory();

      final imagePath =
          '/${directory.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await image.saveTo(imagePath);

      return imagePath;
    } catch (e) {
      throw Exception(e);
    }
  }

  void dispose() {
    _cameraController?.dispose();
  }
}
