import 'package:flutter/material.dart';
import 'package:attendance_kiosk_app/face_scanner.dart';

void main() {
  runApp( MyApp() );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF82D8ff),
            Color(0xffffffff),
          ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 200,),
            SizedBox(height: 30,),
            Text('Facial Recognition System', style: TextStyle(fontFamily: 'sans', fontSize: 18),),
            Text('Secure Attendance Tracking', style: TextStyle(fontFamily: 'sans', fontSize: 14),),
            SizedBox(height: 70,),
            ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FaceScanner())
                );
            }, 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: Size(200, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Next'))
            ],
          )
        )
      ),
    );
  }
}

