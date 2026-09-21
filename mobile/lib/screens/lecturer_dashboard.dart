import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uni_attend/screens/login.dart';

import '../services/api.dart';
// ignore: unused_import
import 'login_screen.dart';

class LecturerDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;

  const LecturerDashboard({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<LecturerDashboard> createState() =>
      _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  int selectedTab = 0;

  bool loading = true;
  bool generating = false;
  bool refreshingAttendance = false;

  String? errorMessage;

  List<Map<String, dynamic>> timetableData = [];

  Map<String, dynamic>? selectedClass;

  String? qrToken;
  int? sessionId;

  Timer? qrTimer;
  Timer? liveAttendanceTimer;

  int remainingSeconds = 0;

  List<Map<String, dynamic>> liveStudents = [];

  @override
  void initState() {
    super.initState();
    loadTimetable();
  }

  @override
  void dispose() {
    qrTimer?.cancel();
    liveAttendanceTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    qrTimer?.cancel();
    liveAttendanceTimer?.cancel();

    try {
      await Api.logout(widget.token);
    } catch (_) {
      // Even if the backend logout fails,
      // continue with local logout.
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // GET LOGGED-IN USER ID
  // ============================================================

  int? _getUserId() {
    final dynamic value = widget.user['id'];

    if (value == null) {
      return null;
    }

    return int.tryParse(value.toString());
  }

  // ============================================================
  // LOAD TIMETABLE
  // ============================================================

  Future<void> loadTimetable() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final dynamic response =
          await Api.timetable(widget.token);

      List<dynamic> loaded = [];

      if (response is List) {
        loaded = response;
      } else if (response is Map<String, dynamic>) {
        if (response['data'] is List) {
          loaded = response['data'];
        } else if (response['timetable'] is List) {
          loaded = response['timetable'];
        } else if (response['results'] is List) {
          loaded = response['results'];
        }
      }

      final List<Map<String, dynamic>> allClasses = loaded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      final int? lecturerId = _getUserId();

      List<Map<String, dynamic>> lecturerClasses;

      if (lecturerId == null) {
        lecturerClasses = allClasses;
      } else {
        lecturerClasses = allClasses.where((item) {
          dynamic value = item['lecturer_id'];

          if (value == null && item['course'] is Map) {
            value = item['course']['lecturer_id'];
          }

          if (value == null) {
            return false;
          }

          return int.tryParse(value.toString()) ==
              lecturerId;
        }).toList();
      }

      lecturerClasses.sort((a, b) {
        final String dayA =
            (a['day'] ?? '').toString().toLowerCase();

        final String dayB =
            (b['day'] ?? '').toString().toLowerCase();

        final int dayComparison =
            _dayOrder(dayA).compareTo(
          _dayOrder(dayB),
        );

        if (dayComparison != 0) {
          return dayComparison;
        }

        final String startA =
            (a['start'] ?? '').toString();

        final String startB =
            (b['start'] ?? '').toString();

        return startA.compareTo(startB);
      });

      if (!mounted) return;

      setState(() {
        timetableData = lecturerClasses;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = _cleanError(e);
      });
    }
  }

  // ============================================================
  // DAY ORDER
  // ============================================================

  int _dayOrder(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 1;
      case 'tuesday':
        return 2;
      case 'wednesday':
        return 3;
      case 'thursday':
        return 4;
      case 'friday':
        return 5;
      case 'saturday':
        return 6;
      case 'sunday':
        return 7;
      default:
        return 99;
    }
  }

  // ============================================================
  // COURSE ID
  // ============================================================

  int? _getCourseId(Map<String, dynamic> item) {
    dynamic value = item['course_id'];

    if (value == null && item['course'] is Map) {
      value = item['course']['id'];
    }

    if (value == null) {
      return null;
    }

    return int.tryParse(value.toString());
  }

  // ============================================================
  // TIMETABLE ID
  // ============================================================

  int? _getTimetableId(Map<String, dynamic> item) {
    dynamic value = item['timetable_id'];

    if (value == null) {
      value = item['id'];
    }

    if (value == null) {
      return null;
    }

    return int.tryParse(value.toString());
  }

  // ============================================================
  // COURSE CODE
  // ============================================================

  String _courseCode(Map<String, dynamic> item) {
    dynamic value = item['course_code'];

    if (value == null && item['course'] is Map) {
      value = item['course']['code'];
    }

    return value?.toString() ?? 'Unknown Course';
  }

  // ============================================================
  // COURSE TITLE
  // ============================================================

  String _courseTitle(Map<String, dynamic> item) {
    dynamic value = item['course_title'];

    if (value == null && item['course'] is Map) {
      value = item['course']['title'];
    }

    return value?.toString() ?? 'Course';
  }

  // ============================================================
  // VALUE
  // ============================================================

  String _value(
    Map<String, dynamic> item,
    String key, {
    String fallback = '-',
  }) {
    final dynamic value = item[key];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  // ============================================================
  // GENERATE QR
  // ============================================================

  Future<void> generateQr(
    Map<String, dynamic> classData,
  ) async {
    final int? courseId =
        _getCourseId(classData);

    final int? timetableId =
        _getTimetableId(classData);

    if (courseId == null) {
      _showError(
        'Unable to identify the course.',
      );
      return;
    }

    if (timetableId == null) {
      _showError(
        'Unable to identify the timetable entry.',
      );
      return;
    }

    qrTimer?.cancel();
    liveAttendanceTimer?.cancel();

    if (!mounted) return;

    setState(() {
      generating = true;
      errorMessage = null;
      selectedClass = classData;
      qrToken = null;
      sessionId = null;
      liveStudents = [];
      remainingSeconds = 0;
    });

    try {
      final dynamic response =
          await Api.createSession(
        widget.token,
        courseId,
        timetableId,
      );

      if (response is! Map) {
        throw Exception(
          'Invalid response from attendance server.',
        );
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(response);

      final dynamic tokenValue =
          data['token'];

      if (tokenValue == null ||
          tokenValue.toString().isEmpty) {
        throw Exception(
          'The server did not return a QR token.',
        );
      }

      final dynamic sessionValue =
          data['session_id'] ?? data['id'];

      final int? newSessionId =
          int.tryParse(
        sessionValue.toString(),
      );

      if (newSessionId == null) {
        throw Exception(
          'The server did not return a valid session ID.',
        );
      }

      int expiry = 300;

      final dynamic expiresIn =
          data['expires_in'];

      if (expiresIn != null) {
        expiry =
            int.tryParse(
              expiresIn.toString(),
            ) ??
            300;
      }

      if (expiry <= 0) {
        expiry = 300;
      }

      if (!mounted) return;

      setState(() {
        qrToken = tokenValue.toString();
        sessionId = newSessionId;
        remainingSeconds = expiry;
        generating = false;
        selectedTab = 2;
      });

      startQrTimer();
      startLiveAttendanceTimer();

      _showSuccess(
        'Attendance session started successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        generating = false;
        qrToken = null;
        sessionId = null;
      });

      _showError(
        'Unable to generate QR code: '
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // QR TIMER
  // ============================================================

  void startQrTimer() {
    qrTimer?.cancel();

    qrTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (remainingSeconds <= 1) {
          timer.cancel();

          setState(() {
            remainingSeconds = 0;
          });

          _showError(
            'The QR code has expired.',
          );

          endCurrentSession(
            showMessage: false,
          );

          return;
        }

        setState(() {
          remainingSeconds--;
        });
      },
    );
  }

  // ============================================================
  // LIVE ATTENDANCE TIMER
  // ============================================================

  void startLiveAttendanceTimer() {
    liveAttendanceTimer?.cancel();

    liveAttendanceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        if (sessionId != null) {
          refreshLiveStudents(
            silent: true,
          );
        } else {
          timer.cancel();
        }
      },
    );
  }

  // ============================================================
  // REFRESH STUDENTS
  // ============================================================

  Future<void> refreshLiveStudents({
    bool silent = false,
  }) async {
    if (sessionId == null) {
      return;
    }

    if (refreshingAttendance) {
      return;
    }

    if (!silent && mounted) {
      setState(() {
        refreshingAttendance = true;
      });
    } else {
      refreshingAttendance = true;
    }

    try {
      final dynamic response =
          await Api.liveStudents(
        widget.token,
        sessionId!,
      );

      List<dynamic> records = [];

      if (response is List) {
        records = response;
      } else if (response is Map<String, dynamic>) {
        if (response['data'] is List) {
          records = response['data'];
        } else if (response['students'] is List) {
          records = response['students'];
        } else if (response['records'] is List) {
          records = response['records'];
        }
      }

      final List<Map<String, dynamic>> students =
          records
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(item),
              )
              .toList();

      if (!mounted) return;

      setState(() {
        liveStudents = students;
        refreshingAttendance = false;
      });
    } catch (e) {
      refreshingAttendance = false;

      if (!silent && mounted) {
        _showError(
          'Unable to refresh attendance: '
          '${_cleanError(e)}',
        );
      }
    }
  }

  // ============================================================
  // END SESSION
  // ============================================================

  Future<void> endCurrentSession({
    bool showMessage = true,
  }) async {
    if (sessionId == null) {
      return;
    }

    final int endingSessionId = sessionId!;

    try {
      await Api.endSession(
        widget.token,
        endingSessionId,
      );

      qrTimer?.cancel();
      liveAttendanceTimer?.cancel();

      if (!mounted) return;

      setState(() {
        qrToken = null;
        sessionId = null;
        selectedClass = null;
        remainingSeconds = 0;
      });

      if (showMessage) {
        _showSuccess(
          'Attendance session ended successfully.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to end attendance session: '
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // CONFIRM END SESSION
  // ============================================================

  Future<void> _confirmEndSession() async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'End Attendance Session?',
          ),
          content: const Text(
            'Students will no longer be able to '
            'use this QR code to mark attendance.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'End Session',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await endCurrentSession();
    }
  }

  // ============================================================
  // FORMAT TIMER
  // ============================================================

  String _formatRemainingTime(
    int seconds,
  ) {
    final int minutes =
        seconds ~/ 60;

    final int secs =
        seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(dynamic error) {
    String message =
        error.toString();

    if (message.startsWith('Exception:')) {
      message =
          message
              .substring(
                'Exception:'.length,
              )
              .trim();
    }

    return message;
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lecturer Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh timetable',
            onPressed:
                loading
                    ? null
                    : loadTimetable,
            icon: const Icon(
              Icons.refresh,
            ),
          ),

          // ======================================================
          // LOGOUT BUTTON
          // ======================================================

          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _buildMainContent(),
      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            selectedTab,
        onDestinationSelected:
            (index) {
          setState(() {
            selectedTab = index;
          });

          if (index == 3 &&
              sessionId != null) {
            refreshLiveStudents();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.dashboard,
            ),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.calendar_month_outlined,
            ),
            selectedIcon: Icon(
              Icons.calendar_month,
            ),
            label: 'Timetable',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.qr_code_2_outlined,
            ),
            selectedIcon: Icon(
              Icons.qr_code_2,
            ),
            label: 'QR',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.people_outline,
            ),
            selectedIcon: Icon(
              Icons.people,
            ),
            label: 'Attendance',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildMainContent() {
    if (errorMessage != null &&
        timetableData.isEmpty) {
      return _buildErrorScreen();
    }

    switch (selectedTab) {
      case 1:
        return _buildTimetableScreen();

      case 2:
        return _buildQrScreen();

      case 3:
        return _buildAttendanceScreen();

      default:
        return _buildDashboardScreen();
    }
  }

  // ============================================================
  // ERROR SCREEN
  // ============================================================

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 70,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load timetable',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ??
                  'Unknown error',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed:
                  loadTimetable,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboardScreen() {
    return RefreshIndicator(
      onRefresh: loadTimetable,
      child: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildStatistics(),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Classes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedTab = 1;
                  });
                },
                child:
                    const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (timetableData.isEmpty)
            _buildEmptyTimetable()
          else
            ...timetableData
                .take(5)
                .map(
                  (item) =>
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child:
                        _classCard(
                      item,
                      compact: true,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    final String name =
        widget.user['full_name']
                ?.toString() ??
            'Lecturer';

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              child: Text(
                _initials(name),
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style:
                        const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Lecturer',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String _initials(String name) {
    final parts =
        name.trim().split(
              RegExp(r'\s+'),
            );

    if (parts.isEmpty) {
      return 'L';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length > 1
                ? 2
                : 1,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}'
            '${parts.last[0]}'
        .toUpperCase();
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.menu_book,
            title: 'Classes',
            value:
                timetableData.length
                    .toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.qr_code_2,
            title: 'QR Status',
            value:
                sessionId != null
                    ? 'ACTIVE'
                    : 'NONE',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.people,
            title: 'Present',
            value:
                liveStudents.length
                    .toString(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 10,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIMETABLE
  // ============================================================

  Widget _buildTimetableScreen() {
    return RefreshIndicator(
      onRefresh: loadTimetable,
      child: timetableData.isEmpty
          ? ListView(
              children: [
                const SizedBox(
                  height: 150,
                ),
                _buildEmptyTimetable(),
              ],
            )
          : ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: [
                const Text(
                  'My Complete Timetable',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select any class to start attendance.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ...timetableData.map(
                  (item) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child:
                        _classCard(item),
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // CLASS CARD
  // ============================================================

  Widget _classCard(
    Map<String, dynamic> item, {
    bool compact = false,
  }) {
    final String code =
        _courseCode(item);

    final String title =
        _courseTitle(item);

    final String day =
        _value(item, 'day');

    final String start =
        _value(item, 'start');

    final String end =
        _value(item, 'end');

    final String room =
        _value(item, 'room');

    final String block =
        _value(item, 'block');

    final String group =
        _value(item, 'group');

    final String mode =
        _value(item, 'class_mode');

    final bool isActive =
        item['is_active'] != false;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(
          compact ? 14 : 18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(
                    10,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary
                        .withValues(
                          alpha: 0.10,
                        ),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style:
                            TextStyle(
                          fontSize:
                              compact
                                  ? 16
                                  : 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        title,
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      color: Colors.green
                          .withValues(
                        alpha: 0.10,
                      ),
                    ),
                    child:
                        const Text(
                      'ACTIVE',
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.calendar_today,
                  day,
                ),
                _infoChip(
                  Icons.access_time,
                  '$start - $end',
                ),
                _infoChip(
                  Icons.location_on,
                  room,
                ),
                if (block != '-')
                  _infoChip(
                    Icons.domain,
                    'Block $block',
                  ),
                if (group != '-')
                  _infoChip(
                    Icons.groups,
                    group,
                  ),
                if (mode != '-')
                  _infoChip(
                    Icons.cast,
                    mode,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    generating
                        ? null
                        : () =>
                            generateQr(
                              item,
                            ),
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.qr_code_2,
                      ),
                label: Text(
                  generating
                      ? 'Starting Class...'
                      : 'Start Class & Generate QR',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(8),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style:
                const TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QR SCREEN
  // ============================================================

  Widget _buildQrScreen() {
    if (qrToken == null ||
        sessionId == null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2,
                size: 90,
                color:
                    Colors.grey.shade400,
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'No Active Attendance Session',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Go to the Timetable tab and select '
                'any class to generate an attendance QR code.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedTab = 1;
                  });
                },
                icon: const Icon(
                  Icons.calendar_month,
                ),
                label: const Text(
                  'Open Timetable',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final String code =
        selectedClass != null
            ? _courseCode(
                selectedClass!,
              )
            : 'Class';

    final String title =
        selectedClass != null
            ? _courseTitle(
                selectedClass!,
              )
            : '';

    final String day =
        selectedClass != null
            ? _value(
                selectedClass!,
                'day',
              )
            : '-';

    final String room =
        selectedClass != null
            ? _value(
                selectedClass!,
                'room',
              )
            : '-';

    final bool expired =
        remainingSeconds <= 0;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 45,
                    color: Colors.green,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Text(
                    'Attendance Session Active',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    '$code - $title',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    '$day • $room',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Padding(
              padding:
                  const EdgeInsets.all(25),
              child: Column(
                children: [
                  const Text(
                    'SCAN TO MARK ATTENDANCE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.all(
                      15,
                    ),
                    decoration:
                        BoxDecoration(
                      border: Border.all(
                        width: 2,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: QrImageView(
                      data: qrToken!,
                      version:
                          QrVersions.auto,
                      size: 280,
                      backgroundColor:
                          Colors.white,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Text(
                    expired
                        ? 'EXPIRED'
                        : _formatRemainingTime(
                            remainingSeconds,
                          ),
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight:
                          FontWeight.bold,
                      color: expired
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    expired
                        ? 'QR code expired'
                        : 'QR code expires in',
                    style:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    size: 35,
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Students Present',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          liveStudents
                              .length
                              .toString(),
                          style:
                              const TextStyle(
                            fontSize: 25,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        refreshingAttendance
                            ? null
                            : () =>
                                refreshLiveStudents(),
                    icon:
                        refreshingAttendance
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                              ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: const [
                  Text(
                    'Attendance Instructions',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '1. Display this QR code to students.',
                  ),
                  SizedBox(height: 6),
                  Text(
                    '2. Students scan the QR code.',
                  ),
                  SizedBox(height: 6),
                  Text(
                    '3. Students complete biometric verification.',
                  ),
                  SizedBox(height: 6),
                  Text(
                    '4. Attendance is recorded automatically.',
                  ),
                  SizedBox(height: 6),
                  Text(
                    '5. Monitor attendance from the Attendance tab.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child:
                ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed:
                  _confirmEndSession,
              icon: const Icon(
                Icons.stop_circle,
              ),
              label: const Text(
                'End Attendance Session',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE SCREEN
  // ============================================================

  Widget _buildAttendanceScreen() {
    if (sessionId == null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color:
                    Colors.grey.shade400,
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'No Active Attendance Session',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Start an attendance session from '
                'your timetable to view students here.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedTab = 1;
                  });
                },
                icon: const Icon(
                  Icons.calendar_month,
                ),
                label: const Text(
                  'Open Timetable',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          refreshLiveStudents(),
      child: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 27,
                    child: Icon(
                      Icons.people,
                    ),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Live Attendance',
                          style:
                              TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          selectedClass !=
                                  null
                              ? '${_courseCode(selectedClass!)} - '
                                '${_courseTitle(selectedClass!)}'
                              : 'Current class',
                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        refreshingAttendance
                            ? null
                            : () =>
                                refreshLiveStudents(),
                    icon:
                        refreshingAttendance
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                              ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'TOTAL PRESENT',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    liveStudents.length
                        .toString(),
                    style:
                        const TextStyle(
                      fontSize: 42,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (liveStudents.isEmpty)
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  30,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_search,
                      size: 60,
                      color: Colors
                          .grey.shade400,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'No students have marked attendance yet.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...liveStudents
                .asMap()
                .entries
                .map(
                  (entry) {
                    final int index =
                        entry.key;

                    final Map<String,
                            dynamic>
                        student =
                        entry.value;

                    return _studentAttendanceCard(
                      student,
                      index + 1,
                    );
                  },
                ),
          const SizedBox(
            height: 15,
          ),
          SizedBox(
            height: 50,
            width: double.infinity,
            child:
                ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed:
                  _confirmEndSession,
              icon: const Icon(
                Icons.stop_circle,
              ),
              label: const Text(
                'End Attendance Session',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget _studentAttendanceCard(
    Map<String, dynamic> student,
    int number,
  ) {
    final String name =
        student['student_name']
                ?.toString() ??
            student['full_name']
                ?.toString() ??
            'Student';

    final String studentNumber =
        student['student_number']
                ?.toString() ??
            '-';

    final String method =
        student['method']
                ?.toString() ??
            'QR+biometric';

    final String markedAt =
        student['marked_at']
                ?.toString() ??
            '-';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            number.toString(),
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const SizedBox(
              height: 3,
            ),
            Text(
              'Student ID: '
              '$studentNumber',
            ),
            const SizedBox(
              height: 2,
            ),
            Text(
              'Method: $method',
            ),
            const SizedBox(
              height: 2,
            ),
            Text(
              'Marked: $markedAt',
              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing:
            const Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY TIMETABLE
  // ============================================================

  Widget _buildEmptyTimetable() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.calendar_month,
              size: 65,
              color:
                  Colors.grey.shade400,
            ),
            const SizedBox(
              height: 15,
            ),
            const Text(
              'No timetable classes found.',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Make sure the admin has uploaded the '
              'Excel timetable and assigned courses '
              'to your lecturer account.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton.icon(
              onPressed:
                  loadTimetable,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Refresh Timetable',
              ),
            ),
          ],
        ),
      ),
    );
  }
}