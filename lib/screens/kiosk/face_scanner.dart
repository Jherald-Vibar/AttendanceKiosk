import 'package:Sentry/screens/kiosk/welcome.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:typed_data';

class FaceScanner extends StatefulWidget {
  const FaceScanner({super.key});

  @override
  State<FaceScanner> createState() => _FaceScannerState();
}

class _FaceScannerState extends State<FaceScanner> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _faceDetected = false;
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
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
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
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          
          if (mounted) {
            setState(() {
              _faceDetected = faces.isNotEmpty;
            });
          }
        }
      } catch (e) {
        print('Error detecting faces: $e');
      }

      _isDetecting = false;
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      
      InputImageRotation rotation;
      
      if (Platform.isIOS) {
        rotation = InputImageRotation.rotation0deg;
      } else {
        if (camera.lensDirection == CameraLensDirection.front) {
          rotation = InputImageRotation.rotation270deg;
        } else {
          rotation = InputImageRotation.rotation90deg;
        }
      }

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (image.planes.isEmpty) return null;

      // Concatenate all plane bytes for NV21 format
      final allBytes = <int>[];
      for (final plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }

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

  void _handleScan() async {
    if (!_faceDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No face detected. Please position your face in the frame.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _cameraController?.stopImageStream();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Face scanned successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Wait a moment before navigating
      await Future.delayed(Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Welcome())
        );
      }
    } catch (e) {
      print('Error during scan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning face. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          
          // Dark overlay for better visibility
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          
          // UI Content
          SafeArea(
            child: Column(
              children: [
                // Header - SENTRY
                Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    'SENTRY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                // Main content area
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Scan your face',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 50),
                      
                      // Face frame with rounded corners - changes color based on detection
                      Container(
                        width: 300,
                        height: 380,
                        child: Stack(
                          children: [
                            // Corner brackets - color changes when face detected
                            Positioned(
                              top: 0,
                              left: 0,
                              child: _buildCorner(true, true, _faceDetected),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: _buildCorner(true, false, _faceDetected),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: _buildCorner(false, true, _faceDetected),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: _buildCorner(false, false, _faceDetected),
                            ),
                            
                            // Center checkmark when face is detected
                            if (_faceDetected)
                              Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 64,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 50),
                      Text(
                        _faceDetected 
                          ? 'Face detected! Ready to scan.'
                          : 'Find a good lighting spot',
                        style: TextStyle(
                          color: _faceDetected 
                            ? Colors.green
                            : Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: _faceDetected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Buttons
                Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      // Scan button - enabled only when face is detected
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _faceDetected ? _handleScan : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _faceDetected ? Colors.green : Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.black.withOpacity(0.5),
                            disabledForegroundColor: Colors.white.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Scan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 15),
                      
                      // Back button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
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
        ],
      ),
    );
  }

  // Build corner bracket widget with rounded corners - color changes based on face detection
  Widget _buildCorner(bool isTop, bool isLeft, bool faceDetected) {
    Color borderColor = faceDetected ? Colors.green : Colors.white;
    
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: borderColor, width: 5) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: borderColor, width: 5) : BorderSide.none,
          left: isLeft ? BorderSide(color: borderColor, width: 5) : BorderSide.none,
          right: !isLeft ? BorderSide(color: borderColor, width: 5) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? Radius.circular(20) : Radius.zero,
          topRight: isTop && !isLeft ? Radius.circular(20) : Radius.zero,
          bottomLeft: !isTop && isLeft ? Radius.circular(20) : Radius.zero,
          bottomRight: !isTop && !isLeft ? Radius.circular(20) : Radius.zero,
        ),
      ),
    );
  }
}