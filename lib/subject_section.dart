import 'package:Sentry/select_section.dart';
import 'package:flutter/material.dart';

class SubjectSelection extends StatefulWidget {
  const SubjectSelection({super.key});

  @override
  State<SubjectSelection> createState() => _SubjectSelectionState();
}

class _SubjectSelectionState extends State<SubjectSelection> {
  String? selectedSubject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'SENTRY',
          style: TextStyle(
            fontFamily: 'sans',
            fontSize: 28,
            fontStyle: FontStyle.italic,
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              // Add profile image here
              // backgroundImage: AssetImage('assets/images/profile.png'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProgressDot(true),
                _buildProgressLine(true),
                _buildProgressDot(true),
                _buildProgressLine(false),
                _buildProgressDot(false),
                _buildProgressLine(false),
                _buildProgressDot(false),
              ],
            ),
          ),
          
          SizedBox(height: 8),
          
          Text(
            'Select a Subject',
            style: TextStyle(
              fontFamily: 'sans',
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Subjects list
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 1st Year
                    Text(
                      '1st Year',
                      style: TextStyle(
                        fontFamily: 'sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubjectCard(
                            'Philippine\nHistory',
                            Icons.edit_outlined,
                            [Color(0xFF00D4AA), Color(0xFF00B894)],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSubjectCard(
                            'Computer\nProgramming',
                            Icons.memory,
                            [Color(0xFFFF9068), Color(0xFFFF6B6B)],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 2nd Year
                    Text(
                      '2nd Year',
                      style: TextStyle(
                        fontFamily: 'sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubjectCard(
                            'Data Structures\nand Algorithm',
                            Icons.memory,
                            [Color(0xFF4E9FFF), Color(0xFF0080FF)],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSubjectCard(
                            'Music',
                            Icons.music_note_outlined,
                            [Color(0xFFFF9068), Color(0xFFFF6B6B)],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 3rd Year
                    Text(
                      '3rd Year',
                      style: TextStyle(
                        fontFamily: 'sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Container()), // Empty placeholder
                        SizedBox(width: 12),
                        Expanded(child: Container()), // Empty placeholder
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Next button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Navigation logic
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text("Next"),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          // Back button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.grey[300]!),
                  textStyle: TextStyle(
                    fontFamily: 'sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text("Back"),
              ),
            ),
          ),
          
          SizedBox(height: 24),
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
        color: isActive ? Colors.grey[600] : Colors.grey[300],
      ),
    );
  }
  
  Widget _buildProgressLine(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      color: isActive ? Colors.grey[600] : Colors.grey[300],
    );
  }
  
  Widget _buildSubjectCard(String title, IconData icon, List<Color> gradientColors) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SectionSelection(subjectName: title))
        );
      },
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 12,
              right: 12,
              child: Icon(
                icon,
                color: Colors.white.withOpacity(0.7),
                size: 48,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'sans',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}