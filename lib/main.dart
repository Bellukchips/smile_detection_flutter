// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_detection_local/camera_helper.dart';
import 'package:face_detection_local/face_image_helper.dart';
import 'package:face_detection_local/smile_detection.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SmileCamera(cameras: widget.cameras),
    );
  }
}

class SmileCamera extends StatefulWidget {
  const SmileCamera({super.key, required this.cameras});

  final List<CameraDescription> cameras;
  @override
  State<SmileCamera> createState() => _SmileCameraState();
}

class _SmileCameraState extends State<SmileCamera> {
  late CameraHelper _cameraHelper;
  late FaceImageHelper _faceImageHelper;
  late SmileDetection _smileDetection;

  bool _initialized = false;
  bool _isSimlling = false;
  String? _lastCaptureImage;

  int _faceCount = 0;
  double? _smileProb;
  Future<void> _initializedService() async {
    _cameraHelper = CameraHelper();
    _faceImageHelper = FaceImageHelper();
    _smileDetection = SmileDetection(_cameraHelper, _faceImageHelper);

    await _cameraHelper.initCamera(widget.cameras);
    _faceImageHelper.initializeFaceDetector();

    _smileDetection.onSmileChanged = (isSmilling) {
      if (mounted) {
        setState(() {
          _isSimlling = isSmilling;
        });
      }
    };

    _smileDetection.onCaptureChanged = (imagePath) {
      if (mounted) {
        setState(() {
          _lastCaptureImage = imagePath;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Smile detected! Photo captured!'),
          duration: Duration(seconds: 2),
        ),
      );
    };

    _faceImageHelper.onDebugInfo = (faceCount, smileProb) {
      if (mounted) {
        setState(() {
          _faceCount = faceCount!;
          _smileProb = smileProb;
        });
      }
    };

    _smileDetection.startDetection();
    setState(() {
      _initialized = true;
    });
  }

  @override
  void initState() {
    _initializedService();
    super.initState();
  }

  @override
  void dispose() {
    _smileDetection.dispose();
    _cameraHelper.dispose();
    _faceImageHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || !_cameraHelper.init) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection'),
        actions: [
          IconButton(
            icon: Icon(
              _smileDetection.isAutoCapture
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined,
            ),
            onPressed: () {
              setState(() {
                _smileDetection.toggleAutoCapture();
              });
            },
            tooltip: 'Auto Capture',
          ),
        ],
      ),

      body: Stack(
        children: [
          CameraPreview(_cameraHelper.controller),

          Positioned(
            top: 20,
            left: 0,
            right: 0,

            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isSimlling ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Column(
                  children: [
                    Text(
                      _isSimlling ? '😊 Smiling!' : '😐 Smile to capture',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Faces: $_faceCount | Smile: ${_smileProb != null ? "${(_smileProb! * 100).toStringAsFixed(0)}%" : "N/A"}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_lastCaptureImage != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ImagePreviewScreen(imagePath: _lastCaptureImage!),
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      File(_lastCaptureImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final String imagePath;
  const ImagePreviewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captured Photo')),
      body: Center(child: Image.file(File(imagePath))),
    );
  }
}
