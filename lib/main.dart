// lib/main.dart

import 'package:flutter/material.dart';
import 'package:Sentry/screens/kiosk/professor_scanner.dart';
import 'package:Sentry/screens/Auth/login.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentry',
      theme: ThemeData(primarySwatch: Colors.lightBlue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _showKioskPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _AdminScanDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background Gradient ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF82D8ff), Color(0xffffffff)],
              ),
            ),
          ),

          // ── Kiosk Mode Button (Top Right) ────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _showKioskPopup(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.black.withOpacity(0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.desktop_windows_rounded,
                                size: 16, color: Color(0xFF1C2536)),
                            SizedBox(width: 6),
                            Text('Kiosk Mode',
                                style: TextStyle(
                                  color: Color(0xFF1C2536),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content ─────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 200),
                const SizedBox(height: 30),
                const Text('Facial Recognition System',
                    style: TextStyle(fontFamily: 'sans', fontSize: 18)),
                const Text('Secure Attendance Tracking',
                    style: TextStyle(fontFamily: 'sans', fontSize: 14)),
                const SizedBox(height: 70),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin Scan Dialog ──────────────────────────────────────────────────

class _AdminScanDialog extends StatefulWidget {
  const _AdminScanDialog();

  @override
  State<_AdminScanDialog> createState() => _AdminScanDialogState();
}

class _AdminScanDialogState extends State<_AdminScanDialog> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _faceDetected = false;
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isStreaming = false;

  List<EnrolledFace> _enrolledAdmins = [];
  bool _dbLoaded = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    print('🎬 _AdminScanDialogState initState called');
    _initCamera();
    _loadAdmins();
    FaceRecognitionService.instance.initialize();
  }

  Future<void> _loadAdmins() async {
    print('🚀 _loadAdmins called');
    final adminRows = await DatabaseHelper.instance.getAllAdmins();
    print('🔐 Admin rows found: ${adminRows.length}');
    final admins = <EnrolledFace>[];
    for (final row in adminRows) {
      print('👤 Admin: ${row['full_name']}, has embedding: ${row['face_embedding'] != null}');
      if (row['face_embedding'] == null) continue;
      try {
        admins.add(EnrolledFace(
          id: row['id'],
          name: row['full_name'],
          role: 'admin',
          embedding: FaceRecognitionService.decode(row['face_embedding']),
        ));
      } catch (e) {
        print('❌ Error decoding embedding: $e');
      }
    }
    print('✅ Admins with embeddings loaded: ${admins.length}');
    if (mounted) {
      setState(() {
        _enrolledAdmins = admins;
        _dbLoaded = true;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front, ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _cameraReady = true);
        _startStream();
      }
    } catch (e) {
      print('❌ Camera init error: $e');
    }
  }

  void _startStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isStreaming) return;
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting || _isProcessing) return;
      _isDetecting = true;
      try {
        final inputImage = _toInputImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          if (mounted) setState(() => _faceDetected = faces.isNotEmpty);
        }
      } catch (_) {}
      _isDetecting = false;
    });
    _isStreaming = true;
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      final rotation = Platform.isIOS
          ? InputImageRotation.rotation0deg
          : camera.lensDirection == CameraLensDirection.front
              ? InputImageRotation.rotation270deg
              : InputImageRotation.rotation90deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null || image.planes.isEmpty) return null;
      final allBytes = <int>[];
      for (final p in image.planes) allBytes.addAll(p.bytes);
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(allBytes),
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

  Future<void> _stopStream() async {
    if (!_isStreaming) return;
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    _isStreaming = false;
  }

  void _handleScan() async {
    if (!_faceDetected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No face detected.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!_dbLoaded || _enrolledAdmins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No admin face enrolled. Please enroll in account settings first.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      _showError('Camera not ready. Please wait.');
      return;
    }
    if (!mounted) return;

    setState(() => _isProcessing = true);

    try {
      await _stopStream();
      await Future.delayed(const Duration(milliseconds: 200));

      final xFile = await _cameraController!.takePicture();

      final inputImage = InputImage.fromFile(File(xFile.path));
      final faces =
          await FaceRecognitionService.instance.detectFaces(inputImage);
      if (faces.isEmpty) {
        _showError('No face on capture. Try again.');
        _restartStream();
        return;
      }

      final embedding = await FaceRecognitionService.instance
          .generateEmbeddingFromFile(xFile.path, faces.first);
      if (embedding == null) {
        _showError('Could not read face. Try better lighting.');
        _restartStream();
        return;
      }

      final match = FaceRecognitionService.instance
          .findBestMatch(embedding, _enrolledAdmins);

      if (match == null) {
        _showError('Not recognized as admin. Access denied.');
        _restartStream();
        return;
      }

      // ── Admin verified ───────────────────────────────────────────
      if (!mounted) return;

      // Capture navigator BEFORE pop so it stays valid after dialog dismissal
      final navigator = Navigator.of(context);

      try {
        _cameraController?.dispose();
        _cameraController = null;
      } catch (_) {}

      navigator.pop();
      await Future.delayed(const Duration(milliseconds: 300));
      navigator.push(MaterialPageRoute(
        builder: (_) => const FaceScanner(isKioskMode: true),
      ));

    } catch (e) {
      print('❌ Scan error: $e');
      if (mounted) _showError('Error scanning. Please try again.');
      _restartStream();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _restartStream() {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _faceDetected = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startStream();
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    if (_isStreaming) {
      try {
        _cameraController?.stopImageStream();
      } catch (_) {}
      _isStreaming = false;
    }
    _cameraController?.dispose();
    _cameraController = null;
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0E1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Color(0xFF00D4FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kiosk Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            )),
                        Text('Admin verification required',
                            style: TextStyle(
                              color: Color(0xFF8B9DC3),
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFF8B9DC3), size: 20),
                  ),
                ],
              ),
            ),

            // ── Camera + Scan UI ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Scan your face to enter Kiosk Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1C2536),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Live Camera Preview ──────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 220,
                      child: _cameraReady && _cameraController != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController!),
                                CustomPaint(
                                  painter: _CornerFramePainter(
                                    color: _faceDetected
                                        ? Colors.green
                                        : Colors.white,
                                  ),
                                ),
                                if (_faceDetected)
                                  const Center(
                                    child: Icon(Icons.check_circle,
                                        color: Colors.green, size: 48),
                                  ),
                                if (_isProcessing)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                          SizedBox(height: 10),
                                          Text('Verifying admin...',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Container(
                              color: const Color(0xFF0A0E1A),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00D4FF),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _faceDetected
                        ? 'Face detected! Ready to scan.'
                        : 'Position your face within the frame',
                    style: TextStyle(
                      color: _faceDetected
                          ? Colors.green
                          : const Color(0xFF8B9DC3),
                      fontSize: 13,
                      fontWeight: _faceDetected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Scan Button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_faceDetected && !_isProcessing)
                          ? _handleScan
                          : null,
                      icon: const Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 20),
                      label: const Text('Scan Admin Face',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _faceDetected
                            ? Colors.green
                            : const Color(0xFF0A0E1A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.withOpacity(0.3),
                        disabledForegroundColor: Colors.white54,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF8B9DC3),
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Corner Frame Painter ───────────────────────────────────────────────

class _CornerFramePainter extends CustomPainter {
  final Color color;
  _CornerFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const c = 20.0;
    canvas.drawLine(const Offset(0, c), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(c, 0), paint);
    canvas.drawLine(
        Offset(size.width - c, 0), Offset(size.width, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, c), paint);
    canvas.drawLine(
        Offset(0, size.height - c), Offset(0, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(c, size.height), paint);
    canvas.drawLine(Offset(size.width - c, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - c), paint);
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) => old.color != color;
}