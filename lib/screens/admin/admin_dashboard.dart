// lib/screens/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Sentry/database/database_helper.dart';
import 'package:Sentry/screens/admin/manage_professors.dart';
import 'package:Sentry/screens/admin/manage_subjects.dart';
import 'package:Sentry/screens/admin/manage_sections.dart';
import 'package:Sentry/screens/admin/manage_students.dart';
import 'package:Sentry/screens/admin/admin_account_settings.dart';
import 'package:Sentry/main.dart' show HomePage;
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> admin;
  const AdminDashboard({super.key, required this.admin});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, int> _stats = {
    'professors': 0,
    'subjects': 0,
    'sections': 0,
    'students': 0,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getDashboardStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  Future<bool> _onWillPop() async {
    _showLogoutDialog();
    return false;
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C2536),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.redAccent, size: 26),
              ),
              const SizedBox(height: 16),
              const Text('Logout?',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B9DC3), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Color(0xFF8B9DC3),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomePage()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
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
      ),
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────
  void _goTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final adminName = widget.admin['full_name'] ?? 'Admin';

    // Stat card definitions — each carries its destination route
    final statItems = [
      {
        'label': 'Professors',
        'value': '${_stats['professors']}',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF00D4FF),
        'screen': const ManageProfessors(),
      },
      {
        'label': 'Subjects',
        'value': '${_stats['subjects']}',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF00E676),
        'screen': const ManageSubjects(),
      },
      {
        'label': 'Sections',
        'value': '${_stats['sections']}',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFFFFB800),
        'screen': const ManageSections(),
      },
      {
        'label': 'Students',
        'value': '${_stats['students']}',
        'icon': Icons.person_rounded,
        'color': const Color(0xFFB06EFF),
        'screen': const ManageStudents(),
      },
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadStats,
            color: const Color(0xFF00D4FF),
            backgroundColor: const Color(0xFF1C2536),
            child: CustomScrollView(
              slivers: [
                // ── Header ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d').format(now),
                              style: const TextStyle(
                                  color: Color(0xFF8B9DC3), fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hello, ${adminName.split(' ').first}! 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminAccountSettings(
                                      admin: widget.admin),
                                ),
                              ),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C2536),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFF1E2D45)),
                                ),
                                child: const Icon(
                                    Icons.manage_accounts_rounded,
                                    color: Color(0xFF00D4FF),
                                    size: 22),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _showLogoutDialog,
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.logout_rounded,
                                    color: Colors.redAccent, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Admin badge ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF0066CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('System Administrator',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    )),
                                Text(adminName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    )),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Stats (now tappable) ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                )),
                            Text('Tap to manage',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 11,
                                )),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF00D4FF)))
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final cardWidth =
                                      (constraints.maxWidth - 14) / 2;
                                  final cardHeight = cardWidth * 0.72;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      mainAxisExtent: cardHeight,
                                    ),
                                    itemCount: statItems.length,
                                    itemBuilder: (context, index) {
                                      final item = statItems[index];
                                      return _StatCard(
                                        label: item['label'] as String,
                                        value: item['value'] as String,
                                        icon: item['icon'] as IconData,
                                        color: item['color'] as Color,
                                        onTap: () => _goTo(
                                            item['screen'] as Widget),
                                      );
                                    },
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),

                // ── Quick Actions ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Manage',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 14),
                        _MenuTile(
                          icon: Icons.school_rounded,
                          color: const Color(0xFF00D4FF),
                          title: 'Professors',
                          subtitle: 'Add, edit, assign subjects',
                          onTap: () => _goTo(const ManageProfessors()),
                        ),
                        const SizedBox(height: 12),
                        _MenuTile(
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFF00E676),
                          title: 'Subjects',
                          subtitle: 'Create and manage subjects',
                          onTap: () => _goTo(const ManageSubjects()),
                        ),
                        const SizedBox(height: 12),
                        _MenuTile(
                          icon: Icons.groups_rounded,
                          color: const Color(0xFFFFB800),
                          title: 'Sections',
                          subtitle: 'Create sections, assign subjects',
                          onTap: () => _goTo(const ManageSections()),
                        ),
                        const SizedBox(height: 12),
                        _MenuTile(
                          icon: Icons.face_retouching_natural_rounded,
                          color: const Color(0xFFB06EFF),
                          title: 'Students',
                          subtitle: 'Register students & face records',
                          onTap: () => _goTo(const ManageStudents()),
                        ),
                        const SizedBox(height: 12),
                        _MenuTile(
                          icon: Icons.manage_accounts_rounded,
                          color: const Color(0xFFFF6B6B),
                          title: 'Account Settings',
                          subtitle: 'Face ID, password, profile',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminAccountSettings(
                                  admin: widget.admin),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap; // ← new
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2D45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                // Small arrow hint so users know it's tappable
                Icon(Icons.arrow_forward_ios_rounded,
                    color: color.withOpacity(0.45), size: 11),
              ],
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: TextStyle(
                            color: color,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF8B9DC3),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2D45)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF8B9DC3), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF8B9DC3), size: 14),
          ],
        ),
      ),
    );
  }
}