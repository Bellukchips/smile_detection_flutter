import 'package:camera/camera.dart';
import 'package:face_detection_local/camera_helper.dart';
import 'package:face_detection_local/image_convert.dart';
import 'package:face_detection_local/ml_service.dart';

class SmileDetection {
  SmileDetection(this.cameraHelper, this.faceImageHelper);

  final CameraHelper cameraHelper;
  final MlService faceImageHelper;

  bool _isDetection = false;
  bool _isSmilling = false;
  bool _autocCapture = false;
  String? _lastCapture;

  Function(bool)? onSmileChanged;
  Function(String)? onCaptureChanged;

  bool get isSmiling => _isSmilling;
  bool get isDetection => _isDetection;
  bool get isAutoCapture => _autocCapture;
  String? get lastCapture => _lastCapture;

  /// Toggle the auto capture feature. If it is currently enabled,
  /// it will be disabled, and vice versa.
  void toggleAutoCapture() {
    _autocCapture = !_autocCapture;
  }

  /// Starts the detection of faces in the camera image stream. When a face is
  /// detected, the [onSmileChanged] callback is called with the detected smile
  /// value. If the auto capture feature is enabled, the camera image is also
  /// saved to the device's default directory for saving images and the
  /// [onCaptureChanged] callback is called with the path to the saved image.
  ///
  /// If the detection is already started, this does nothing.
  void startDetection() {
    cameraHelper.startStreamCamera(_processCameraImage);
  }

  /// Stops the detection of faces in the camera image stream.
  /// If the detection is not started, this does nothing.
  void stopDetection() {
    cameraHelper.stopStreamCamera();
  }

  /// Processes a single camera image frame to detect a smile. If a smile is
  /// detected and the auto capture feature is enabled, the camera image is
  /// saved to the device's default directory for saving images and the
  /// [onCaptureChanged] callback is called with the path to the saved image.
  ///
  /// When the detection is finished, the [onSmileChanged] callback is called with
  /// the detected smile value. If the detection failed, an exception is thrown.
  ///
  /// If the detection is already running or the auto capture feature is disabled,
  /// this does nothing.
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetection || !_autocCapture) return;

    _isDetection = true;

    final inputImage = ImageConvert.convertImage(
      image,
      cameraHelper.controller.description,
    );

    if (inputImage == null) {
      _isDetection = false;
      return;
    }

    try {
      final isSmile = await faceImageHelper.detectSmile(inputImage);
      if (isSmile && !_isSmilling) {
        await _capturePhoto();
      }

      if (_isSmilling != isSmile) {
        _isSmilling = isSmile;

        onSmileChanged?.call(_isSmilling);
      }
    } catch (e) {
      throw Exception(e);
    } finally {
      _isDetection = false;
    }
  }

  /// Captures a photo with the camera and calls [onCaptureChanged] with the path to the saved image.
  ///
  /// If the photo capture failed, this does nothing.
  ///
  /// After the photo is captured, this waits for 3 seconds before completing.
  Future<void> _capturePhoto() async {
    final imagePath = await cameraHelper.takePicture();

    if (imagePath != null) {
      _lastCapture = imagePath;
      onCaptureChanged?.call(imagePath);

      await Future.delayed(const Duration(seconds: 3));
    }
  }

/// Stops the detection of faces in the camera image stream when this
/// object is disposed. If the detection is not started, this
/// does nothing.
  void dispose() {
    stopDetection();
  }
}
