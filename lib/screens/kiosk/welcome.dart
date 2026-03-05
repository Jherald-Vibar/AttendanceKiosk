// lib/screens/kiosk/welcome.dart

import 'package:flutter/material.dart';
import 'package:Sentry/screens/kiosk/subject_selection.dart'; // your existing file

class Welcome extends StatelessWidget {
  final Map<String, dynamic>? professor;
  final List<Map<String, dynamic>>? subjects;

  const Welcome({
    super.key,
    this.professor,  // optional so login.dart Welcome() still works
    this.subjects,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = professor?['full_name'] ?? 'Professor';
    final firstName = fullName.split(' ').first;
    final department = professor?['department'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'SENTRY',
              style: TextStyle(
                fontFamily: 'sans',
                fontStyle: FontStyle.italic,
                fontSize: 36,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),

            const Spacer(),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile circle with gold border — your original design
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE8B44F),
                      width: 12,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A8A),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        fullName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                Text(
                  'Welcome, Sir $firstName!',
                  style: const TextStyle(
                    fontFamily: 'sans',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  fullName,
                  style: TextStyle(
                    fontFamily: 'sans',
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),

                if (department.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    department,
                    style: TextStyle(
                      fontFamily: 'sans',
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubjectSelection(  // ← correct class name
                          professor: professor ?? {},
                          subjects: subjects ?? [],
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontFamily: 'sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text("Next"),
                ),
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}