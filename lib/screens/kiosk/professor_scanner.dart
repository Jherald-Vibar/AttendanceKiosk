// lib/screens/kiosk/professor_scanner.dart

import 'package:Sentry/screens/kiosk/welcome.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/services/face_recognition_service.dart';

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
          if (mounted) setState(() => _faceDetected = faces.isNotEmpty);
        }
      } catch (e) {
        print('Error detecting faces: $e');
      }
      _isDetecting = false;
    });
    _isStreaming = true;
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
    } catch (e) {
      print('Error converting image: $e');
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
          .findBestMatch(embedding, _enrolledProfessors);
      if (match == null) {
        _showUnknownDialog();
        _restartStream();
        return;
      }

      final profData =
          await DatabaseHelper.instance.getProfessorById(match.id);
      final subjects =
          await DatabaseHelper.instance.getSubjectsByProfessor(match.id);
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
      print('Error during scan: $e');
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
      _isStreaming = false;
    });
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
      builder: (ctx) => AlertDialog(
        title: const Text('Not Recognized'),
        content: const Text(
            'Face not found in the system.\nOnly registered professors can proceed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Try Again'))
        ],
      ),
    );
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
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // ✅ Compute dynamic sizes once from actual screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final frameSize = screenHeight * 0.38;         // face frame scales with screen
    final verticalSpacing = screenHeight * 0.04;   // replaces fixed SizedBox(50)

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
                // ── Title ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: const Text('SENTRY',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2)),
                ),

                // ── Centre content — Expanded so it fills remaining space ──
                Expanded(
                  child: SingleChildScrollView(
                    // ✅ SingleChildScrollView prevents overflow on very
                    //    small screens; on normal screens nothing scrolls
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

                          // ✅ Face frame — size tied to screen height
                          SizedBox(
                            width: frameSize * 0.8,
                            height: frameSize,
                            child: Stack(children: [
                              Positioned(
                                  top: 0,
                                  left: 0,
                                  child: _buildCorner(true, true, _faceDetected)),
                              Positioned(
                                  top: 0,
                                  right: 0,
                                  child: _buildCorner(true, false, _faceDetected)),
                              Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: _buildCorner(false, true, _faceDetected)),
                              Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: _buildCorner(false, false, _faceDetected)),
                              if (_faceDetected)
                                const Center(
                                    child: Icon(Icons.check_circle,
                                        color: Colors.green, size: 64)),
                            ]),
                          ),

                          SizedBox(height: verticalSpacing),
                          Text(
                            _faceDetected
                                ? 'Face detected! Ready to scan.'
                                : 'Find a good lighting spot',
                            style: TextStyle(
                              color: _faceDetected
                                  ? Colors.green
                                  : Colors.white.withOpacity(0.8),
                              fontSize: 16,
                              fontWeight: _faceDetected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          SizedBox(height: verticalSpacing),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom buttons — always anchored at the bottom ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: (_faceDetected && !_isProcessing)
                              ? _handleScan
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _faceDetected
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

  Widget _buildCorner(bool isTop, bool isLeft, bool faceDetected) {
    final Color borderColor = faceDetected ? Colors.green : Colors.white;
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: borderColor, width: 5)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: borderColor, width: 5)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: borderColor, width: 5)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: borderColor, width: 5)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft
              ? const Radius.circular(20)
              : Radius.zero,
          topRight: isTop && !isLeft
              ? const Radius.circular(20)
              : Radius.zero,
          bottomLeft: !isTop && isLeft
              ? const Radius.circular(20)
              : Radius.zero,
          bottomRight: !isTop && !isLeft
              ? const Radius.circular(20)
              : Radius.zero,
        ),
      ),
    );
  }
}