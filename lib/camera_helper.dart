import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraHelper {
  CameraController? _cameraController;
  CameraController get controller => _cameraController!;
  bool get init => _cameraController?.value.isInitialized ?? false;
  double get aspectRatio => _cameraController?.value.aspectRatio ?? 0.0;

  /// Initialize the camera controller with the given list of cameras.
  ///
  /// If the list contains a front camera, it is used. Otherwise, the first
  /// camera in the list is used.
  ///
  /// The camera controller is initialized with the high resolution preset,
  /// audio disabled, and image format group set to ImageFormatGroup.nv21.
  ///
  /// The initialization is awaited.
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

  /// Starts the camera image stream and calls [onImage] with the camera image.
  ///
  /// [onImage] is a callback that is called with the camera image for each frame.
  /// It is called on the platform's main thread.
  ///
  /// The image stream is stopped when [stopStreamCamera] is called.
  ///
  /// The image stream is not started if the camera controller is not initialized.
  ///
  /// The image stream is not started if the camera controller is null.
  ///
  /// The image stream is not started if the camera controller is not initialized.
  ///
  void startStreamCamera(Function(CameraImage) onImage) {
    _cameraController?.startImageStream(onImage);
  }

  /// Stops the camera image stream.
  ///
  /// If the camera controller is null, this does nothing.
  /// If the camera controller is not initialized, this does nothing.
  ///
  /// The camera image stream is stopped when this is called.
  void stopStreamCamera() {
    _cameraController?.stopImageStream();
  }

  /// Takes a picture with the camera and returns the path to the saved image.
  ///
  /// The camera controller must be initialized before calling this method.
  ///
  /// If the camera controller is null or not initialized, this method returns null.
  ///
  /// If an error occurs while taking the picture, this method re-throws the error.
  ///
  /// The image is saved to the device's default directory for saving images.
  Future<String?> takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }

    try {
      final image = await _cameraController!.takePicture();


      return image.path;
    } catch (e) {
      throw Exception(e);
    }
  }

  /// Disposes the camera controller. This should be called when the camera helper is no
  /// longer needed. If the camera controller is null, this does nothing.
  void dispose() {
    _cameraController?.dispose();
  }
}
