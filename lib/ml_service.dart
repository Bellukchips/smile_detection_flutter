import 'dart:io';
import 'dart:math';
import 'package:face_detection_local/models/user.dart';
import 'package:face_detection_local/models/verification_result.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class MlService {
  static final MlService instance = MlService._init();

  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  Logger logger = Logger();
  Function(int? smileCount, double? smileProb)? onDebugInfo;

  //Trheshold
  static const double VERIFICATION_THRESHOLD = 0.5;
  static const double QUALITY_THRESHOLD = 0.6;
  static const int EMBEDDING_SIZE = 128;

  MlService._init();

  /// Initialize the face detector and the model interpreter.
  ///
  /// This function sets up the face detector with the desired options and loads
  /// the model interpreter from the mobile_face_net.tflite asset. If the model
  /// loads successfully, it prints a success message to the logger. If
  /// the model fails to load, it prints an error message to the logger.
  ///
  /// This function should be called before any other functions in this class.
  ///
  Future<void> intialized() async {
    logger.i('MlService intialized');

    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    );

    _faceDetector = FaceDetector(options: options);

    try {
      _interpreter = await Interpreter.fromAsset(
        "assets/mobile_face_net.tflite",
      );
      logger.i('Model loaded successfully');
    } catch (e) {
      logger.e('Failed to load model: $e');
    }
  }

  /// Detect a single face in the given image.
  ///
  /// This function takes a path to an image as an argument and uses the face detector
  /// to detect faces in the image. If no faces are detected, it throws an exception.
  /// If more than one face is detected, it throws an exception. Otherwise, it returns the
  /// single face that was detected.
  ///
  /// The function logs a message to the logger indicating how many faces were detected.
  /// If an exception is thrown, it is logged to the logger with an error level.
  Future<Face?> detectionSingleFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector!.processImage(inputImage);

    logger.i('detected ${faces.length} face(s)');

    if (faces.isEmpty) {
      throw Exception('No face detected');
    }

    if (faces.length > 1) {
      throw Exception('Multiple face detected');
    }

    return faces.first;
  }

  /// Checks the quality of a face in an image.
  ///
  /// This function takes a face detected by the face detector and an image path as arguments.
  /// It checks the size of the face relative to the image size and throws an exception if
  /// the face is too small or too close to the camera. It also checks the head angles of the
  /// face and throws an exception if the head is too frontal or too tilted.
  ///
  /// The function logs messages to the logger indicating the face ratio and head angles.
  /// If an exception is thrown, it is logged to the logger with an error level.
  ///
  /// Returns true if the face passes all the checks, or throws an exception if any of the checks fail.
  Future<bool> checkFaceQuality(Face face, String imagePath) async {
    final boundingBox = face.boundingBox;
    final faceSize = boundingBox.width * boundingBox.height;

    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return false;

    final imageSize = image.width * image.height;
    final faceRatio = faceSize / imageSize;

    logger.i('Face ratio : ${(faceRatio * 100).toStringAsFixed(1)}%');

    if (faceRatio < 0.05) {
      logger.i('Face too small');
      throw Exception('Face too small');
    }
    logger.i(faceRatio);

    if (faceRatio > 0.85) {
      logger.i('Face too close');
      throw Exception('Face too close');
    }

    final headeEulerAngleY = face.headEulerAngleY ?? 0;
    final headEulerAngleX = face.headEulerAngleX ?? 0;

    logger.i(
      'Head angles : Y: ${headeEulerAngleY.toStringAsFixed(1)}, X: ${headEulerAngleX.toStringAsFixed(1)}',
    );

    if (headEulerAngleX.abs() > 25) {
      logger.i('Head too frontal');
      throw Exception('Head too frontal');
    }

    if (headeEulerAngleY.abs() > 25) {
      logger.i('Head too tilted');
      throw Exception('Head too tilted');
    }

    return true;
  }

  Future<img.Image> preProcessFace(String imagePath, Face face) async {
    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return throw Exception('Failed to decode image');

    final boudingBox = face.boundingBox;
    final margin = 20;

    final x = max(0, boudingBox.left.toInt() - margin);
    final y = max(0, boudingBox.top.toInt() - margin);
    final width = min(image.width - x, boudingBox.width.toInt() + margin * 2);
    final height = min(
      image.height - y,
      boudingBox.height.toInt() + margin * 2,
    );

    final croppedFace = img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );

    final resizedFace = img.copyResize(croppedFace, width: 112, height: 112);
    return resizedFace;
  }

  Future<List<double>> generateEmbedding(String imagePath) async {
    logger.i('Generate embedding');

    final face = await detectionSingleFace(imagePath);

    if (face == null) {
      throw Exception('No face detected');
    }

    await checkFaceQuality(face, imagePath);

    final processedFace = await preProcessFace(imagePath, face);

    if (_interpreter != null) {
      return await _generateEmbeddingWithModel(processedFace);
    } else {
      return _generateMockEmbedding(imagePath);
    }
  }

  /// Generates a face embedding using a pre-trained model.
  ///
  /// This function takes a pre-processed face image and generates a face embedding
  /// using a pre-trained model. The model is loaded from the assets folder and
  /// the input is normalized to be in the range of -1 to 1. The output is
  /// a list of 128 doubles representing the face embedding.
  ///
  /// The function returns a future that resolves to the face embedding. If the
  /// model fails to load, it throws an exception.
  Future<List<double>> _generateEmbeddingWithModel(img.Image image) async {
    final input = List.generate(
      1,
      (i) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) => List.generate(3, (c) {
            final pixel = image.getPixel(x, y);
            double value;
            if (c == 0) {
              value = pixel.r.toDouble();
            } else if (c == 1) {
              value = pixel.g.toDouble();
            } else {
              value = pixel.b.toDouble();
            }
            return (value - 127.5) / 127.5;
          }),
        ),
      ),
    );

    final output = List.filled(1, List.filled(EMBEDDING_SIZE, 0.0));

    _interpreter!.run(input, output);

    final embedding = output[0];
    return _l2Normalize(embedding);
  }

  /// Generates a mock embedding for the given image path.
  ///
  /// This function generates a random list of doubles of length [EMBEDDING_SIZE] and
  /// returns it as a mock embedding. The random list is generated using a Random
  /// object seeded with the hash code of the image path. This ensures that the
  /// same image path will always generate the same mock embedding.
  List<double> _generateMockEmbedding(String imagePath) {
    final random = Random(imagePath.hashCode);
    return List.generate(EMBEDDING_SIZE, (_) => (random.nextDouble() * 2 - 1));
  }

  /// Normalize a list of doubles by L2 norm.
  ///
  /// The L2 norm is calculated by summing the squares of all elements in the list
  /// and taking the square root of the sum. The normalized list is then obtained by
  /// dividing all elements by the norm.
  ///
  /// This function is used to normalize the embedding before it is used in the KNN
  /// algorithm.
  List<double> _l2Normalize(List<double> embedding) {
    final sum = embedding.fold<double>(0, (a, b) => a + b * b);
    final norm = sqrt(sum);
    return embedding.map((e) => e / norm).toList();
  }

  /// Calculate the similarity between two embeddings.
  ///
  /// The similarity is calculated as the cosine of the angle between the two
  /// embeddings. The embeddings must have the same length.
  ///
  /// Returns a value between 0 and 1, where 0 indicates no similarity and 1 indicates
  /// identical embeddings.
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Embeddings must have the same length');
    }

    double dotProduct = 0;
    double norm1 = 0;
    double norm2 = 0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    final similarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    return (similarity + 1) / 2;
  }

  /// Calculate the Euclidean distance between two embeddings.
  ///
  /// The Euclidean distance is a measure of the straight-line distance between two points in n-dimensional space.
  ///
  /// This function takes two embeddings as input and returns the Euclidean distance between them.
  /// The embeddings must have the same length.
  ///
  /// Returns a double value representing the Euclidean distance between the two embeddings.
  double calculateEuclideanDistance(
    List<double> embedding1,
    List<double> embedding2,
  ) {
    double sum = 0;
    for (int i = 0; i < embedding1.length; i++) {
      final diff = embedding1[i] - embedding2[i];
      sum += diff * diff;
    }

    return sqrt(sum);
  }

  bool isMatch(List<double> embedding1, List<double> embedding2) {
    final similarity = calculateSimilarity(embedding1, embedding2);

    logger.i('similarity score : ${(similarity * 100).toStringAsFixed(1)}%');

    return similarity >= VERIFICATION_THRESHOLD;
  }

  Future<VerificationResult> verifyFace(
    String imagePath,
    List<UserModel> registeredUsers,
  ) async {
    try {
      final inputEmbedding = await generateEmbedding(imagePath);

      if (registeredUsers.isEmpty) {
        return VerificationResult(
          success: false,
          message: 'No user registered',
        );
      }

      List<({UserModel user, double score})> matches = [];

      for (final user in registeredUsers) {
        final similarity = calculateSimilarity(
          inputEmbedding,
          user.faceEmbedding,
        );

        matches.add((user: user, score: similarity));
      }

      matches.sort((a, b) => b.score.compareTo(a.score));

      final bestMatch = matches.first;

      logger.i(
        'best match score ${bestMatch.user.name} : ${(bestMatch.score * 100).toStringAsFixed(1)}%',
      );

      if (bestMatch.score >= VERIFICATION_THRESHOLD) {
        return VerificationResult(
          success: true,
          user: bestMatch.user,
          confidence: bestMatch.score,
          message: 'Verified',
        );
      } else {
        return VerificationResult(
          success: false,
          message: 'Failed',
          confidence: bestMatch.score,
        );
      }
    } catch (e) {
      logger.e(e);
      return VerificationResult(success: false, message: e.toString());
    }
  }

  Future<bool> detectSmile(InputImage inputImage) async {
    if (_faceDetector == null) {
      debugPrint('FaceDetector is not initialized.');
      return false;
    }

    try {
      final faces = await _faceDetector!.processImage(inputImage);

      debugPrint('Faces detected: ${faces.length}');
      if (faces.isNotEmpty) {
        final face = faces.first;
        final smilingProb = face.smilingProbability ?? 0;
        debugPrint(
          '😊 Smile probability: ${(smilingProb * 100).toStringAsFixed(1)}% (threshold: ${(VERIFICATION_THRESHOLD * 100).toStringAsFixed(0)}%)',
        );

        // Kirim debug info ke UI
        onDebugInfo?.call(faces.length, smilingProb);

        return smilingProb > VERIFICATION_THRESHOLD;
      } else {
        onDebugInfo?.call(0, 0);
        debugPrint(
          '😊 Smile probability: 0% (threshold: ${(VERIFICATION_THRESHOLD * 100).toStringAsFixed(0)}%)',
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error during face detection: $e');
      return false;
    }
  }

  void dispose() {
    _faceDetector?.close();
    _interpreter?.close();
  }
}
