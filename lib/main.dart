// lib/main.dart

import 'package:flutter/material.dart';
import 'package:Sentry/screens/kiosk/kiosk_dashboard.dart';
import 'package:Sentry/screens/Auth/login.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Sentry/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

// ── Liveness config ───────────────────────────────────────────────────────────
const double _eyeOpenThreshold   = 0.7;
const double _eyeClosedThreshold = 0.2;
const Duration _blinkTimeout     = Duration(seconds: 6);

enum _LivenessState { idle, waiting, blinkDone, failed }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://anzabsyngsmxgvnnbonn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFuemFic3luZ3NteGd2bm5ib25uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNDI5MjUsImV4cCI6MjA5MTYxODkyNX0.ngE64HEMTcndgOuRBkmjr0KEnQtF_gxxfvAJj2NL1lU',
  );

  await SyncService.instance.init();

  try {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeeded = prefs.getBool('seeded_from_supabase') ?? false;

    if (!alreadySeeded) {
      debugPrint('🌱 First launch — seeding from Supabase...');
      await DatabaseHelper.instance.seedFromSupabase();
      await prefs.setBool('seeded_from_supabase', true);
      debugPrint('✅ Seed complete.');
    } else {
      debugPrint('✅ Already seeded — skipping.');
    }
  } catch (e) {
    debugPrint('❌ Seed error: $e');
  }

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

