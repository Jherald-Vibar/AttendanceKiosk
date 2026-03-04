// lib/services/face_recognition_service.dart

import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  static final FaceRecognitionService instance = FaceRecognitionService._();
  FaceRecognitionService._();

  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // ── Tune this threshold: lower = stricter, higher = lenient ──────────
  static const double THRESHOLD = 0.8;
  static const int INPUT_SIZE = 160;

  // ── Initialize ML Kit + FaceNet ───────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
      ),
    );

    _interpreter = await Interpreter.fromAsset('assets/models/facenet.tflite');
    _isInitialized = true;
  }

  void dispose() {
    _faceDetector?.close();
    _interpreter?.close();
    _isInitialized = false;
  }

  // ── Detect faces from InputImage ──────────────────────────────────────
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    await initialize();
    return _faceDetector!.processImage(inputImage);
  }

  // ── Build InputImage from CameraImage (live stream) ───────────────────
  InputImage? buildInputImageFromCamera(
      CameraImage image, CameraDescription camera) {
    try {
      InputImageRotation rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotation.rotation0deg;
      } else {
        rotation = camera.lensDirection == CameraLensDirection.front
            ? InputImageRotation.rotation270deg
            : InputImageRotation.rotation90deg;
      }

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null || image.planes.isEmpty) return null;

      final bytes = <int>[];
      for (final p in image.planes) bytes.addAll(p.bytes);

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Generate 128-D embedding from image file + detected face ──────────
  Future<List<double>?> generateEmbeddingFromFile(
      String imagePath, Face face) async {
    await initialize();
    try {
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;
      return _extractEmbedding(original, face);
    } catch (_) {
      return null;
    }
  }

  // ── Generate embedding from raw img.Image + face ──────────────────────
  Future<List<double>?> generateEmbedding(img.Image original, Face face) async {
    await initialize();
    return _extractEmbedding(original, face);
  }

  List<double>? _extractEmbedding(img.Image original, Face face) {
    try {
      final rect = face.boundingBox;
      const padding = 20;

      final x = (rect.left.toInt() - padding).clamp(0, original.width - 1);
      final y = (rect.top.toInt() - padding).clamp(0, original.height - 1);
      final w = (rect.width.toInt() + padding * 2)
          .clamp(1, original.width - x);
      final h = (rect.height.toInt() + padding * 2)
          .clamp(1, original.height - y);

      final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
      final resized =
          img.copyResize(cropped, width: INPUT_SIZE, height: INPUT_SIZE);

      final input = _toInputTensor(resized);
      final output = List.filled(128, 0.0).reshape([1, 128]);
      _interpreter!.run(input, output);

      return List<double>.from(output[0]);
    } catch (_) {
      return null;
    }
  }

  List<List<List<List<double>>>> _toInputTensor(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        INPUT_SIZE,
        (y) => List.generate(
          INPUT_SIZE,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r.toDouble() - 127.5) / 128.0,
              (pixel.g.toDouble() - 127.5) / 128.0,
              (pixel.b.toDouble() - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );
  }

  // ── Match embedding against enrolled list ─────────────────────────────
  SentryMatch? findBestMatch(
      List<double> query, List<EnrolledFace> enrolled) {
    if (enrolled.isEmpty) return null;

    double minDist = double.infinity;
    EnrolledFace? best;

    for (final e in enrolled) {
      final d = _euclidean(query, e.embedding);
      if (d < minDist) {
        minDist = d;
        best = e;
      }
    }

    if (minDist < THRESHOLD && best != null) {
      return SentryMatch(
        id: best.id,
        name: best.name,
        role: best.role,
        sectionName: best.sectionName,
        distance: minDist,
        confidence: ((1 - (minDist / THRESHOLD)) * 100).clamp(0.0, 100.0),
      );
    }
    return null;
  }

  double _euclidean(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]) * (a[i] - b[i]);
    }
    return sqrt(sum);
  }

  // ── Serialization ─────────────────────────────────────────────────────
  static String encode(List<double> e) => e.join(',');
  static List<double> decode(String s) =>
      s.split(',').map(double.parse).toList();
}

// ── Data Models ───────────────────────────────────────────────────────────

class EnrolledFace {
  final int id;
  final String name;
  final String role; // 'student' | 'professor'
  final String? sectionName;
  final List<double> embedding;

  EnrolledFace({
    required this.id,
    required this.name,
    required this.role,
    this.sectionName,
    required this.embedding,
  });
}

class SentryMatch {
  final int id;
  final String name;
  final String role;
  final String? sectionName;
  final double distance;
  final double confidence;

  SentryMatch({
    required this.id,
    required this.name,
    required this.role,
    this.sectionName,
    required this.distance,
    required this.confidence,
  });
}