import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // ADD THIS LINE

class StudentScanner extends StatefulWidget {
  var sectionName;
  StudentScanner({super.key, required this.sectionName});

  @override
  State<StudentScanner> createState() => _StudentScannerState();
}

class _StudentScannerState extends State<StudentScanner> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isTimeIn = true;
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
    try {
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
        setState(() {
          _isCameraInitialized = true;
        });
        
        _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }
      
      final faces = await _faceDetector.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _faceDetected = faces.isNotEmpty;
        });
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
        if (camera.lensDirection == CameraLensDirection.front) {
          rotation = InputImageRotation.rotation270deg;
        } else {
          rotation = InputImageRotation.rotation90deg;
        }
      }

      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null) {
        print('Unsupported format: ${cameraImage.format.raw}');
        return null;
      }

      if (cameraImage.planes.isEmpty) {
        return null;
      }

      // Concatenate all plane bytes
      final allBytes = <int>[];
      for (final plane in cameraImage.planes) {
        allBytes.addAll(plane.bytes);
      }

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(allBytes),
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
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

  Future<void> _captureAndProcessFace() async {
    if (!_faceDetected) {
      _showMessage('No face detected. Please position your face in the frame.');
      return;
    }

    try {
      await _cameraController?.stopImageStream();
      
      final XFile image = await _cameraController!.takePicture();
      
      _showMessage('Face captured successfully!');
      
      await _processAttendance(image.path);
      
      await Future.delayed(Duration(seconds: 1));
      if (mounted && _cameraController != null) {
        _cameraController!.startImageStream(_processCameraImage);
      }
      
    } catch (e) {
      print('Error capturing face: $e');
      _showMessage('Error capturing face. Please try again.');
      if (mounted && _cameraController != null) {
        _cameraController!.startImageStream(_processCameraImage);
      }
    }
  }

  Future<void> _processAttendance(String imagePath) async {
    await Future.delayed(Duration(seconds: 2));
    
    if (mounted) {
      _showSuccessDialog();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(
          _isTimeIn 
            ? 'Time in recorded successfully!' 
            : 'Time out recorded successfully!'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: CameraPreview(_cameraController!),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'SENTRY',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

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
                      SizedBox(height: 16),

                      Text(
                        widget.sectionName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTimeButton('Time in', _isTimeIn, () {
                            setState(() {
                              _isTimeIn = true;
                            });
                          }),
                          SizedBox(width: 12),
                          _buildTimeButton('Time out', !_isTimeIn, () {
                            setState(() {
                              _isTimeIn = false;
                            });
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(),

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
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _buildCornerBracket(
                        topLeft: true,
                        color: _faceDetected ? Colors.green : Colors.white,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildCornerBracket(
                        topRight: true,
                        color: _faceDetected ? Colors.green : Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildCornerBracket(
                        bottomLeft: true,
                        color: _faceDetected ? Colors.green : Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildCornerBracket(
                        bottomRight: true,
                        color: _faceDetected ? Colors.green : Colors.white,
                      ),
                    ),
                    
                    if (_faceDetected)
                      Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 48,
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              Text(
                _faceDetected 
                  ? 'Face detected! Ready to scan.' 
                  : 'Find a good lighting spot',
                style: TextStyle(
                  color: _faceDetected ? Colors.green : Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: _faceDetected ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              Spacer(),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isCameraInitialized ? _captureAndProcessFace : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _faceDetected ? Colors.green : Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _faceDetected ? Colors.green : Colors.white,
                              width: 1,
                            ),
                          ),
                          disabledBackgroundColor: Colors.grey[800],
                        ),
                        child: Text(
                          'Scan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 16,
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
        ],
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildProgressLine() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.white.withOpacity(0.3),
      margin: EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildTimeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[700] : Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
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
      width: 40,
      height: 40,
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