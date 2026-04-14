// lib/screens/kiosk/student_scanner.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';
import 'package:Sentry/screens/kiosk/kiosk_dashboard.dart';

enum _AttendanceResult {
  timeInRecorded,
  timeOutRecorded,
  alreadyTimedIn,
  alreadyTimedOut,
  noTimeInYet,
}

class StudentScanner extends StatefulWidget {
  final int subjectSectionId;
  final String sectionName;
  final Map<String, dynamic> professor;

  const StudentScanner({
    super.key,
    required this.subjectSectionId,
    required this.sectionName,
    required this.professor,
  });

  @override
  State<StudentScanner> createState() => _StudentScannerState();
}

class _StudentScannerState extends State<StudentScanner> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isStreaming = false;
  bool _isTimeIn = true;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isProcessing = false;
  List<EnrolledFace> _enrolledFaces = [];
  bool _dbLoaded = false;

  // ── Auto-scan state ───────────────────────────────────────────────
  Timer? _autoScanTimer;
  bool _autoScanReady = true;
  static const Duration _autoScanDelay    = Duration(seconds: 2);
  static const Duration _autoScanCooldown = Duration(seconds: 4);
  DateTime? _faceFirstSeenAt;

  // ── No-face auto-end (Time Out mode only) ─────────────────────────
  Timer? _noFaceEndTimer;
  int _noFaceCountdown = 0;
  static const int _noFaceTimeoutSecs = 60;

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
    FaceRecognitionService.instance.initialize();
  }

  Future<void> _loadEnrolledFaces() async {
    final rows = await DatabaseHelper.instance
        .getEnrolledFacesBySubjectSection(widget.subjectSectionId);
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
    if (mounted) setState(() { _enrolledFaces = faces; _dbLoaded = true; });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startStream();
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  // ── Stream helpers ────────────────────────────────────────────────
  void _startStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isStreaming) return;
    _cameraController!.startImageStream(_processCameraImage);
    _isStreaming = true;
  }

  Future<void> _stopStream() async {
    if (!_isStreaming) return;
    try { await _cameraController?.stopImageStream(); } catch (_) {}
    _isStreaming = false;
  }

  Future<void> _processCameraImage(CameraImage img) async {
    if (_isDetecting || _isProcessing) return;
    _isDetecting = true;
    try {
      final inp = _convertCameraImage(img);
      if (inp != null) {
        final faces = await _faceDetector.processImage(inp);
        final detected = faces.isNotEmpty;

        if (mounted) setState(() => _faceDetected = detected);

        if (detected) {
          // Face appeared — cancel any no-face end timer
          _cancelNoFaceTimer();
          _faceFirstSeenAt ??= DateTime.now();

          final heldLongEnough = DateTime.now()
              .difference(_faceFirstSeenAt!) >= _autoScanDelay;

          if (heldLongEnough && _autoScanReady && !_isProcessing && _dbLoaded) {
            _triggerAutoScan();
          }
        } else {
          // No face — reset hold timer
          _faceFirstSeenAt = null;

          // Start no-face countdown only in Time Out mode
          if (!_isTimeIn && !_isProcessing) {
            _startNoFaceTimer();
          }
        }
      }
    } catch (_) {}
    _isDetecting = false;
  }

  // ── No-face auto-end timer ────────────────────────────────────────

  /// Starts the countdown only if not already running.
  void _startNoFaceTimer() {
    if (_noFaceEndTimer != null) return; // already ticking
    if (mounted) setState(() => _noFaceCountdown = _noFaceTimeoutSecs);

    // Tick every second to update the countdown UI
    _noFaceEndTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = _noFaceCountdown - 1;
      if (remaining <= 0) {
        t.cancel();
        _noFaceEndTimer = null;
        _autoEndClass();
      } else {
        setState(() => _noFaceCountdown = remaining);
      }
    });
  }

  /// Cancels the countdown (called when a face is detected again).
  void _cancelNoFaceTimer() {
    if (_noFaceEndTimer == null) return;
    _noFaceEndTimer?.cancel();
    _noFaceEndTimer = null;
    if (mounted) setState(() => _noFaceCountdown = 0);
  }

  /// Fires when countdown reaches zero — navigates to KioskDashboard.
  void _autoEndClass() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KioskDashboard()),
      (route) => false,
    );
  }

  // ── Auto-scan helpers ─────────────────────────────────────────────
  void _triggerAutoScan() {
    if (!_autoScanReady || _isProcessing) return;
    setState(() => _autoScanReady = false);
    _captureAndProcessFace();
  }

  void _startCooldown() {
    _faceFirstSeenAt = null;
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer(_autoScanCooldown, () {
      if (mounted) setState(() => _autoScanReady = true);
    });
  }

  InputImage? _convertCameraImage(CameraImage img) {
    try {
      final rotation = Platform.isIOS
          ? InputImageRotation.rotation0deg
          : _cameraController!.description.lensDirection == CameraLensDirection.front
              ? InputImageRotation.rotation270deg
              : InputImageRotation.rotation90deg;
      final format = InputImageFormatValue.fromRawValue(img.format.raw);
      if (format == null || img.planes.isEmpty) return null;
      final bytes = <int>[];
      for (final p in img.planes) bytes.addAll(p.bytes);
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: img.planes[0].bytesPerRow,
        ),
      );
    } catch (_) { return null; }
  }

  // ── Student face scan ─────────────────────────────────────────────
  Future<void> _captureAndProcessFace() async {
    if (!_faceDetected) { _startCooldown(); return; }
    if (!_dbLoaded)     { _startCooldown(); return; }
    if (_enrolledFaces.isEmpty) { _showMessage('No enrolled students.'); _startCooldown(); return; }

    setState(() => _isProcessing = true);
    try {
      await _stopStream();
      final xFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFile(File(xFile.path));
      final faces = await FaceRecognitionService.instance.detectFaces(inputImage);
      if (faces.isEmpty) { _showMessage('No face on capture.'); _restartStream(); _startCooldown(); return; }

      final primaryFace = faces.reduce((a, b) =>
          a.boundingBox.width > b.boundingBox.width ? a : b);

      final embedding = await FaceRecognitionService.instance
          .generateEmbeddingFromFile(xFile.path, primaryFace);
      if (embedding == null) { _showMessage('Could not read face.'); _restartStream(); _startCooldown(); return; }

      final match = FaceRecognitionService.instance
          .findBestMatch(embedding, _enrolledFaces);
      if (match == null) { _showUnknownDialog(); _restartStream(); _startCooldown(); return; }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now   = DateFormat('HH:mm:ss').format(DateTime.now());

      _AttendanceResult attendanceResult;

      if (_isTimeIn) {
        final alreadyIn = await DatabaseHelper.instance.alreadyMarkedToday(
          studentId: match.id,
          subjectSectionId: widget.subjectSectionId,
          date: today,
        );
        if (!alreadyIn) {
          await DatabaseHelper.instance.markAttendance(
            studentId: match.id,
            subjectSectionId: widget.subjectSectionId,
            date: today,
            timeIn: now,
          );
          attendanceResult = _AttendanceResult.timeInRecorded;
        } else {
          attendanceResult = _AttendanceResult.alreadyTimedIn;
        }
      } else {
        final needsOut = await DatabaseHelper.instance.hasTimedInButNotOut(
          studentId: match.id,
          subjectSectionId: widget.subjectSectionId,
          date: today,
        );
        if (needsOut) {
          await DatabaseHelper.instance.markTimeOut(
            studentId: match.id,
            subjectSectionId: widget.subjectSectionId,
            date: today,
            timeOut: now,
          );
          attendanceResult = _AttendanceResult.timeOutRecorded;
        } else {
          final existing = await DatabaseHelper.instance.getAttendanceForToday(
            studentId: match.id,
            subjectSectionId: widget.subjectSectionId,
            date: today,
          );
          attendanceResult = existing == null
              ? _AttendanceResult.noTimeInYet
              : _AttendanceResult.alreadyTimedOut;
        }
      }

      _showSuccessDialog(
        name: match.name,
        confidence: match.confidence,
        result: attendanceResult,
      );
      _restartStream();
      _startCooldown();
    } catch (e) {
      debugPrint('Scan error: $e');
      _showMessage('Error during scan.');
      _restartStream();
      _startCooldown();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Professor verify sheet ────────────────────────────────────────
  Future<void> _showProfessorVerifySheet({required bool isEndClass}) async {
    // Pause no-face timer while professor sheet is open
    _cancelNoFaceTimer();
    await _stopStream();
    _autoScanTimer?.cancel();
    if (mounted) setState(() { _faceDetected = false; _autoScanReady = false; });

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _ProfessorVerifySheet(
        professor: widget.professor,
        actionLabel: isEndClass ? 'End Class' : 'Enable Time Out',
        onVerified: () {
          Navigator.pop(ctx);
          if (isEndClass) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const KioskDashboard()),
              (route) => false,
            );
          } else {
            if (mounted) setState(() => _isTimeIn = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Time Out mode enabled.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        onCancelled: () => Navigator.pop(ctx),
      ),
    );

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    await _reinitializeCameraAfterSheet();
    if (mounted) setState(() => _autoScanReady = true);
    // If we're now in Time Out mode, the no-face timer starts naturally
    // via _processCameraImage when no face is seen.
  }

  Future<void> _reinitializeCameraAfterSheet() async {
    try {
      final old = _cameraController;
      _cameraController = null;
      _isStreaming = false;
      if (mounted) setState(() { _isCameraInitialized = false; _faceDetected = false; });
      try { await old?.dispose(); } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startStream();
      }
    } catch (e) {
      debugPrint('Camera reinit error: $e');
    }
  }

  void _restartStream() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startStream();
    });
  }

  // ── Dialogs & messages ────────────────────────────────────────────
  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessDialog({
    required String name,
    required double confidence,
    required _AttendanceResult result,
  }) {
    final isWarning = result == _AttendanceResult.alreadyTimedIn ||
        result == _AttendanceResult.alreadyTimedOut ||
        result == _AttendanceResult.noTimeInYet;

    final Color iconBg;
    final Color iconColor;
    final IconData iconData;
    final String statusText;

    switch (result) {
      case _AttendanceResult.timeInRecorded:
        iconBg = Colors.green.withOpacity(0.15);
        iconColor = Colors.green;
        iconData = Icons.how_to_reg_rounded;
        statusText = '✓ Time In recorded!';
        break;
      case _AttendanceResult.timeOutRecorded:
        iconBg = Colors.blue.withOpacity(0.15);
        iconColor = Colors.blue;
        iconData = Icons.logout_rounded;
        statusText = '✓ Time Out recorded!';
        break;
      case _AttendanceResult.alreadyTimedIn:
        iconBg = Colors.orange.withOpacity(0.15);
        iconColor = Colors.orange;
        iconData = Icons.event_available_rounded;
        statusText = 'Already timed in today';
        break;
      case _AttendanceResult.alreadyTimedOut:
        iconBg = Colors.orange.withOpacity(0.15);
        iconColor = Colors.orange;
        iconData = Icons.event_available_rounded;
        statusText = 'Already timed out today';
        break;
      case _AttendanceResult.noTimeInYet:
        iconBg = Colors.red.withOpacity(0.15);
        iconColor = Colors.redAccent;
        iconData = Icons.warning_amber_rounded;
        statusText = 'No time-in found for today';
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 38),
            ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(statusText,
                style: TextStyle(
                    color: isWarning ? iconColor : Colors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(DateFormat('hh:mm:ss a').format(DateTime.now()),
                style: const TextStyle(color: Color(0xFF8B9DC3), fontSize: 13)),
            const SizedBox(height: 2),
            Text('Confidence: ${confidence.toStringAsFixed(1)}%',
                style: const TextStyle(color: Color(0xFF8B9DC3), fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWarning ? iconColor : Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showUnknownDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle),
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
              'This face is not enrolled in this section.\nPlease register with the admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B9DC3), fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
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
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _noFaceEndTimer?.cancel();
    _stopStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final frameHeight = screenHeight * 0.30;
    final frameWidth = frameHeight * 0.875;

    final bool isWarmingUp = _faceDetected &&
        !_isProcessing &&
        _autoScanReady &&
        _faceFirstSeenAt != null;

    // Show countdown only in Time Out mode while no face is visible
    final bool showNoFaceCountdown = !_isTimeIn &&
        !_isProcessing &&
        !_faceDetected &&
        _noFaceCountdown > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_isCameraInitialized && _cameraController != null)
              SizedBox.expand(child: CameraPreview(_cameraController!))
            else
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),

            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                    SizedBox(height: 16),
                    Text('Recognizing face...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('SENTRY',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 2)),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildProgressDot(true), _buildProgressLine(),
                          _buildProgressDot(true), _buildProgressLine(),
                          _buildProgressDot(true), _buildProgressLine(),
                          _buildProgressDot(true),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(widget.sectionName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),

                      if (_dbLoaded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _enrolledFaces.isEmpty
                                ? Colors.orange.withOpacity(0.15)
                                : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _enrolledFaces.isEmpty
                                ? '⚠ No enrolled students'
                                : '${_enrolledFaces.length} students enrolled',
                            style: TextStyle(
                              color: _enrolledFaces.isEmpty
                                  ? Colors.orange
                                  : Colors.green.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 1.5),
                        ),
                      const SizedBox(height: 10),

                      // ── Mode row ──────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: _isTimeIn
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _isTimeIn
                                      ? Colors.green.withOpacity(0.4)
                                      : Colors.orange.withOpacity(0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                _isTimeIn
                                    ? Icons.login_rounded
                                    : Icons.logout_rounded,
                                color: _isTimeIn ? Colors.green : Colors.orange,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isTimeIn ? 'Time In' : 'Time Out',
                                style: TextStyle(
                                  color: _isTimeIn ? Colors.green : Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ]),
                          ),

                          if (_isTimeIn) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async =>
                                  await _showProfessorVerifySheet(
                                      isEndClass: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.4)),
                                ),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded,
                                          color: Colors.orange, size: 12),
                                      SizedBox(width: 4),
                                      Text('Time Out',
                                          style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ]),
                  ),

                  // ── Face frame ─────────────────────────────────
                  Expanded(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: frameWidth, height: frameHeight,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _isProcessing
                                    ? Colors.white
                                    : showNoFaceCountdown
                                        ? Colors.redAccent
                                        : !_autoScanReady
                                            ? Colors.blue
                                            : _faceDetected
                                                ? Colors.green
                                                : Colors.white,
                                width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(children: [
                            Positioned(
                                top: 0, left: 0,
                                child: _buildCornerBracket(
                                    topLeft: true,
                                    color: showNoFaceCountdown
                                        ? Colors.redAccent
                                        : _faceDetected
                                            ? Colors.green
                                            : Colors.white)),
                            Positioned(
                                top: 0, right: 0,
                                child: _buildCornerBracket(
                                    topRight: true,
                                    color: showNoFaceCountdown
                                        ? Colors.redAccent
                                        : _faceDetected
                                            ? Colors.green
                                            : Colors.white)),
                            Positioned(
                                bottom: 0, left: 0,
                                child: _buildCornerBracket(
                                    bottomLeft: true,
                                    color: showNoFaceCountdown
                                        ? Colors.redAccent
                                        : _faceDetected
                                            ? Colors.green
                                            : Colors.white)),
                            Positioned(
                                bottom: 0, right: 0,
                                child: _buildCornerBracket(
                                    bottomRight: true,
                                    color: showNoFaceCountdown
                                        ? Colors.redAccent
                                        : _faceDetected
                                            ? Colors.green
                                            : Colors.white)),

                            // No-face countdown overlay (Time Out mode)
                            if (showNoFaceCountdown)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_noFaceCountdown',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Text(
                                      'Ending class...',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),

                            // Warming up indicator
                            if (isWarmingUp && !showNoFaceCountdown)
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.face_unlock_outlined,
                                        color: Colors.green, size: 36),
                                    SizedBox(height: 6),
                                    Text('Hold still...',
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),

                            // Cooldown indicator
                            if (!_autoScanReady && !_isProcessing && !showNoFaceCountdown)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Please wait...',
                                      style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 12),

                        // Status text
                        Text(
                          _isProcessing
                              ? 'Processing...'
                              : showNoFaceCountdown
                                  ? 'No face detected — class ending in $_noFaceCountdown s'
                                  : !_autoScanReady
                                      ? 'Next scan ready soon...'
                                      : _faceDetected
                                          ? 'Face detected — scanning automatically'
                                          : 'Find a good lighting spot',
                          style: TextStyle(
                            color: _isProcessing
                                ? Colors.white
                                : showNoFaceCountdown
                                    ? Colors.redAccent
                                    : !_autoScanReady
                                        ? Colors.blue
                                        : _faceDetected
                                            ? Colors.green
                                            : Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: (showNoFaceCountdown ||
                                    _faceDetected ||
                                    !_autoScanReady)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),

                        const SizedBox(height: 6),

                        if (!_isProcessing && !showNoFaceCountdown)
                          Text(
                            'Auto-scans after ${_autoScanDelay.inSeconds}s • ${_autoScanCooldown.inSeconds}s cooldown',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                          ),

                        // Hint shown in Time Out mode while waiting
                        if (!_isProcessing && !_isTimeIn && !_faceDetected && !showNoFaceCountdown)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Class auto-ends after ${_noFaceTimeoutSecs}s with no face',
                              style: TextStyle(
                                color: Colors.orange.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),

                  // ── Bottom — End Class only ───────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async =>
                            await _showProfessorVerifySheet(isEndClass: true),
                        icon: const Icon(Icons.stop_circle_rounded, size: 18),
                        label: const Text('End Class',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
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

  Widget _buildProgressDot(bool isActive) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        ),
      );

  Widget _buildProgressLine() => Container(
        width: 40, height: 2,
        color: Colors.white.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  Widget _buildCornerBracket({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
    Color color = Colors.white,
  }) =>
      Container(
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

// ══════════════════════════════════════════════════════════════════════════════
// Professor Verify Bottom Sheet  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════

class _ProfessorVerifySheet extends StatefulWidget {
  final Map<String, dynamic> professor;
  final String actionLabel;
  final VoidCallback onVerified;
  final VoidCallback onCancelled;

  const _ProfessorVerifySheet({
    required this.professor,
    required this.actionLabel,
    required this.onVerified,
    required this.onCancelled,
  });

  @override
  State<_ProfessorVerifySheet> createState() => _ProfessorVerifySheetState();
}

class _ProfessorVerifySheetState extends State<_ProfessorVerifySheet> {
  CameraController? _cam;
  bool _camReady = false;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isProcessing = false;
  bool _isStreaming = false;
  EnrolledFace? _professorFace;

  final FaceDetector _detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));

  @override
  void initState() {
    super.initState();
    _loadProfessorFace();
    _initCamera();
  }

  Future<void> _loadProfessorFace() async {
    final profId = widget.professor['id'];
    if (profId == null) return;
    final row = await DatabaseHelper.instance.getProfessorById(profId);
    if (row == null || row['face_embedding'] == null) return;
    try {
      if (mounted) setState(() {
        _professorFace = EnrolledFace(
          id: row['id'],
          name: row['full_name'],
          role: 'professor',
          embedding: FaceRecognitionService.decode(row['face_embedding']),
        );
      });
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first);
      _cam = CameraController(front, ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
      await _cam!.initialize();
      if (mounted) {
        setState(() => _camReady = true);
        _startStream();
      }
    } catch (_) {}
  }

  void _startStream() {
    if (_cam == null || !_cam!.value.isInitialized || _isStreaming) return;
    _cam!.startImageStream((image) async {
      if (_isDetecting || _isProcessing) return;
      _isDetecting = true;
      try {
        final inp = _toInput(image);
        if (inp != null) {
          final faces = await _detector.processImage(inp);
          if (mounted) setState(() => _faceDetected = faces.isNotEmpty);
        }
      } catch (_) {}
      _isDetecting = false;
    });
    _isStreaming = true;
  }

  InputImage? _toInput(CameraImage image) {
    try {
      final rotation = Platform.isIOS
          ? InputImageRotation.rotation0deg
          : _cam!.description.lensDirection == CameraLensDirection.front
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

  Future<void> _verify() async {
    if (!_faceDetected) return;
    if (_professorFace == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Professor face not enrolled. Cannot verify.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (_isStreaming) {
        try { await _cam?.stopImageStream(); } catch (_) {}
        _isStreaming = false;
      }
      await Future.delayed(const Duration(milliseconds: 200));

      final xFile = await _cam!.takePicture();
      final faces = await FaceRecognitionService.instance
          .detectFaces(InputImage.fromFile(File(xFile.path)));
      if (faces.isEmpty) {
        _showErr('No face captured.');
        _restartStream();
        return;
      }

      final embedding = await FaceRecognitionService.instance
          .generateEmbeddingFromFile(xFile.path, faces.first);
      if (embedding == null) {
        _showErr('Could not read face.');
        _restartStream();
        return;
      }

      final match = FaceRecognitionService.instance
          .findBestMatch(embedding, [_professorFace!]);
      if (match == null) {
        _showErr('Not recognized. Only the professor can do this.');
        _restartStream();
        return;
      }

      if (_isStreaming) {
        try { await _cam?.stopImageStream(); } catch (_) {}
        _isStreaming = false;
      }

      widget.onVerified();
    } catch (_) {
      _showErr('Error verifying. Try again.');
      _restartStream();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCancel() async {
    if (_isStreaming) {
      try { await _cam?.stopImageStream(); } catch (_) {}
      _isStreaming = false;
    }
    try { await _cam?.dispose(); _cam = null; } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
    widget.onCancelled();
  }

  void _restartStream() {
    if (!mounted) return;
    setState(() { _isStreaming = false; _faceDetected = false; });
    Future.delayed(const Duration(milliseconds: 300), _startStream);
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
      try { _cam?.stopImageStream(); } catch (_) {}
    }
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFF3D4F6B),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.lock_rounded,
                  color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.actionLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const Text('Professor face verification required',
                        style: TextStyle(
                            color: Color(0xFF8B9DC3), fontSize: 12)),
                  ]),
            ),
            GestureDetector(
              onTap: _handleCancel,
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF8B9DC3), size: 22),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _camReady && _cam != null
                  ? Stack(fit: StackFit.expand, children: [
                      CameraPreview(_cam!),
                      if (_faceDetected)
                        const Center(
                          child: Icon(Icons.check_circle,
                              color: Colors.green, size: 64),
                        ),
                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                  SizedBox(height: 10),
                                  Text('Verifying professor...',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 13)),
                                ]),
                          ),
                        ),
                    ])
                  : const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00D4FF))),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _faceDetected
                ? 'Face detected! Tap Verify.'
                : "Position professor's face in frame",
            style: TextStyle(
              color: _faceDetected ? Colors.green : const Color(0xFF8B9DC3),
              fontSize: 13,
              fontWeight: _faceDetected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _handleCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B9DC3),
                  side: const BorderSide(color: Color(0xFF1E2D45)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (_faceDetected && !_isProcessing) ? _verify : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}