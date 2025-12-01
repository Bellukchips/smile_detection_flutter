// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:camera/camera.dart';
import 'package:face_detection_local/database_service.dart';
import 'package:face_detection_local/main_page.dart';
import 'package:face_detection_local/ml_service.dart';
import 'package:face_detection_local/unit_test.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cameras
  final cameras = await availableCameras();
  print('✅ Found ${cameras.length} camera(s)');

  // Initialize services
  await DatabaseService.instance.database;
  print('✅ Database initialized');

  await MlService.instance.intialized();

  await runAllDatabaseTests();
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
      home: MainPage(cameras: widget.cameras,),
    );
  }
}
