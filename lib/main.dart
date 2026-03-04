import 'package:flutter/material.dart';
import 'package:Sentry/screens/kiosk/professor_scanner.dart';
import 'package:Sentry/screens/Auth/login.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentry',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ── Show Admin Face Scan Popup ─────────────────────────────────────
  void _showKioskPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
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
              // ── Header ─────────────────────────────────────────────
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xFF00D4FF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kiosk Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Admin verification required',
                            style: TextStyle(
                              color: Color(0xFF8B9DC3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF8B9DC3), size: 20),
                    ),
                  ],
                ),
              ),

              // ── Face Scan Area ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text(
                      'Scan your face to enter\nKiosk Mode as Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1C2536),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Face scan frame
                    _AnimatedFaceFrame(),

                    const SizedBox(height: 24),

                    const Text(
                      'Position your face within the frame',
                      style: TextStyle(
                        color: Color(0xFF8B9DC3),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Scan button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FaceScanner(isKioskMode: true),  // unchanged
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Scan Admin Face',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A0E1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF8B9DC3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background Gradient ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF82D8ff),
                  Color(0xffffffff),
                ],
              ),
            ),
          ),

          // ── Kiosk Mode Button (Top Right) ────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _showKioskPopup(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.black.withOpacity(0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.desktop_windows_rounded,
                                size: 16, color: Color(0xFF1C2536)),
                            SizedBox(width: 6),
                            Text(
                              'Kiosk Mode',
                              style: TextStyle(
                                color: Color(0xFF1C2536),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content ─────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 200),
                const SizedBox(height: 30),
                const Text(
                  'Facial Recognition System',
                  style: TextStyle(fontFamily: 'sans', fontSize: 18),
                ),
                const Text(
                  'Secure Attendance Tracking',
                  style: TextStyle(fontFamily: 'sans', fontSize: 14),
                ),
                const SizedBox(height: 70),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Face Frame Widget ─────────────────────────────────────────

class _AnimatedFaceFrame extends StatefulWidget {
  @override
  State<_AnimatedFaceFrame> createState() => _AnimatedFaceFrameState();
}

class _AnimatedFaceFrameState extends State<_AnimatedFaceFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 200,
      child: Stack(
        children: [
          // Face oval placeholder
          Center(
            child: Container(
              width: 140,
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(80),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 80,
                color: Color(0xFFCDD5E0),
              ),
            ),
          ),

          // Corner frame
          CustomPaint(
            size: const Size(180, 200),
            painter: _CornerFramePainter(color: const Color(0xFF0A0E1A)),
          ),

          // Animated scan line
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (_, __) => Positioned(
              top: 20 + (_scanAnimation.value * 160),
              left: 20,
              right: 20,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF00D4FF).withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

    const c = 22.0;
    // Top-left
    canvas.drawLine(const Offset(0, c), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(c, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - c, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, c), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - c), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(c, size.height), paint);
    // Bottom-right
    canvas.drawLine(
        Offset(size.width - c, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - c), paint);
  }

  @override
  bool shouldRepaint(_CornerFramePainter old) => old.color != color;
}