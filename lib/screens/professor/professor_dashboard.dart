// lib/screens/professor/professor_dashboard.dart

import 'package:flutter/material.dart';
import 'package:Sentry/main.dart' show HomePage;
import 'package:Sentry/screens/professor/prof_subjects_page.dart';
import 'package:Sentry/screens/professor/prof_account_page.dart';

class ProfessorDashboard extends StatefulWidget {
  final Map<String, dynamic> professor;
  const ProfessorDashboard({super.key, required this.professor});

  @override
  State<ProfessorDashboard> createState() => _ProfessorDashboardState();
}

class _ProfessorDashboardState extends State<ProfessorDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ProfSubjectsPage(professor: widget.professor),
      ProfAccountPage(professor: widget.professor),
    ];
  }

  // ─────────────────────────────────────────────────────────────────
  // Back button → show logout dialog, NEVER go back to login screen
  // ─────────────────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    _showLogoutDialog();
    return false;
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LogoutDialog(
        onConfirm: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        // IndexedStack keeps each page alive — no rebuild on tab switch
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: _BottomNav(
          selectedIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared logout dialog — used in dashboard AND subjects page header button
// ─────────────────────────────────────────────────────────────────────────
class LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const LogoutDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFF1C2536), size: 26),
            ),
            const SizedBox(height: 16),
            const Text('Logout?',
                style: TextStyle(
                    color: Color(0xFF1C2536),
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to logout?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.45), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.06),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF1C2536),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Logout',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bottom nav bar
// ─────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.menu_book_rounded,
                label: 'Subjects',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.manage_accounts_rounded,
                label: 'Account',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.black.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected
                    ? const Color(0xFF1C2536)
                    : Colors.black.withOpacity(0.3),
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF1C2536)
                      : Colors.black.withOpacity(0.3),
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}