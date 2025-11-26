// import 'package:face_detection_local/(unused)/camera_service.dart';
// import 'package:face_detection_local/(unused)/face_detector.dart';
// import 'package:face_detection_local/preview_camera_widget.dart';
// import 'package:face_detection_local/storage_service.dart';
// import 'package:face_detection_local/tflite_service.dart';
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Hive.initFlutter();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(title: 'Flutter Demo', home: const CameraContainer());
//   }
// }

// class CameraContainer extends StatefulWidget {
//   const CameraContainer({super.key});

//   @override
//   State<CameraContainer> createState() => _CameraContainerState();
// }

// class _CameraContainerState extends State<CameraContainer> {
//   final CameraService _cameraService = CameraService();
//   final FaceDetectorService _faceService = FaceDetectorService();

//   String status = 'Idle';

//   @override
//   void initState() {
//     super.initState();
//     _initAll();
//   }

//   Future<void> _initAll() async {
//     await _cameraService.init();
//     _cameraService.startImageStream((bytes, size, rotation) async {
//       // Process with ML Kit
//       final face = await _faceService.processImage(bytes, size, rotation);
//       if (face != null) {
//         setState(() => status = 'Face detected');
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _cameraService.dispose();
//     _faceService.dispose();
//     super.dispose();
//   }

//   Future<void> _registerFace() async {
//     setState(() => status = 'Capturing...');
//     final cropped = await _cameraService.captureCropFaces();
//     if (cropped.isEmpty) {
//       setState(() => status = 'No face captured');
//       return;
//     }

//     final emb = await TfliteService.generateEmbedding(cropped);
//     await StorageService.saveEmbedding('user_face', emb);
//     setState(() => status = 'Face registered');
//   }

//   Future<void> _verifyFace() async {
//     setState(() => status = 'Verifying...');
//     final saved = StorageService.getEmbedding('user_face');
//     if (saved == null) {
//       setState(() => status = 'No registered face');
//       return;
//     }

//     final cropped = await _cameraService.captureCropFaces();
//     if (cropped.isEmpty) {
//       setState(() => status = 'No face captured');
//       return;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Face Verify Demo')),
//       body: Column(
//         children: [
//           Expanded(
//             child: CameraPreviewWidget(controller: _cameraService.controller),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Column(
//               children: [
//                 Text('Status: $status'),
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton(
//                       onPressed: _registerFace,
//                       child: const Text('Register'),
//                     ),
//                     ElevatedButton(
//                       onPressed: _verifyFace,
//                       child: const Text('Verify'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
