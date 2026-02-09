import 'package:Sentry/welcome.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceScanner extends StatefulWidget {
  const FaceScanner({super.key});

  @override
  State<FaceScanner> createState() => _FaceScannerState();
}

class _FaceScannerState extends State<FaceScanner> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  List<Face> _faces = [];
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
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
      ResolutionPreset.high,
      enableAudio: false,
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
              _faces = faces;
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
    final camera = _cameraController!.description;
    
    InputImageRotation? rotation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotation = InputImageRotation.rotation270deg;
    } else {
      rotation = InputImageRotation.rotation90deg;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
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
                // Header - SENTRY (transparent background)
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
                      
                      // Face frame with rounded corners
                      Container(
                        width: 300,
                        height: 380,
                        child: Stack(
                          children: [
                            // Corner brackets
                            Positioned(
                              top: 0,
                              left: 0,
                              child: _buildCorner(true, true),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: _buildCorner(true, false),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: _buildCorner(false, true),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: _buildCorner(false, false),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 50),
                      Text(
                        'Find a good lighting spot',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
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
                      // Scan button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () async{
                            await _cameraController?.stopImageStream();
                            if(mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => Welcome())
                              );
                            }
                            // print('Scanning face...');
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   SnackBar(
                            //     content: Text('Face scanned successfully!'),
                            //     backgroundColor: Colors.green,
                            //   ),
                            // );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
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

  // Build corner bracket widget with rounded corners
  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: Colors.white, width: 5) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: Colors.white, width: 5) : BorderSide.none,
          left: isLeft ? BorderSide(color: Colors.white, width: 5) : BorderSide.none,
          right: !isLeft ? BorderSide(color: Colors.white, width: 5) : BorderSide.none,
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