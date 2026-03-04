// lib/screens/kiosk/student_scanner.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';

class StudentScanner extends StatefulWidget {
  final int subjectSectionId;
  final String sectionName;

  const StudentScanner({
    super.key,
    required this.subjectSectionId,
    required this.sectionName,
  });

  @override
  State<StudentScanner> createState() => _StudentScannerState();
}

class _StudentScannerState extends State<StudentScanner> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isTimeIn = true;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isProcessing = false;

  // ── Enrolled faces loaded from SQLite ─────────────────────────────────
  List<EnrolledFace> _enrolledFaces = [];
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
    _initializeCamera();
    _loadEnrolledFaces();
    FaceRecognitionService.instance.initialize(); // warms up FaceNet
  }

  // ── Load enrolled faces from DB ──────────────────────────────────────
  Future<void> _loadEnrolledFaces() async {
    final rows = await DatabaseHelper.instance.getAllEnrolledFaces();
    final faces = <EnrolledFace>[];
    for (final row in rows) {
      if (row['face_embedding'] == null) continue;
      try {
        faces.add(EnrolledFace(
          id: row['id'],
          name: row['full_name'],
          role: 'student',
          sectionName: row['section_name'],
          embedding: FaceRecognitionService.decode(row['face_embedding']),
        ));
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _enrolledFaces = faces;
        _dbLoaded = true;
      });
    }
  }

  // ── Camera init ──────────────────────────────────────────────────────
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high, // high for better FaceNet accuracy
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  // ── Live face detection (frame indicator only) ───────────────────────
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting || _isProcessing) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) { _isDetecting = false; return; }

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() => _faceDetected = faces.isNotEmpty);
      }
    } catch (e) {
      print('Error detecting face: $e');
    }

    _isDetecting = false;
  }

  InputImage? _convertCameraImage(CameraImage cameraImage) {
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

      final format =
          InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null || cameraImage.planes.isEmpty) return null;

      final allBytes = <int>[];
      for (final plane in cameraImage.planes) {
        allBytes.addAll(plane.bytes);
      }

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(allBytes),
        metadata: InputImageMetadata(
          size: Size(
              cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

  // ── MAIN SCAN: photo → FaceNet → match → attendance ──────────────────
  Future<void> _captureAndProcessFace() async {
    if (!_faceDetected) {
      _showMessage('No face detected. Position your face in the frame.');
      return;
    }
    if (!_dbLoaded || _enrolledFaces.isEmpty) {
      _showMessage('No enrolled students yet. Register faces first.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Stop stream + take still photo
      await _cameraController?.stopImageStream();
      final XFile xFile = await _cameraController!.takePicture();

      // 2. Detect face on still photo
      final inputImage = InputImage.fromFile(File(xFile.path));
      final faces =
          await FaceRecognitionService.instance.detectFaces(inputImage);

      if (faces.isEmpty) {
        _showMessage('No face detected on capture. Try again.');
        _restartStream();
        return;
      }

      // 3. Generate REAL 128-D FaceNet embedding
      final embedding = await FaceRecognitionService.instance
          .generateEmbeddingFromFile(xFile.path, faces.first);

      if (embedding == null) {
        _showMessage('Could not read face. Try better lighting.');
        _restartStream();
        return;
      }

      // 4. Match against enrolled students
      final match = FaceRecognitionService.instance
          .findBestMatch(embedding, _enrolledFaces);

      if (match == null) {
        _showUnknownDialog();
        _restartStream();
        return;
      }

      // 5. Check duplicate attendance today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final alreadyMarked = await DatabaseHelper.instance.alreadyMarkedToday(
        studentId: match.id,
        subjectSectionId: widget.subjectSectionId,
        date: today,
      );

      // 6. Mark attendance if not already done
      if (!alreadyMarked) {
        await DatabaseHelper.instance.markAttendance(
          studentId: match.id,
          subjectSectionId: widget.subjectSectionId,
          date: today,
          timeIn: DateFormat('HH:mm:ss').format(DateTime.now()),
          status: _isTimeIn ? 'present' : 'time_out',
        );
      }

      // 7. Show result
      _showSuccessDialog(
        name: match.name,
        confidence: match.confidence,
        alreadyMarked: alreadyMarked,
      );

      _restartStream();
    } catch (e) {
      print('Scan error: $e');
      _showMessage('Error during scan. Please try again.');
      _restartStream();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _restartStream() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _cameraController != null) {
        _cameraController!.startImageStream(_processCameraImage);
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Success dialog ────────────────────────────────────────────────────
  void _showSuccessDialog({
    required String name,
    required double confidence,
    required bool alreadyMarked,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: alreadyMarked
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  alreadyMarked
                      ? Icons.event_available_rounded
                      : Icons.how_to_reg_rounded,
                  color: alreadyMarked ? Colors.orange : Colors.green,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Status
              Text(
                alreadyMarked
                    ? 'Already marked today'
                    : _isTimeIn
                        ? '✓ Time In recorded!'
                        : '✓ Time Out recorded!',
                style: TextStyle(
                  color: alreadyMarked ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),

              // Time + confidence
              Text(
                DateFormat('hh:mm:ss a').format(DateTime.now()),
                style: const TextStyle(
                    color: Color(0xFF8B9DC3), fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                'Confidence: ${confidence.toStringAsFixed(1)}%',
                style: const TextStyle(
                    color: Color(0xFF8B9DC3), fontSize: 12),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Unknown face dialog ───────────────────────────────────────────────
  void _showUnknownDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_accounts_rounded,
                    color: Colors.redAccent, size: 38),
              ),
              const SizedBox(height: 16),
              const Text('Face Not Recognized',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 6),
              const Text(
                'This face is not enrolled.\nPlease register with the admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B9DC3), fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD — keeping your original UI
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(child: CameraPreview(_cameraController!))
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
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
                        color: Colors.white, strokeWidth: 2.5),
                    SizedBox(height: 16),
                    Text('Recognizing face...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // SENTRY logo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SENTRY',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildProgressDot(true),
                          _buildProgressLine(),
                          _buildProgressDot(true),
                          _buildProgressLine(),
                          _buildProgressDot(true),
                          _buildProgressLine(),
                          _buildProgressDot(true),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section name + enrolled count
                      Text(
                        widget.sectionName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_dbLoaded)
                        Text(
                          '${_enrolledFaces.length} students enrolled',
                          style: TextStyle(
                            color: _enrolledFaces.isEmpty
                                ? Colors.orange
                                : Colors.green.shade300,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Time in / Time out toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTimeButton('Time in', _isTimeIn, () {
                            setState(() => _isTimeIn = true);
                          }),
                          const SizedBox(width: 12),
                          _buildTimeButton('Time out', !_isTimeIn, () {
                            setState(() => _isTimeIn = false);
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Face frame
              Container(
                width: 280,
                height: 320,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _faceDetected ? Colors.green : Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned(top: 0, left: 0,
                        child: _buildCornerBracket(topLeft: true,
                            color: _faceDetected ? Colors.green : Colors.white)),
                    Positioned(top: 0, right: 0,
                        child: _buildCornerBracket(topRight: true,
                            color: _faceDetected ? Colors.green : Colors.white)),
                    Positioned(bottom: 0, left: 0,
                        child: _buildCornerBracket(bottomLeft: true,
                            color: _faceDetected ? Colors.green : Colors.white)),
                    Positioned(bottom: 0, right: 0,
                        child: _buildCornerBracket(bottomRight: true,
                            color: _faceDetected ? Colors.green : Colors.white)),
                    if (_faceDetected)
                      const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.green, size: 48),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                _isProcessing
                    ? 'Processing...'
                    : _faceDetected
                        ? 'Face detected! Ready to scan.'
                        : 'Find a good lighting spot',
                style: TextStyle(
                  color: _faceDetected ? Colors.green : Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight:
                      _faceDetected ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isCameraInitialized && !_isProcessing)
                            ? _captureAndProcessFace
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _faceDetected ? Colors.green : Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _faceDetected
                                  ? Colors.green
                                  : Colors.white,
                              width: 1,
                            ),
                          ),
                          disabledBackgroundColor: Colors.grey[800],
                        ),
                        child: const Text('Scan',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Your original UI helpers ──────────────────────────────────────────
  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProgressLine() {
    return Container(
      width: 40, height: 2,
      color: Colors.white.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildTimeButton(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[700] : Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  Widget _buildCornerBracket({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
    Color color = Colors.white,
  }) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: (topLeft || topRight)
              ? BorderSide(color: color, width: 4)
              : BorderSide.none,
          bottom: (bottomLeft || bottomRight)
              ? BorderSide(color: color, width: 4)
              : BorderSide.none,
          left: (topLeft || bottomLeft)
              ? BorderSide(color: color, width: 4)
              : BorderSide.none,
          right: (topRight || bottomRight)
              ? BorderSide(color: color, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }
}