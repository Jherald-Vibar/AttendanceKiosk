import 'package:Sentry/subject_section.dart';
import 'package:flutter/material.dart';

class Welcome extends StatelessWidget {
  const Welcome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // SENTRY Logo at top
            SizedBox(height: 40),
            Text(
              'SENTRY',
              style: TextStyle(
                fontFamily: 'sans',
                fontStyle: FontStyle.italic,
                fontSize: 36,
                color: Color(0xFF1E3A8A), // Dark blue color
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            
            Spacer(),
            
            // Centered content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile picture with gold border
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFFE8B44F), // Gold/yellow border
                      width: 12,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                      // Uncomment when you add image
                      // image: DecorationImage(
                      //   image: AssetImage('assets/images/profile.png'),
                      //   fit: BoxFit.cover,
                      // ),
                    ),
                  ),
                ),
                
                SizedBox(height: 50),
                
                // Welcome text
                Text(
                  'Welcome, Sir Stephen!',
                  style: TextStyle(
                    fontFamily: 'sans',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Name subtitle
                Text(
                  'Stephen Forteza',
                  style: TextStyle(
                    fontFamily: 'sans',
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            
            Spacer(),
            
            // Next button at bottom
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SubjectSelection())
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontFamily: 'sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text("Next"),
                ),
              ),
            ),
            
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}