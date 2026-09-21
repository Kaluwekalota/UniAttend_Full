import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_attend/screens/login.dart';

import '../services/admin_api.dart';
import 'admin_timetable.dart';
// ignore: unused_import
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;

  const AdminDashboard({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<AdminDashboard> createState() =>
      _AdminDashboardState();
}

class _AdminDashboardState
    extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> stats;

  int tab = 0;

  @override
  void initState() {
    super.initState();

    stats = AdminApi.dashboard(
      widget.token,
    );
  }

  // ============================================================
  // REFRESH DASHBOARD
  // ============================================================

  void refresh() {
    setState(() {
      stats = AdminApi.dashboard(
        widget.token,
      );
    });
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Logout',
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              icon: const Icon(
                Icons.logout,
              ),
              label: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    // ==========================================================
    // REMOVE STORED LOGIN INFORMATION
    // ==========================================================

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.remove('token');
      await prefs.remove('access_token');
      await prefs.remove('user');
    } catch (_) {
      // Continue to login even if local cleanup fails.
    }

    // ==========================================================
    // OPTIONAL API LOGOUT
    // ==========================================================

    try {
      await AdminApi.logout(
        widget.token,
      );
    } catch (_) {
      // Ignore because JWT logout is handled locally.
    }

    if (!mounted) {
      return;
    }

    // ==========================================================
    // RETURN TO LOGIN
    // ==========================================================

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'UniAttend Admin',
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: logout,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: tab == 1
          ? AdminTimetable(
              token: widget.token,
            )
          : FutureBuilder<Map<String, dynamic>>(
              future: stats,
              builder: (context, snapshot) {
                // =================================================
                // LOADING
                // =================================================

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // =================================================
                // ERROR
                // =================================================

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 55,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          const Text(
                            'Unable to load admin dashboard.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Text(
                            '${snapshot.error}',
                            textAlign:
                                TextAlign.center,
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          ElevatedButton.icon(
                            onPressed: refresh,
                            icon: const Icon(
                              Icons.refresh,
                            ),
                            label: const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // =================================================
                // DATA
                // =================================================

                final x =
                    snapshot.data ?? {};

                return RefreshIndicator(
                  onRefresh: () async {
                    refresh();
                  },

                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),

                    padding:
                        const EdgeInsets.all(16),

                    children: [
                      // ===========================================
                      // WELCOME
                      // ===========================================

                      Text(
                        'Welcome, '
                        '${widget.user['full_name'] ?? 'Administrator'}',
                        style:
                            const TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      const Text(
                        'UniAttend Administration Panel',
                        style: TextStyle(
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ===========================================
                      // STATISTICS
                      // ===========================================

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _card(
                            'Students',
                            '${x['students'] ?? 0}',
                            Icons.school,
                          ),

                          _card(
                            'Lecturers',
                            '${x['lecturers'] ?? 0}',
                            Icons.person,
                          ),

                          _card(
                            'Courses',
                            '${x['courses'] ?? 0}',
                            Icons.menu_book,
                          ),

                          _card(
                            'Timetable',
                            '${x['timetable_entries'] ?? 0}',
                            Icons.calendar_month,
                          ),

                          _card(
                            'Attendance',
                            '${x['attendance_records'] ?? 0}',
                            Icons.fact_check,
                          ),

                          _card(
                            'Live Sessions',
                            '${x['active_sessions'] ?? 0}',
                            Icons.wifi_tethering,
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ===========================================
                      // TIMETABLE MANAGEMENT
                      // ===========================================

                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.calendar_month,
                          ),

                          title: const Text(
                            'Timetable Management',
                          ),

                          subtitle: const Text(
                            'Upload and manage the university timetable',
                          ),

                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                          ),

                          onTap: () {
                            setState(() {
                              tab = 1;
                            });
                          },
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // ===========================================
                      // LOGOUT CARD
                      // ===========================================

                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.logout,
                          ),

                          title: const Text(
                            'Logout',
                          ),

                          subtitle: const Text(
                            'Sign out of the administrator account',
                          ),

                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                          ),

                          onTap: logout,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                );
              },
            ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,

        onDestinationSelected: (index) {
          setState(() {
            tab = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard,
            ),
            label: 'Dashboard',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.calendar_month,
            ),
            label: 'Timetable',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTIC CARD
  // ============================================================

  Widget _card(
    String title,
    String value,
    IconData icon,
  ) {
    final width =
        MediaQuery.of(context).size.width;

    return SizedBox(
      width: width > 700
          ? 210
          : width / 2 - 24,

      child: Card(
        child: Padding(
          padding:
              const EdgeInsets.all(18),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                icon,
                size: 32,
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                title,
              ),
            ],
          ),
        ),
      ),
    );
  }
}