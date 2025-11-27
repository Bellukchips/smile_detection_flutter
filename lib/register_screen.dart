// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:face_detection_local/camera_helper.dart';
import 'package:face_detection_local/database_service.dart';
import 'package:face_detection_local/ml_service.dart';
import 'package:face_detection_local/models/user.dart';
import 'package:face_detection_local/smile_detection.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.cameras});
  final List<CameraDescription> cameras;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();

  late CameraHelper _cameraHelper;
  late MlService _mlService;
  late SmileDetection _smileDetection;
  // CameraController? _controller;
  String? _capturedImagePath;
  bool _isProcessing = false;
  bool _initialized = false;
  bool _isSimlling = false;
  int _faceCount = 0;
  double? _smileProb;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraHelper = CameraHelper();
      _mlService = MlService.instance;
      _smileDetection = SmileDetection(_cameraHelper, _mlService);

      await _cameraHelper.initCamera(widget.cameras);
      _mlService.intialized();

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
            _capturedImagePath = imagePath;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Smile detected! Photo captured!'),
            duration: Duration(seconds: 2),
          ),
        );
      };

      _mlService.onDebugInfo = (faceCount, smileProb) {
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
    } catch (e) {
      print('❌ Camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _registerFace() async {
    if (!_formKey.currentState!.validate()) return;
    if (_capturedImagePath == null) {
      _showError('Please capture a face image first');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check if employee ID already exists
      final existing = await DatabaseService.instance.getUserByEmployeeId(
        _employeeIdController.text,
      );

      if (existing != null) {
        throw Exception('Employee ID already registered');
      }

      // Generate face embedding
      final embedding = await MlService.instance.generateEmbedding(
        _capturedImagePath!,
      );

      // Save photo permanently
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final savedPath = '${directory.path}/$fileName';
      await File(_capturedImagePath!).copy(savedPath);

      // Create user model
      final user = UserModel(
        id: const Uuid().v4(),
        name: _nameController.text,
        employeeId: _employeeIdController.text,
        departement: _departmentController.text,
        faceEmbedding: embedding,
        photoPath: savedPath,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save to database
      await DatabaseService.instance.insertUser(user);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${user.name} registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _smileDetection.dispose();
    _cameraHelper.dispose();
    _mlService.dispose();
    _nameController.dispose();
    _employeeIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Face'),
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
      body: !_initialized || !_cameraHelper.init
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Camera Preview
                    SizedBox(
                      height: _capturedImagePath == null ? 600 : 380,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: _capturedImagePath == null
                            ? AspectRatio(
                                aspectRatio: _cameraHelper.aspectRatio,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CameraPreview(_cameraHelper.controller),
                                    // Face oval overlay
                                    CustomPaint(
                                      size: Size.fromHeight(20),
                                      painter: FaceOvalPainter(),
                                    ),
                                    // Instructions
                                    Positioned(
                                      top: 10,
                                      left: 0,
                                      right: 0,
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            color: _isSimlling
                                                ? Colors.green
                                                : Colors.red,
                                            child: Text(
                                              'Position your face in the oval ${_isSimlling ? '😊 Smiling!' : '😐 Smile to capture'}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
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
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Image.file(
                                    File(_capturedImagePath!),
                                    height: 300,
                                    fit: BoxFit.cover,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _capturedImagePath = null;
                                        });
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retake Photo'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Capture Button
                    // if (_capturedImagePath == null)
                    //   ElevatedButton.icon(
                    //     onPressed: _captureImage,
                    //     icon: const Icon(Icons.camera),
                    //     label: const Text('Capture Face'),
                    //     style: ElevatedButton.styleFrom(
                    //       minimumSize: const Size(double.infinity, 50),
                    //     ),
                    //   ),
                    const SizedBox(height: 24),

                    // Form Fields
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _employeeIdController,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter employee ID';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter department';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Register Button
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _registerFace,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.how_to_reg),
                      label: Text(_isProcessing ? 'Processing...' : 'Register'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class FaceOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * 0.35;
    final radiusY = size.height * 0.30;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
