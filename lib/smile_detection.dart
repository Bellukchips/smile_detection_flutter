
import 'package:camera/camera.dart';
import 'package:face_detection_local/camera_helper.dart';
import 'package:face_detection_local/face_image_helper.dart';
import 'package:face_detection_local/image_convert.dart';

class SmileDetection {
  SmileDetection(this.cameraHelper, this.faceImageHelper);

  final CameraHelper cameraHelper;
  final FaceImageHelper faceImageHelper;

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

  void toggleAutoCapture() {
    _autocCapture = !_autocCapture;
  }

  void startDetection() {
    cameraHelper.startStreamCamera(_processCameraImage);
  }

  void stopDetection() {
    cameraHelper.stopStreamCamera();
  }

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

  Future<void> _capturePhoto() async {
    final imagePath  = await cameraHelper.takePicture();

    if(imagePath != null) {
      _lastCapture = imagePath;
      onCaptureChanged?.call(imagePath);

      await Future.delayed(const Duration(seconds: 3));
    }

  }

  void dispose(){
    stopDetection();
  }
}
