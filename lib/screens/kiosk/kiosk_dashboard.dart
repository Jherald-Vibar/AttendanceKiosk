// lib/screens/kiosk/kiosk_dashboard.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:Sentry/screens/kiosk/professor_scanner.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';
import 'package:Sentry/main.dart' show HomePage;

class KioskDashboard extends StatefulWidget {
  const KioskDashboard({super.key});

  @override
  State<KioskDashboard> createState() => _KioskDashboardState();
}

class _KioskDashboardState extends State<KioskDashboard>
    with WidgetsBindingObserver {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockScreen();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _lockScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _lockScreen();
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showExitKioskDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ExitKioskDialog(
        onVerified: () async {
          // Restore system UI and orientations before leaving kiosk
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          // KioskDashboard IS the root (pushAndRemoveUntil cleared the stack
          // when entering kiosk), so we must push HomePage and remove all.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr     = DateFormat('hh:mm').format(_now);
    final secondsStr  = DateFormat('ss').format(_now);
    final amPm        = DateFormat('a').format(_now);
    final dateStr     = DateFormat('EEEE, MMMM d, yyyy').format(_now);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── Top bar ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Color(0xFF00D4FF), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('SENTRY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              fontStyle: FontStyle.italic,
                            )),
                      ],
                    ),

                    // Right: kiosk badge + exit button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF00D4FF).withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.desktop_windows_rounded,
                                  color: Color(0xFF00D4FF), size: 13),
                              SizedBox(width: 6),
                              Text('KIOSK MODE',
                                  style: TextStyle(
                                    color: Color(0xFF00D4FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  )),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 🔒 Exit kiosk — admin face required
                        GestureDetector(
                          onTap: _showExitKioskDialog,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.exit_to_app_rounded,
                                color: Colors.redAccent, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // ── Clock ────────────────────────────────────────────
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(timeStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 80,
                              fontWeight: FontWeight.w200,
                              letterSpacing: -2,
                            )),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(':$secondsStr',
                              style: const TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                              )),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16, left: 8),
                          child: Text(amPm,
                              style: const TextStyle(
                                color: Color(0xFF8B9DC3),
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                              )),
                        ),
                      ],
                    ),
                    Text(dateStr,
                        style: const TextStyle(
                          color: Color(0xFF8B9DC3),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        )),
                  ],
                ),

                const Spacer(),

                // ── Divider ──────────────────────────────────────────
                Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFF1E2D45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Info card ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E2D45)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.how_to_reg_rounded,
                            color: Color(0xFF00E676), size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Attendance System',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                )),
                            SizedBox(height: 2),
                            Text(
                              'Professor scans first to start class attendance',
                              style: TextStyle(
                                color: Color(0xFF8B9DC3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Start Attendance button ───────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FaceScanner(isKioskMode: true),
                      ),
                    ),
                    icon: const Icon(Icons.face_retouching_natural_rounded,
                        size: 22),
                    label: const Text('Start Attendance',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: const Color(0xFF0A0E1A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Footer ───────────────────────────────────────────
                Text(
                  'Facial Recognition Attendance • Secure & Automated',
                  style: TextStyle(
                    color: const Color(0xFF8B9DC3).withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Exit Kiosk Dialog  —  matches the Enter Kiosk dialog style from main.dart
// ══════════════════════════════════════════════════════════════════════════════

class _ExitKioskDialog extends StatefulWidget {
  final VoidCallback onVerified;
  const _ExitKioskDialog({required this.onVerified});

  @override
  State<_ExitKioskDialog> createState() => _ExitKioskDialogState();
}

class _ExitKioskDialogState extends State<_ExitKioskDialog> {
  CameraController? _cameraController;
  bool _cameraReady    = false;
  bool _faceDetected   = false;
  bool _isDetecting    = false;
  bool _isProcessing   = false;
  bool _isStreaming     = false;

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
    _initCamera();
    _loadAdmins();
    FaceRecognitionService.instance.initialize();
  }

  Future<void> _loadAdmins() async {
    final rows = await DatabaseHelper.instance.getAllAdmins();
    final admins = <EnrolledFace>[];
    for (final row in rows) {
      if (row['face_embedding'] == null) continue;
      try {
        admins.add(EnrolledFace(
          id: row['id'],
          name: row['full_name'],
          role: 'admin',
          embedding: FaceRecognitionService.decode(row['face_embedding']),
        ));
      } catch (_) {}
    }
    if (mounted) setState(() { _enrolledAdmins = admins; _dbLoaded = true; });
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
    } catch (_) {}
  }

  void _startStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isStreaming) return;
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting || _isProcessing) return;
      _isDetecting = true;
      try {
        final inp = _toInputImage(image);
        if (inp != null) {
          final faces = await _faceDetector.processImage(inp);
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
    } catch (_) { return null; }
  }

  Future<void> _stopStream() async {
    if (!_isStreaming) return;
    try { await _cameraController?.stopImageStream(); } catch (_) {}
    _isStreaming = false;
  }

  Future<void> _handleScan() async {
    if (!_faceDetected) {
      _showErr('No face detected.');
      return;
    }
    if (!_dbLoaded || _enrolledAdmins.isEmpty) {
      _showErr('No admin face enrolled. Enroll in account settings first.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await _stopStream();
      await Future.delayed(const Duration(milliseconds: 200));

      final xFile = await _cameraController!.takePicture();
      final faces = await FaceRecognitionService.instance
          .detectFaces(InputImage.fromFile(File(xFile.path)));
      if (faces.isEmpty) {
        _showErr('No face on capture. Try again.');
        _restartStream();
        return;
      }

      final embedding = await FaceRecognitionService.instance
          .generateEmbeddingFromFile(xFile.path, faces.first);
      if (embedding == null) {
        _showErr('Could not read face. Try better lighting.');
        _restartStream();
        return;
      }

      final match = FaceRecognitionService.instance
          .findBestMatch(embedding, _enrolledAdmins);
      if (match == null) {
        _showErr('Not recognized as admin. Access denied.');
        _restartStream();
        return;
      }

      // ✅ Verified — dispose camera then close dialog and exit kiosk
      try { await _cameraController?.dispose(); _cameraController = null; } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context); // close dialog
      widget.onVerified();    // restore UI + popUntil root

    } catch (_) {
      _showErr('Error scanning. Please try again.');
      _restartStream();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _restartStream() {
    if (!mounted) return;
    setState(() { _isStreaming = false; _faceDetected = false; });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startStream();
    });
  }

  void _showErr(String msg) {
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
      try { _cameraController?.stopImageStream(); } catch (_) {}
    }
    _cameraController?.dispose();
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

            // ── Header — dark, matches Enter Kiosk style ─────────
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
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.exit_to_app_rounded,
                        color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exit Kiosk Mode',
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

            // ── Body ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Scan your face to exit Kiosk Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1C2536),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Camera preview with corner frame
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
                                    strokeWidth: 2),
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

                  // Scan button
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

// ── Corner Frame Painter (same as main.dart) ──────────────────────────────

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