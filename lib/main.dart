import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext contebayaan xt) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Hot Reload Demo'),
          backgroundColor: Colors.blue, // Try changing to Colors.red and save!
        ),
        body: Center(
          child: Text(
            'Change me!', // Try changing this text and press Ctrl+S
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}