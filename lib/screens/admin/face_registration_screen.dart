// lib/screens/admin/face_registration_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';

enum FaceRegType { admin, professor, student }

class FaceRegistrationScreen extends StatefulWidget {
  final int personId;
  final String personName;
  final FaceRegType type;

  const FaceRegistrationScreen({
    super.key,
    required this.personId,
    required this.personName,
    required this.type,
  });

  @override
  State<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _isProcessing = false;
  bool _faceCaptured = false;
  bool _faceDetected = false;
  bool _isDetecting = false;
  List<double>? _capturedEmbedding;

  // ── 4-shot state ──────────────────────────────────────────────────
  int _shotsTaken = 0;
  static const int _totalShots = 4;
  String _statusMessage = 'Align face inside the frame';

  late AnimationController _successCtrl;

  Color get _accent => switch (widget.type) {
        FaceRegType.admin => const Color(0xFFFF6B6B),
        FaceRegType.professor => const Color(0xFF00D4FF),
        FaceRegType.student => const Color(0xFFB06EFF),
      };

  String get _typeLabel => switch (widget.type) {
        FaceRegType.admin => 'Admin',
        FaceRegType.professor => 'Professor',
        FaceRegType.student => 'Student',
      };

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _initCamera();
    FaceRecognitionService.instance.initialize();
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      front, ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _cameraController!.initialize();
    if (mounted) {
      setState(() => _cameraReady = true);
      _startLiveDetection();
    }
  }

  void _startLiveDetection() {
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting || _faceCaptured) return;
      _isDetecting = true;
      try {
        final input = FaceRecognitionService.instance
            .buildInputImageFromCamera(
                image, _cameraController!.description);
        if (input != null) {
          final faces =
              await FaceRecognitionService.instance.detectFaces(input);
          if (mounted) setState(() => _faceDetected = faces.isNotEmpty);
        }
      } catch (_) {}
      _isDetecting = false;
    });
  }

  // ── 4-shot capture — uses largest face instead of rejecting ───────
  Future<void> _captureFace() async {
    if (_isProcessing || !_faceDetected) return;
    setState(() {
      _isProcessing = true;
      _shotsTaken = 0;
      _statusMessage = 'Starting capture...';
    });

    try {
      await _cameraController!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 200));

      final List<List<double>> embeddings = [];

      for (int shot = 1; shot <= _totalShots; shot++) {
        if (!mounted) return;

        setState(() => _statusMessage = 'Taking shot $shot of $_totalShots...');

        // Take photo
        final xFile = await _cameraController!.takePicture();

        // Detect faces
        final inputImage = InputImage.fromFile(File(xFile.path));
        final allFaces =
            await FaceRecognitionService.instance.detectFaces(inputImage);

        if (allFaces.isEmpty) {
          _showError('Shot $shot: No face detected. Try again.');
          _resetCapture();
          return;
        }

        // ── FIX: pick the largest face instead of rejecting ──────────
        final primaryFace = allFaces.reduce((a, b) =>
            a.boundingBox.width > b.boundingBox.width ? a : b);

        // Generate embedding for this shot using only the primary face
        final embedding = await FaceRecognitionService.instance
            .generateEmbeddingFromFile(xFile.path, primaryFace);

        if (embedding == null) {
          _showError('Shot $shot failed. Try better lighting.');
          _resetCapture();
          return;
        }

        embeddings.add(embedding);
        setState(() => _shotsTaken = shot);

        // Short pause between shots (except after last)
        if (shot < _totalShots) {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      // ── Average all 4 embeddings ──────────────────────────────────
      final averaged = _averageEmbeddings(embeddings);

      setState(() {
        _capturedEmbedding = averaged;
        _faceCaptured = true;
        _statusMessage = '✓ Face captured from $_totalShots shots!';
      });
      _successCtrl.forward(from: 0);

    } catch (e) {
      _showError('Error: ${e.toString()}');
      _resetCapture();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Average N embeddings into one — reduces noise from single-shot capture
  List<double> _averageEmbeddings(List<List<double>> embeddings) {
    final length = embeddings.first.length;
    final averaged = List<double>.filled(length, 0.0);
    for (final emb in embeddings) {
      for (int i = 0; i < length; i++) {
        averaged[i] += emb[i];
      }
    }
    for (int i = 0; i < length; i++) {
      averaged[i] /= embeddings.length;
    }
    return averaged;
  }

  Future<void> _saveFace() async {
    if (_capturedEmbedding == null) return;
    setState(() => _isProcessing = true);

    try {
      final embStr = FaceRecognitionService.encode(_capturedEmbedding!);

      switch (widget.type) {
        case FaceRegType.admin:
          await DatabaseHelper.instance
              .saveAdminFaceEmbedding(widget.personId, embStr);
          break;
        case FaceRegType.professor:
          await DatabaseHelper.instance
              .saveProfessorFaceEmbedding(widget.personId, embStr);
          break;
        case FaceRegType.student:
          await DatabaseHelper.instance
              .saveStudentFaceEmbedding(widget.personId, embStr);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.personName} — Face ID saved from $_totalShots shots!'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context);
      }
    } catch (_) {
      _showError('Save failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _retake() {
    setState(() {
      _faceCaptured = false;
      _capturedEmbedding = null;
      _shotsTaken = 0;
      _statusMessage = 'Align face inside the frame';
    });
    _successCtrl.reset();
    _restartStream();
  }

  void _resetCapture() {
    setState(() {
      _shotsTaken = 0;
      _isProcessing = false;
      _faceDetected = false;
      _statusMessage = 'Align face inside the frame';
    });
    _startLiveDetection();
  }

  void _restartStream() {
    setState(() {
      _faceDetected = false;
      _isProcessing = false;
    });
    _startLiveDetection();
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_cameraReady && !_faceCaptured)
            Positioned.fill(child: CameraPreview(_cameraController!)),

          // Success screen
          if (_faceCaptured)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0A0E1A),
                child: Center(
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                        parent: _successCtrl, curve: Curves.elasticOut),
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent, width: 3),
                      ),
                      child: Icon(Icons.check_rounded, color: _accent, size: 70),
                    ),
                  ),
                ),
              ),
            ),

          if (!_faceCaptured)
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Register Face — $_typeLabel',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(widget.personName,
                              style: TextStyle(color: _accent, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Face frame + status
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 220, height: 280,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(120),
                              border: Border.all(
                                color: _faceCaptured
                                    ? _accent
                                    : _faceDetected
                                        ? const Color(0xFF00E676)
                                        : Colors.white24,
                                width: 2.5,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260, height: 320,
                            child: CustomPaint(
                              painter: _FramePainter(
                                color: _faceCaptured
                                    ? _accent
                                    : _faceDetected
                                        ? const Color(0xFF00E676)
                                        : Colors.white38,
                              ),
                            ),
                          ),

                          // Shot progress overlay while capturing
                          if (_isProcessing && _shotsTaken > 0)
                            Container(
                              width: 220, height: 280,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(120),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$_shotsTaken / $_totalShots',
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'shots taken',
                                    style: TextStyle(
                                        color: _accent.withOpacity(0.7),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Status message
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusMessage,
                          key: ValueKey(_statusMessage),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _faceCaptured
                                ? _accent
                                : _faceDetected
                                    ? const Color(0xFF00E676)
                                    : Colors.white60,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Shot progress dots
                      if (!_faceCaptured)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_totalShots, (i) {
                            final done = i < _shotsTaken;
                            final active = i == _shotsTaken && _isProcessing;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: active ? 18 : 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: done
                                    ? _accent
                                    : active
                                        ? _accent.withOpacity(0.6)
                                        : Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          }),
                        ),

                      const SizedBox(height: 12),

                      // Tips (only before capture starts)
                      if (!_faceCaptured && !_isProcessing)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Tip(icon: Icons.wb_sunny_outlined, text: 'Good light'),
                            SizedBox(width: 16),
                            _Tip(icon: Icons.face_outlined, text: 'Face forward'),
                            SizedBox(width: 16),
                            _Tip(icon: Icons.remove_red_eye_outlined, text: 'Eyes open'),
                          ],
                        ),

                      // Processing label
                      if (_isProcessing && _shotsTaken == 0)
                        const Text('Preparing...',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: _faceCaptured
                      ? Column(
                          children: [
                            // Quality indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _accent.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: _accent, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Averaged from $_totalShots shots — high quality',
                                    style: TextStyle(
                                        color: _accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _saveFace,
                                icon: const Icon(Icons.save_rounded, size: 20),
                                label: _isProcessing
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Text('Save Face ID',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _retake,
                              icon: const Icon(Icons.refresh_rounded,
                                  color: Color(0xFF8B9DC3), size: 18),
                              label: const Text('Retake',
                                  style: TextStyle(
                                      color: Color(0xFF8B9DC3),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton.icon(
                            onPressed: (_faceDetected && !_isProcessing)
                                ? _captureFace
                                : null,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 22),
                            label: Text(
                              _isProcessing
                                  ? _statusMessage
                                  : _faceDetected
                                      ? 'Capture Face (4 shots)'
                                      : 'Waiting for face...',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _faceDetected ? _accent : Colors.white12,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white38,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white38, size: 14),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ]);
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  const _FramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const c = 28.0;
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
  bool shouldRepaint(_FramePainter old) => old.color != color;
}