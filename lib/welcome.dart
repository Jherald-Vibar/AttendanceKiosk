import 'package:flutter/material.dart';


class Welcome extends StatelessWidget {
  const Welcome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sentry', style: TextStyle(fontFamily: 'sans', fontSize: 20)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ), 
            ),
            SizedBox(height: 50,),
            Text('Welcome, Stephen', style: TextStyle(fontFamily: 'sans', fontSize: 20, fontWeight: FontWeight.bold),)
          ],
        ),
      )
    );
  }
}