// ── Admin Scan Dialog — with blink liveness ────────────────────────────────────

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

  // ── Liveness state ────────────────────────────────────────────────
  _LivenessState _livenessState = _LivenessState.idle;
  Timer? _blinkTimeoutTimer;
  int _blinkCountdown = 0;
  bool _eyesWereOpen = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: true,   // ← required for eye-open probability
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadAdmins();
    FaceRecognitionService.instance.initialize();
  }

  Future<void> _loadAdmins() async {
    final adminRows = await DatabaseHelper.instance.getAllAdmins();
    final admins = <EnrolledFace>[];
    for (final row in adminRows) {
      if (row['face_embedding'] == null) continue;
      try {
        admins.add(EnrolledFace(
          id: row['id'],
          name: row['full_name'],
          role: 'admin',
          embedding: FaceRecognitionService.decode(row['face_embedding']),
        ));
      } catch (e) {
        debugPrint('❌ Error decoding embedding: $e');
      }
    }
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
      debugPrint('❌ Camera init error: $e');
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
          final detected = faces.isNotEmpty;
          if (mounted) setState(() => _faceDetected = detected);

          if (detected) {
            _processLiveness(faces.first);
          } else {
            _resetLiveness();
          }
        }
      } catch (_) {}
      _isDetecting = false;
    });
    _isStreaming = true;
  }

  // ── Liveness helpers ──────────────────────────────────────────────

  void _processLiveness(Face face) {
    if (_livenessState == _LivenessState.blinkDone) return;
    if (_livenessState == _LivenessState.failed) return;

    final leftEye  = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null) return;

    final avgOpen = (leftEye + rightEye) / 2.0;

    if (_livenessState == _LivenessState.idle) {
      _startBlinkChallenge();
      return;
    }

    if (_livenessState == _LivenessState.waiting) {
      if (avgOpen >= _eyeOpenThreshold) {
        _eyesWereOpen = true;
      } else if (_eyesWereOpen && avgOpen <= _eyeClosedThreshold) {
        _onBlinkDetected();
      }
    }
  }

  void _startBlinkChallenge() {
    if (!mounted) return;
    setState(() {
      _livenessState  = _LivenessState.waiting;
      _eyesWereOpen   = false;
      _blinkCountdown = _blinkTimeout.inSeconds;
    });

    _blinkTimeoutTimer?.cancel();
    _blinkTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = _blinkCountdown - 1;
      if (remaining <= 0) {
        t.cancel();
        _blinkTimeoutTimer = null;
        _onBlinkTimeout();
      } else {
        setState(() => _blinkCountdown = remaining);
      }
    });
  }

  void _onBlinkDetected() {
    _blinkTimeoutTimer?.cancel();
    _blinkTimeoutTimer = null;
    if (!mounted) return;
    setState(() {
      _livenessState  = _LivenessState.blinkDone;
      _blinkCountdown = 0;
    });
  }

  void _onBlinkTimeout() {
    if (!mounted) return;
    setState(() {
      _livenessState  = _LivenessState.failed;
      _blinkCountdown = 0;
      _eyesWereOpen   = false;
    });
    _showError('Liveness check failed — move away and try again.');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _livenessState = _LivenessState.idle);
    });
  }

  void _resetLiveness() {
    _blinkTimeoutTimer?.cancel();
    _blinkTimeoutTimer = null;
    if (!mounted) return;
    if (_livenessState != _LivenessState.idle) {
      setState(() {
        _livenessState  = _LivenessState.idle;
        _blinkCountdown = 0;
        _eyesWereOpen   = false;
      });
    }
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
      _showError('No face detected.');
      return;
    }
    if (_livenessState != _LivenessState.blinkDone) {
      _showError('Please complete the blink check first.');
      return;
    }
    if (!_dbLoaded || _enrolledAdmins.isEmpty) {
      _showError('No admin face enrolled. Please enroll in account settings first.');
      return;
    }
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
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
      final faces = await FaceRecognitionService.instance.detectFaces(inputImage);
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

      if (!mounted) return;
      final navigator = Navigator.of(context);

      try {
        _cameraController?.dispose();
        _cameraController = null;
      } catch (_) {}

      navigator.pop();
      await Future.delayed(const Duration(milliseconds: 300));

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KioskDashboard()),
        (route) => false,
      );

    } catch (e) {
      debugPrint('❌ Scan error: $e');
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
    _resetLiveness();
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
    _blinkTimeoutTimer?.cancel();
    if (_isStreaming) {
      try { _cameraController?.stopImageStream(); } catch (_) {}
      _isStreaming = false;
    }
    _cameraController?.dispose();
    _cameraController = null;
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool livenessWaiting = _livenessState == _LivenessState.waiting;
    final bool livenessPassed  = _livenessState == _LivenessState.blinkDone;
    final bool livenessFailed  = _livenessState == _LivenessState.failed;

    final bool canScan = _faceDetected && livenessPassed && !_isProcessing;

    // Frame colour
    final Color frameColor = livenessFailed
        ? Colors.redAccent
        : livenessWaiting
            ? Colors.amber
            : livenessPassed
                ? Colors.green
                : Colors.white;

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
                        Text('Blink to confirm liveness, then scan',
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

                  // ── Live Camera Preview (aspect-ratio-correct) ───
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      // Use the camera's real aspect ratio so it never stretches.
                      // Falls back to portrait 3:4 while camera is initialising.
                      aspectRatio: _cameraReady && _cameraController != null
                          ? _cameraController!.value.aspectRatio
                          : 3 / 4,
                      child: _cameraReady && _cameraController != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController!),

                                // Corner frame painter (colour-reactive)
                                CustomPaint(
                                  painter: _CornerFramePainter(color: frameColor),
                                ),

                                // Blink challenge overlay
                                if (livenessWaiting)
                                  Container(
                                    color: Colors.black38,
                                    child: Center(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.remove_red_eye_outlined,
                                                color: Colors.amber,
                                                size: 44),
                                            const SizedBox(height: 8),
                                            const Text('Please BLINK',
                                                style: TextStyle(
                                                    color: Colors.amber,
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Text('$_blinkCountdown s remaining',
                                                style: const TextStyle(
                                                    color: Colors.amber,
                                                    fontSize: 13)),
                                          ]),
                                    ),
                                  ),

                                // Liveness failed overlay
                                if (livenessFailed)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.gpp_bad_rounded,
                                                color: Colors.redAccent,
                                                size: 44),
                                            SizedBox(height: 8),
                                            Text('Liveness Failed',
                                                style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            SizedBox(height: 4),
                                            Text('Move away & try again',
                                                style: TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 12)),
                                          ]),
                                    ),
                                  ),

                                // Liveness passed badge
                                if (livenessPassed && !_isProcessing)
                                  const Positioned(
                                    top: 10, right: 10,
                                    child: Icon(Icons.verified_rounded,
                                        color: Colors.green, size: 32),
                                  ),

                                // Processing overlay
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

                  // Status text
                  Text(
                    _isProcessing
                        ? 'Verifying...'
                        : livenessFailed
                            ? 'Blink check failed — move away & retry'
                            : livenessWaiting
                                ? 'Blink now! ($_blinkCountdown s)'
                                : livenessPassed
                                    ? '✓ Liveness confirmed — tap Scan'
                                    : _faceDetected
                                        ? 'Starting liveness check...'
                                        : 'Position your face within the frame',
                    style: TextStyle(
                      color: livenessFailed
                          ? Colors.redAccent
                          : livenessWaiting
                              ? Colors.orange
                              : livenessPassed
                                  ? Colors.green
                                  : const Color(0xFF8B9DC3),
                      fontSize: 13,
                      fontWeight: (livenessPassed || livenessWaiting ||
                              livenessFailed)
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
                      onPressed: canScan ? _handleScan : null,
                      icon: const Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 20),
                      label: const Text('Scan Admin Face',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: livenessPassed
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

// ── Corner Frame Painter ───────────────────────────────────────────────────────

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
    canvas.drawLine(Offset(size.width - c, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, c), paint);
    canvas.drawLine(Offset(0, size.height - c), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(c, size.height), paint);
    canvas.drawLine(Offset(size.width - c, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - c), paint);
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) => old.color != color;
}