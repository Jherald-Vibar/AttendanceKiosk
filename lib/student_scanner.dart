import 'package:flutter/material.dart';

class StudentScanner extends StatefulWidget {
  var sectionName;
  StudentScanner({super.key, required this.sectionName});

  @override
  State<StudentScanner> createState() => _StudentScannerState();
}

class _StudentScannerState extends State<StudentScanner> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.sectionName,
              style: TextStyle(
                fontFamily: "sans",
                fontSize: 24,
                fontWeight: FontWeight.bold,  
                fontStyle: FontStyle.italic,
                color: Colors.blue,
              ),
            ),
          ],
        )
      ),
    );
  }
}