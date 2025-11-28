import 'dart:io';
import 'package:face_detection_local/ml_service.dart';
import 'package:face_detection_local/models/access_log.dart';
import 'package:face_detection_local/models/verification_result.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';


class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  CameraController? _controller;
  bool _isVerifying = false;
  VerificationResult? _lastResult;
  String? _errorMessage;

  @override
  /// Initialize the camera controller and start the verification process.
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Initialize the camera controller and start the verification process.
  ///
  /// This method gets the list of available cameras, and tries to get the front camera.
  /// If no front camera is found, it falls back to using the first available camera.
  ///
  /// After selecting a camera, it initializes the camera controller with the high
  /// resolution preset, disables audio, and initializes the camera controller.
  ///
  /// If the camera initialization fails, it displays an error message and shows a
  /// SnackBar with the error message.
  ///
  /// If the camera initialization succeeds, it sets the state to update the UI and
  /// prints a success message to the console.
  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      // Get available cameras
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        throw Exception('No cameras found on this device');
      }

      print('📷 Available cameras: ${cameras.length}');

      // Try to get front camera, fallback to any available camera
      CameraDescription? selectedCamera;
      
      try {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        print('✅ Using front camera: ${selectedCamera.name}');
      } catch (e) {
        print('⚠️ No front camera found, using first available camera');
        selectedCamera = cameras.first;
        print('✅ Using camera: ${selectedCamera.name}');
      }

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      if (mounted) {
        setState(() {});
        print('✅ Camera initialized successfully');
      }
    } catch (e) {
      print('❌ Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera error: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Verify the face in the camera image stream with all registered users in the database.
  ///
  /// If the verification succeeds, it saves an access log with the user details and
  /// confidence score. If the verification fails, it saves an access log with the
  /// reason for the failure.
  ///
  /// After the verification, it shows a result dialog with the verification result.
  ///
  /// If an error occurs during the verification, it shows an error message dialog with
  /// the error message.
  Future<void> _verifyFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _lastResult = null;
    });

    String? capturedImagePath;

    try {
      // Capture image
      final image = await _controller!.takePicture();
      capturedImagePath = image.path;

      // Get all registered users
      final users = await DatabaseService.instance.getAllUsers();

      if (users.isEmpty) {
        throw Exception('No registered users in database');
      }

      // Find best match
      final result = await MlService.instance
          .verifyFace(capturedImagePath, users);

      // Save log
      final log = AccessLogModel(
        id: const Uuid().v4(),
        userId: result.user?.id,
        userName: result.user?.name,
        action: result.success ? 'granted' : 'denied',
        confidenceScore: result.confidence,
        photoPath: result.success ? null : capturedImagePath,
        timestamp: result.timestamp,
        reason: result.message,
      );

      await DatabaseService.instance.insertAccessLog(log);

      setState(() {
        _lastResult = result;
      });

      // Show result dialog
      if (mounted) {
        _showResultDialog(result);
      }
    } catch (e) {
      setState(() {
        _lastResult = VerificationResult(
          success: false,
          message: e.toString(),
        );
      });
      _showError(e.toString());
    } finally {
      setState(() {
        _isVerifying = false;
      });

      // Clean up captured image if verification failed
      if (capturedImagePath != null && _lastResult?.success == true) {
        try {
          await File(capturedImagePath).delete();
        } catch (_) {}
      }
    }
  }

/// Show a dialog with the verification result.
///
/// The dialog title is "Access Granted" or "Access Denied" depending on the
/// verification result. If the verification is successful, the dialog content
/// shows the user's name, employee ID and department. If the verification fails,
/// the dialog content shows the reason for the failure. The dialog has a single "OK"
/// button to dismiss it.
  void _showResultDialog(VerificationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.cancel,
              color: result.success ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(result.success ? 'Access Granted' : 'Access Denied'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.success && result.user != null) ...[
              _InfoRow(
                icon: Icons.person,
                label: 'Name',
                value: result.user!.name,
              ),
              _InfoRow(
                icon: Icons.badge,
                label: 'Employee ID',
                value: result.user!.employeeId,
              ),
              _InfoRow(
                icon: Icons.business,
                label: 'Department',
                value: result.user!.department,
              ),
              _InfoRow(
                icon: Icons.verified,
                label: 'Confidence',
                value: '${(result.confidence! * 100).toStringAsFixed(1)}%',
              ),
            ] else ...[
              Text(
                result.message ?? 'Unknown error',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

/// Shows an error message as a red SnackBar.
///
/// [message] is the error message to be shown.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
/// Releases the resources used by the [_VerifyScreenState] object.
///
/// This method is invoked when this object is no longer needed.
/// It is always safe to call this method, and it must be called when
/// the object is no longer needed to prevent memory leaks.
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
/// Builds a screen for face verification.
///
/// If the camera is not initialized, it shows an error screen.
/// If the camera is initialized, it shows a camera preview and
/// an overlay of a face oval. It also shows instructions on how
/// to position the face and a button to start verification.
///
/// After verification is complete, it shows the result of the
/// verification as a success or failure indicator.
  Widget build(BuildContext context) {
    // Show error screen if camera failed to initialize
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face Verification'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _initializeCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Verification'),
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera Preview
                CameraPreview(_controller!),
                
                // Face oval overlay
                CustomPaint(
                  painter: FaceOvalPainter(),
                ),
                
                // Instructions
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.face_unlock_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Position your face in the oval',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Look straight at the camera',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Last Result Indicator
                if (_lastResult != null)
                  Positioned(
                    top: 180,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _lastResult!.success
                            ? Colors.green.withOpacity(0.9)
                            : Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastResult!.success
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastResult!.success
                                  ? '✓ ${_lastResult!.user?.name}'
                                  : '✗ ${_lastResult!.message}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Verify Button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        // Main verify button
                        GestureDetector(
                          onTap: _isVerifying ? null : _verifyFace,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _isVerifying
                                  ? Colors.grey
                                  : Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: _isVerifying
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(
                                    Icons.face_unlock_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isVerifying ? 'Verifying...' : 'Tap to Verify',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
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

    final dashPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = size.width * 0.4;
    final radiusY = size.height * 0.25;

    // Draw main oval
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      ),
      paint,
    );

    // Draw corner guides
    final cornerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    const cornerLength = 30.0;
    
    // Top-left
    canvas.drawLine(
      Offset(center.dx - radiusX, center.dy - radiusY),
      Offset(center.dx - radiusX + cornerLength, center.dy - radiusY),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radiusX, center.dy - radiusY),
      Offset(center.dx - radiusX, center.dy - radiusY + cornerLength),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(center.dx + radiusX, center.dy - radiusY),
      Offset(center.dx + radiusX - cornerLength, center.dy - radiusY),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radiusX, center.dy - radiusY),
      Offset(center.dx + radiusX, center.dy - radiusY + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(center.dx - radiusX, center.dy + radiusY),
      Offset(center.dx - radiusX + cornerLength, center.dy + radiusY),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radiusX, center.dy + radiusY),
      Offset(center.dx - radiusX, center.dy + radiusY - cornerLength),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(center.dx + radiusX, center.dy + radiusY),
      Offset(center.dx + radiusX - cornerLength, center.dy + radiusY),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radiusX, center.dy + radiusY),
      Offset(center.dx + radiusX, center.dy + radiusY - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}