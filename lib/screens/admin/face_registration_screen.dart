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
  bool _showingPreview = false;       // ← NEW: grid preview stage
  List<double>? _capturedEmbedding;

  // ── 4-shot state ──────────────────────────────────────────────────
  int _shotsTaken = 0;
  static const int _totalShots = 4;
  String _statusMessage = 'Align face inside the frame';

  // ── Shot preview paths ────────────────────────────────────────────
  final List<String> _shotPaths = [];  // ← NEW: stores file paths for preview

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
      if (_isDetecting || _faceCaptured || _showingPreview) return;
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

  // ── 4-shot capture ────────────────────────────────────────────────
  Future<void> _captureFace() async {
    if (_isProcessing || !_faceDetected) return;
    setState(() {
      _isProcessing = true;
      _shotsTaken = 0;
      _shotPaths.clear();
      _statusMessage = 'Starting capture...';
    });

    try {
      await _cameraController!.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 200));

      final List<List<double>> embeddings = [];

      for (int shot = 1; shot <= _totalShots; shot++) {
        if (!mounted) return;

        setState(() => _statusMessage = 'Taking shot $shot of $_totalShots...');

        final xFile = await _cameraController!.takePicture();
        _shotPaths.add(xFile.path); // ← store path for preview

        final inputImage = InputImage.fromFile(File(xFile.path));
        final allFaces =
            await FaceRecognitionService.instance.detectFaces(inputImage);

        if (allFaces.isEmpty) {
          _showError('Shot $shot: No face detected. Try again.');
          _resetCapture();
          return;
        }

        final primaryFace = allFaces.reduce((a, b) =>
            a.boundingBox.width > b.boundingBox.width ? a : b);

        final embedding = await FaceRecognitionService.instance
            .generateEmbeddingFromFile(xFile.path, primaryFace);

        if (embedding == null) {
          _showError('Shot $shot failed. Try better lighting.');
          _resetCapture();
          return;
        }

        embeddings.add(embedding);
        setState(() => _shotsTaken = shot);

        if (shot < _totalShots) {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      final averaged = _averageEmbeddings(embeddings);

      setState(() {
        _capturedEmbedding = averaged;
        _showingPreview = true;       // ← go to preview stage first
        _isProcessing = false;
        _statusMessage = 'Review your shots';
      });

    } catch (e) {
      _showError('Error: ${e.toString()}');
      _resetCapture();
    } finally {
      if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
      }
    }
  }

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

  // ── Called from preview: user approves ───────────────────────────
  void _confirmPreview() {
    setState(() {
      _showingPreview = false;
      _faceCaptured = true;
      _statusMessage = '✓ Face captured from $_totalShots shots!';
    });
    _successCtrl.forward(from: 0);
  }

  // ── Called from preview: user wants to retake ────────────────────
  void _retakeFromPreview() {
    setState(() {
      _showingPreview = false;
      _capturedEmbedding = null;
      _shotsTaken = 0;
      _shotPaths.clear();
      _statusMessage = 'Align face inside the frame';
      _faceDetected = false;
    });
    _restartStream();
  }

  // ── Save to SQLite (sync to Supabase via DatabaseHelper → SyncService) ──
  Future<void> _saveFace() async {
    if (_capturedEmbedding == null) return;
    setState(() => _isProcessing = true);

    try {
      final embStr = FaceRecognitionService.encode(_capturedEmbedding!);

      // DatabaseHelper.save*FaceEmbedding writes locally AND calls
      // SyncService.pushFaceEmbedding, which is offline-queued automatically.
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
              '${widget.personName} — Face ID saved & synced to cloud!'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Save failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _retake() {
    setState(() {
      _faceCaptured = false;
      _capturedEmbedding = null;
      _shotsTaken = 0;
      _shotPaths.clear();
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
      _shotPaths.clear();
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

  // ═════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview (live feed) ──────────────────────────
          if (_cameraReady && !_faceCaptured && !_showingPreview)
            Positioned.fill(child: CameraPreview(_cameraController!)),

          // ── Preview screen (4-shot grid) ────────────────────────
          if (_showingPreview)
            Positioned.fill(child: _buildPreviewScreen()),

          // ── Success screen ──────────────────────────────────────
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
                      child:
                          Icon(Icons.check_rounded, color: _accent, size: 70),
                    ),
                  ),
                ),
              ),
            ),

          // ── Dark overlay on live camera ─────────────────────────
          if (!_faceCaptured && !_showingPreview)
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),

          // ── UI chrome (hidden while showing preview) ────────────
          if (!_showingPreview)
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildFaceFrame()),
                  _buildButtons(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
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
    );
  }

  // ── Face frame + status + dots ────────────────────────────────────
  Widget _buildFaceFrame() {
    return Column(
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
                          color: _accent.withOpacity(0.7), fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),

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

        if (_isProcessing && _shotsTaken == 0)
          const Text('Preparing...',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  // ── Bottom buttons ────────────────────────────────────────────────
  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
      child: _faceCaptured
          ? Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: _accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: _accent, size: 16),
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
                    icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: _isProcessing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Sync Face ID',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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
                    : const Icon(Icons.camera_alt_rounded, size: 22),
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
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ── NEW: 4-shot preview screen ───────────────────────────────────
  // ══════════════════════════════════════════════════════════════════
  Widget _buildPreviewScreen() {
    return Container(
      color: const Color(0xFF0A0E1A),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _retakeFromPreview,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white10,
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
                      const Text('Preview Shots',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text('Check all shots look clear',
                          style: TextStyle(
                              color: _accent.withOpacity(0.8),
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Instruction banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: _accent, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Make sure your face is clearly visible in all 4 shots. '
                        'Blurry or obstructed shots may reduce accuracy.',
                        style:
                            TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2×2 photo grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _shotPaths.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3 / 4,
                  ),
                  itemBuilder: (context, index) {
                    return _ShotTile(
                      index: index,
                      path: _shotPaths[index],
                      accent: _accent,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quality badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: _accent, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      'Embedding averaged from $_totalShots shots',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Confirm → proceed to save
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _confirmPreview,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Looks Good — Use These',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Retake
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _retakeFromPreview,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Color(0xFF8B9DC3), size: 18),
                      label: const Text('Retake All Shots',
                          style: TextStyle(
                              color: Color(0xFF8B9DC3),
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
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

// ── Shot tile widget ──────────────────────────────────────────────────
class _ShotTile extends StatelessWidget {
  final int index;
  final String path;
  final Color accent;

  const _ShotTile({
    required this.index,
    required this.path,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          Image.file(File(path), fit: BoxFit.cover),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Shot label badge
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Shot ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Corner frame decoration
          Positioned(
            top: 6, right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.check_rounded, color: accent, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tips widget ───────────────────────────────────────────────────────
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

// ── Corner frame painter ──────────────────────────────────────────────
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
  bool shouldRepaint(_FramePainter old) => old.color != color;
}