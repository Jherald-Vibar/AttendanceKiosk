// lib/screens/kiosk/professor_scanner.dart

import 'package:Sentry/screens/kiosk/welcome.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';

// ── Liveness config (shared constants) ───────────────────────────────────────
const double _eyeOpenThreshold   = 0.7;
const double _eyeClosedThreshold = 0.2;
const Duration _blinkTimeout     = Duration(seconds: 6);

enum _LivenessState { idle, waiting, blinkDone, failed }

class FaceScanner extends StatefulWidget {
  final bool isKioskMode;
  const FaceScanner({super.key, this.isKioskMode = false});

  @override
  State<FaceScanner> createState() => _FaceScannerState();
}

class _FaceScannerState extends State<FaceScanner> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isProcessing = false;
  bool _isStreaming = false;

  List<EnrolledFace> _enrolledProfessors = [];
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
    _initializeCamera();
    _loadProfessors();
    FaceRecognitionService.instance.initialize();
  }

  Future<void> _loadProfessors() async {
    final rows = await DatabaseHelper.instance.getAllProfessors();
    final faces = <EnrolledFace>[];
    for (final row in rows) {
      if (row['face_embedding'] == null) continue;
      try {
        faces.add(EnrolledFace(
          id: row['id'],
          name: row['full_name'],
          role: 'professor',
          embedding: FaceRecognitionService.decode(row['face_embedding']),
        ));
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _enrolledProfessors = faces;
        _dbLoaded = true;
      });
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      frontCamera, ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
      _startImageStream();
    }
  }

  void _startImageStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isStreaming) return;
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting || _isProcessing) return;
      _isDetecting = true;
      try {
        final inputImage = _inputImageFromCameraImage(image);
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

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
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
      final allBytes = <int>[];
      for (final plane in image.planes) allBytes.addAll(plane.bytes);
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
        content: Text('No face detected. Please position your face in the frame.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_livenessState != _LivenessState.blinkDone) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please complete the blink check first.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!_dbLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Still loading. Please wait.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_enrolledProfessors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No professors enrolled yet.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

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
          .findBestMatch(embedding, _enrolledProfessors);
      if (match == null) {
        _showUnknownDialog();
        _restartStream();
        return;
      }

      final profData = await DatabaseHelper.instance.getProfessorById(match.id);
      final subjects = await DatabaseHelper.instance.getSubjectsByProfessor(match.id);
      if (profData == null) {
        _showError('Professor data not found.');
        _restartStream();
        return;
      }

      if (!mounted) return;
      final navigator = Navigator.of(context);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Face scanned successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));

      await Future.delayed(const Duration(milliseconds: 500));

      navigator.push(MaterialPageRoute(
        builder: (_) => Welcome(
          professor: profData,
          subjects: subjects,
        ),
      ));
    } catch (e) {
      debugPrint('Error during scan: $e');
      _showError('Error scanning face. Please try again.');
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
      _isStreaming   = false;
    });
    _resetLiveness();
    Future.delayed(const Duration(milliseconds: 300), _startImageStream);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showUnknownDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.no_accounts_rounded,
                  color: Colors.redAccent, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Not Recognized',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Face not found in the system.\nOnly registered professors can proceed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B9DC3), fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _blinkTimeoutTimer?.cancel();
    if (_isStreaming) {
      try { _cameraController?.stopImageStream(); } catch (_) {}
      _isStreaming = false;
    }
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final screenHeight    = MediaQuery.of(context).size.height;
    final frameSize       = screenHeight * 0.38;
    final verticalSpacing = screenHeight * 0.04;

    final bool livenessWaiting = _livenessState == _LivenessState.waiting;
    final bool livenessPassed  = _livenessState == _LivenessState.blinkDone;
    final bool livenessFailed  = _livenessState == _LivenessState.failed;

    // Frame corner colour
    final Color frameColor = livenessFailed
        ? Colors.redAccent
        : livenessWaiting
            ? Colors.amber
            : livenessPassed
                ? Colors.green
                : Colors.white;

    // Scan button enabled only when liveness passed
    final bool canScan = _faceDetected && livenessPassed && !_isProcessing;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: CameraPreview(_cameraController!)),
          Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.3))),

          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text('Identifying professor...',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // ── Title ────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 10),
                  child: Text('SENTRY',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2)),
                ),

                // ── Centre content ────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: verticalSpacing),
                          const Text('Scan your face',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(height: verticalSpacing),

                          // ── Face frame ────────────────────────────
                          SizedBox(
                            width: frameSize * 0.8,
                            height: frameSize,
                            child: Stack(children: [
                              Positioned(top: 0, left: 0,
                                  child: _buildCorner(true, true, frameColor)),
                              Positioned(top: 0, right: 0,
                                  child: _buildCorner(true, false, frameColor)),
                              Positioned(bottom: 0, left: 0,
                                  child: _buildCorner(false, true, frameColor)),
                              Positioned(bottom: 0, right: 0,
                                  child: _buildCorner(false, false, frameColor)),

                              // Liveness overlays
                              if (livenessWaiting)
                                Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.remove_red_eye_outlined,
                                        color: Colors.amber, size: 40),
                                    const SizedBox(height: 6),
                                    const Text('Please BLINK',
                                        style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('$_blinkCountdown s',
                                        style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                                ),

                              if (livenessFailed)
                                Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.gpp_bad_rounded,
                                        color: Colors.redAccent, size: 40),
                                    const SizedBox(height: 6),
                                    const Text('Liveness Failed',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    const Text('Move away & retry',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12)),
                                  ]),
                                ),

                              if (livenessPassed)
                                const Center(
                                  child: Icon(Icons.verified_rounded,
                                      color: Colors.green, size: 64),
                                ),
                            ]),
                          ),

                          SizedBox(height: verticalSpacing),

                          // Status text
                          Text(
                            livenessFailed
                                ? 'Blink check failed — move away & retry'
                                : livenessWaiting
                                    ? 'Blink now! ($_blinkCountdown s remaining)'
                                    : livenessPassed
                                        ? '✓ Liveness confirmed — tap Scan'
                                        : _faceDetected
                                            ? 'Starting liveness check...'
                                            : 'Find a good lighting spot',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: livenessFailed
                                  ? Colors.redAccent
                                  : livenessWaiting
                                      ? Colors.amber
                                      : livenessPassed
                                          ? Colors.green
                                          : Colors.white.withOpacity(0.8),
                              fontSize: 16,
                              fontWeight: (livenessFailed || livenessWaiting ||
                                      livenessPassed)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),

                          if (!livenessWaiting && !livenessPassed && !livenessFailed)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'You will be asked to blink to confirm liveness',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          SizedBox(height: verticalSpacing),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom buttons ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: canScan ? _handleScan : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: livenessPassed
                                ? Colors.green
                                : Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                Colors.black.withOpacity(0.5),
                            disabledForegroundColor:
                                Colors.white.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            elevation: 0,
                          ),
                          child: const Text('Scan',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            elevation: 0,
                          ),
                          child: const Text('Back',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft, Color color) {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: color, width: 5)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: color, width: 5)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: color, width: 5)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: color, width: 5)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft:     isTop && isLeft   ? const Radius.circular(20) : Radius.zero,
          topRight:    isTop && !isLeft  ? const Radius.circular(20) : Radius.zero,
          bottomLeft:  !isTop && isLeft  ? const Radius.circular(20) : Radius.zero,
          bottomRight: !isTop && !isLeft ? const Radius.circular(20) : Radius.zero,
        ),
      ),
    );
  }
}