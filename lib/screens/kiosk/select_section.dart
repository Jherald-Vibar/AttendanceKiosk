import 'package:Sentry/screens/kiosk/student_scanner.dart';
import 'package:flutter/material.dart';
import 'package:Sentry/screens/kiosk/face_scanner.dart';

class SectionSelection extends StatefulWidget {
  final String subjectName;
  
  const SectionSelection({super.key, required this.subjectName});

  @override
  State<SectionSelection> createState() => _SectionSelectionState();
}

class _SectionSelectionState extends State<SectionSelection> {
  String? selectedSection;
  
  final List<String> sections = [
    '101A',
    '101B',
    '101C',
    '101D',
    '101E',
    '101F',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: SizedBox(), // Remove back button
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
                _buildProgressLine(true),
                _buildProgressDot(true),
                _buildProgressLine(false),
                _buildProgressDot(false),
              ],
            ),
          ),
          
          SizedBox(height: 8),
          
          Text(
            'Select a Section',
            style: TextStyle(
              fontFamily: 'sans',
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Subject name
          Text(
            widget.subjectName,
            style: TextStyle(
              fontFamily: 'sans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          
          SizedBox(height: 20),
          
          // Sections grid
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    return _buildSectionCard(sections[index]);
                  },
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
                  if (selectedSection != null) {
                    var scName = selectedSection;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StudentScanner(sectionName: scName))
                    );
                  }
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
  
  Widget _buildSectionCard(String section) {
    bool isSelected = selectedSection == section;
    
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSection = section;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9068),
              Color(0xFFFF6B6B),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
            ? Border.all(color: Colors.blue, width: 3)
            : null,
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 12,
              right: 12,
              child: Icon(
                Icons.memory,
                color: Colors.white.withOpacity(0.7),
                size: 48,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  section,
                  style: TextStyle(
                    fontFamily: 'sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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