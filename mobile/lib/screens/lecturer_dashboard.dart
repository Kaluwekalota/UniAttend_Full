import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api.dart';

class LecturerDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;

  const LecturerDashboard({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  // ============================================================
  // STATE
  // ============================================================

  int selectedTab = 0;

  bool loading = true;
  bool generating = false;
  bool refreshingAttendance = false;
  bool generatingPdf = false;

  String? errorMessage;

  List<Map<String, dynamic>> timetableData = [];

  Map<String, dynamic>? selectedClass;

  String? qrToken;
  int? sessionId;

  Timer? qrTimer;
  Timer? liveAttendanceTimer;

  int remainingSeconds = 0;

  List<Map<String, dynamic>> liveStudents = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadTimetable();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    qrTimer?.cancel();
    liveAttendanceTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _logout() {
    qrTimer?.cancel();
    liveAttendanceTimer?.cancel();

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  // ============================================================
  // GET USER ID
  // ============================================================

  int? _getUserId() {
    final value = widget.user['id'];

    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
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
      final response = await Api.timetable(widget.token);

      final lecturerId = _getUserId();

      final List<Map<String, dynamic>> data = [];

      for (final item in response) {
        if (item is! Map) continue;

        final Map<String, dynamic> entry =
            Map<String, dynamic>.from(item);

        final dynamic entryLecturerId =
            entry['lecturer_id'] ??
                entry['lecturerId'] ??
                entry['course_lecturer_id'];

        bool belongsToLecturer = true;

        if (lecturerId != null && entryLecturerId != null) {
          int? parsedLecturerId;

          if (entryLecturerId is int) {
            parsedLecturerId = entryLecturerId;
          } else if (entryLecturerId is String) {
            parsedLecturerId = int.tryParse(entryLecturerId);
          }

          belongsToLecturer =
              parsedLecturerId == null ||
              parsedLecturerId == lecturerId;
        }

        if (belongsToLecturer) {
          data.add(entry);
        }
      }

      data.sort((a, b) {
        final dayA = _dayOrder(
          _value(a, ['day', 'weekday']),
        );

        final dayB = _dayOrder(
          _value(b, ['day', 'weekday']),
        );

        if (dayA != dayB) {
          return dayA.compareTo(dayB);
        }

        final startA = _value(
          a,
          ['start', 'start_time', 'startTime'],
        );

        final startB = _value(
          b,
          ['start', 'start_time', 'startTime'],
        );

        return startA.compareTo(startB);
      });

      if (!mounted) return;

      setState(() {
        timetableData = data;
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
    switch (day.toLowerCase().trim()) {
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

  int? _getCourseId(Map<String, dynamic> data) {
    dynamic value =
        data['course_id'] ??
            data['courseId'];

    if (value == null && data['course'] is Map) {
      final course = Map<String, dynamic>.from(
        data['course'],
      );

      value = course['id'];
    }

    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // TIMETABLE ID
  // ============================================================

  int? _getTimetableId(Map<String, dynamic> data) {
    dynamic value =
        data['timetable_id'] ??
            data['timetableId'] ??
            data['id'];

    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // COURSE CODE
  // ============================================================

  String _courseCode(Map<String, dynamic> data) {
    final direct = data['course_code'];

    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    if (data['code'] != null &&
        data['code'].toString().trim().isNotEmpty) {
      return data['code'].toString();
    }

    if (data['course'] is Map) {
      final course = Map<String, dynamic>.from(
        data['course'],
      );

      return course['code']?.toString() ?? 'COURSE';
    }

    return 'COURSE';
  }

  // ============================================================
  // COURSE TITLE
  // ============================================================

  String _courseTitle(Map<String, dynamic> data) {
    final direct =
        data['course_title'] ??
            data['course_name'] ??
            data['title'];

    if (direct != null &&
        direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    if (data['course'] is Map) {
      final course = Map<String, dynamic>.from(
        data['course'],
      );

      return course['title']?.toString() ??
          course['name']?.toString() ??
          'Course';
    }

    return 'Course';
  }

  // ============================================================
  // GENERIC VALUE
  // ============================================================

  String _value(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  // ============================================================
  // GENERATE QR
  // ============================================================

  Future<void> generateQr(
    Map<String, dynamic> classData,
  ) async {
    final courseId = _getCourseId(classData);
    final timetableId = _getTimetableId(classData);

    if (courseId == null) {
      _showError(
        'Could not determine the course ID.',
      );
      return;
    }

    if (timetableId == null) {
      _showError(
        'Could not determine the timetable ID.',
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
      liveStudents = [];
      qrToken = null;
      sessionId = null;
      remainingSeconds = 0;
    });

    try {
      final response = await Api.createSession(
        widget.token,
        courseId,
        timetableId,
      );

      final token = response['token']?.toString();

      dynamic responseSessionId =
          response['session_id'] ??
              response['id'];

      int? parsedSessionId;

      if (responseSessionId is int) {
        parsedSessionId = responseSessionId;
      } else if (responseSessionId is String) {
        parsedSessionId = int.tryParse(
          responseSessionId,
        );
      }

      if (token == null || token.trim().isEmpty) {
        throw Exception(
          'The server did not return a QR token.',
        );
      }

      if (parsedSessionId == null) {
        throw Exception(
          'The server did not return a valid session ID.',
        );
      }

      dynamic expiresIn =
          response['expires_in'] ??
              response['qr_expires_in'] ??
              response['duration'];

      int duration = 300;

      if (expiresIn is int) {
        duration = expiresIn;
      } else if (expiresIn is double) {
        duration = expiresIn.toInt();
      } else if (expiresIn is String) {
        duration = int.tryParse(expiresIn) ?? 300;
      }

      if (duration <= 0) {
        duration = 300;
      }

      if (!mounted) return;

      setState(() {
        qrToken = token;
        sessionId = parsedSessionId;
        remainingSeconds = duration;
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
        _cleanError(e),
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
      const Duration(seconds: 10),
      (_) {
        refreshLiveStudents();
      },
    );

    refreshLiveStudents();
  }

  // ============================================================
  // REFRESH LIVE STUDENTS
  // ============================================================

  Future<void> refreshLiveStudents() async {
    if (sessionId == null) return;

    if (refreshingAttendance) return;

    if (!mounted) return;

    setState(() {
      refreshingAttendance = true;
    });

    try {
      final response = await Api.liveStudents(
        widget.token,
        sessionId!,
      );

      final List<Map<String, dynamic>> students = [];

      for (final item in response) {
        if (item is Map) {
          students.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        liveStudents = students;
        refreshingAttendance = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        refreshingAttendance = false;
      });
    }
  }

  // ============================================================
  // END SESSION
  // ============================================================

  Future<void> endCurrentSession({
    bool showMessage = true,
  }) async {
    final endingSessionId = sessionId;

    if (endingSessionId == null) {
      return;
    }

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
        liveStudents = [];
        selectedTab = 1;
      });

      if (showMessage) {
        _showSuccess(
          'Attendance session ended successfully.',
        );
      }
    } catch (e) {
      if (showMessage) {
        _showError(
          _cleanError(e),
        );
      }
    }
  }

  // ============================================================
  // CONFIRM END SESSION
  // ============================================================

  Future<void> _confirmEndSession() async {
    if (sessionId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'End Attendance Session?',
          ),
          content: const Text(
            'Students will no longer be able to mark attendance using this session.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'End Session',
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await endCurrentSession();
    }
  }

  // ============================================================
  // GENERATE PDF REPORT
  // ============================================================

  Future<void> generatePdfReport() async {
    final currentSessionId = sessionId;

    if (currentSessionId == null) {
      _showError(
        'There is no active attendance session.',
      );
      return;
    }

    if (generatingPdf) return;

    if (!mounted) return;

    setState(() {
      generatingPdf = true;
    });

    try {
      final pdfBytes = await Api.downloadAttendancePdf(
        widget.token,
        currentSessionId,
      );

      final directory =
          await getApplicationDocumentsDirectory();

      final courseCode = _courseCode(
        selectedClass ?? {},
      );

      final safeCourseCode = courseCode
          .replaceAll(
            RegExp(r'[^a-zA-Z0-9_-]'),
            '_',
          );

      final fileName =
          '${safeCourseCode}_attendance_$currentSessionId.pdf';

      final file = File(
        '${directory.path}/$fileName',
      );

      await file.writeAsBytes(
        pdfBytes,
        flush: true,
      );

      if (!mounted) return;

      setState(() {
        generatingPdf = false;
      });

      _showSuccess(
        'PDF report generated successfully.',
      );

      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      if (!mounted) return;

      final result = await OpenFilex.open(
        file.path,
      );

      if (result.type != ResultType.done) {
        if (!mounted) return;

        _showError(
          'PDF was saved, but could not be opened automatically.\n\n'
          'File: ${file.path}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        generatingPdf = false;
      });

      _showError(
        _cleanError(e),
      );
    }
  }

  // ============================================================
  // FORMAT TIMER
  // ============================================================

  String _formatRemainingTime() {
    final minutes =
        remainingSeconds ~/ 60;

    final seconds =
        remainingSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(Object error) {
    String message = error.toString();

    if (message.startsWith('Exception:')) {
      message = message.substring(
        'Exception:'.length,
      );
    }

    return message.trim();
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        title: const Text(
          'Uni-Attend',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh timetable',
            onPressed: loading
                ? null
                : loadTimetable,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage != null
              ? _buildErrorScreen()
              : _buildMainContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          if (!mounted) return;

          setState(() {
            selectedTab = index;
          });
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
    switch (selectedTab) {
      case 0:
        return _buildDashboardScreen();

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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 70,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load timetable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: loadTimetable,
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
    final lecturerName =
        widget.user['full_name']?.toString() ??
            widget.user['name']?.toString() ??
            'Lecturer';

    return RefreshIndicator(
      onRefresh: loadTimetable,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(
            lecturerName,
          ),
          const SizedBox(height: 16),
          _buildStatistics(),
          const SizedBox(height: 20),
          const Text(
            'Your Classes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (timetableData.isEmpty)
            _buildEmptyTimetable()
          else
            ...timetableData
                .take(5)
                .map(
                  (item) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _classCard(
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

  Widget _buildWelcomeCard(
    String lecturerName,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF172033),
            Color(0xFF283B66),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor:
                Colors.white.withOpacity(0.15),
            child: Text(
              _initials(lecturerName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lecturerName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Manage your classes and attendance.',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'));

    if (parts.isEmpty) return 'L';

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

    return '${parts.first[0]}${parts.last[0]}'
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
            icon: Icons.calendar_today,
            title: 'Classes',
            value: timetableData.length
                .toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.people_alt_outlined,
            title: 'Present',
            value: liveStudents.length
                .toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.qr_code_2,
            title: 'Session',
            value: sessionId == null
                ? 'Off'
                : 'Live',
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
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF283B66),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIMETABLE SCREEN
  // ============================================================

  Widget _buildTimetableScreen() {
    return RefreshIndicator(
      onRefresh: loadTimetable,
      child: timetableData.isEmpty
          ? ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                _buildEmptyTimetable(),
              ],
            )
          : ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'My Timetable',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a scheduled class to start attendance.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                ...timetableData.map(
                  (item) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child: _classCard(item),
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
    final code = _courseCode(item);
    final title = _courseTitle(item);

    final day = _value(
      item,
      ['day', 'weekday'],
    );

    final start = _value(
      item,
      ['start', 'start_time', 'startTime'],
    );

    final end = _value(
      item,
      ['end', 'end_time', 'endTime'],
    );

    final room = _value(
      item,
      ['room', 'classroom'],
    );

    final block = _value(
      item,
      ['block'],
    );

    final group = _value(
      item,
      ['group_name', 'group', 'class_group'],
    );

    final mode = _value(
      item,
      ['class_mode', 'mode'],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFE9EEFF,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF283B66),
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
                      style: const TextStyle(
                        color:
                            Color(0xFF283B66),
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: compact ? 1 : 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (mode.isNotEmpty)
                _infoChip(
                  mode.toUpperCase(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (day.isNotEmpty)
                _infoChip(
                  day,
                  icon: Icons.today,
                ),
              if (start.isNotEmpty ||
                  end.isNotEmpty)
                _infoChip(
                  '$start - $end',
                  icon: Icons.access_time,
                ),
              if (room.isNotEmpty)
                _infoChip(
                  room,
                  icon: Icons.room_outlined,
                ),
              if (block.isNotEmpty)
                _infoChip(
                  block,
                  icon: Icons.apartment,
                ),
              if (group.isNotEmpty)
                _infoChip(
                  group,
                  icon: Icons.groups_outlined,
                ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: generating
                    ? null
                    : () => generateQr(item),
                icon: generating &&
                        selectedClass == item
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.qr_code_2,
                      ),
                label: Text(
                  generating &&
                          selectedClass == item
                      ? 'Starting Session...'
                      : 'Start Attendance',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _infoChip(
    String text, {
    IconData? icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F9),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight:
                  FontWeight.w500,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE9EEFF),
                  borderRadius:
                      BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 55,
                  color:
                      Color(0xFF283B66),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'No Active Attendance Session',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Go to your timetable and select a class to start attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
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

    final courseName =
        _courseCode(
      selectedClass ?? {},
    );

    final title =
        _courseTitle(
      selectedClass ?? {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Attendance QR Code',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$courseName • $title',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.08),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrToken!,
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor:
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'QR expires in',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatRemainingTime(),
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: remainingSeconds <= 30
                        ? Colors.red
                        : const Color(
                            0xFF283B66,
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${liveStudents.length} students present',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF283B66),
                ),
                SizedBox(height: 8),
                Text(
                  'Ask students to scan this QR code using Uni-Attend. They will complete biometric verification and, for physical classes, classroom location verification before attendance is recorded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmEndSession,
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: Colors.red,
              ),
              label: const Text(
                'End Attendance Session',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.red,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
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
    final hasSession = sessionId != null;

    return RefreshIndicator(
      onRefresh: refreshLiveStudents,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live Attendance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed:
                    refreshingAttendance
                        ? null
                        : refreshLiveStudents,
                icon: refreshingAttendance
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            hasSession
                ? 'Students who have successfully marked attendance.'
                : 'Start an attendance session to see live attendance.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),

          // ======================================================
          // ATTENDANCE SUMMARY
          // ======================================================

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE9F8EF),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.green,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveStudents.length
                            .toString(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Students Present',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasSession)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFE9F8EF),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // STUDENTS
          // ======================================================

          if (liveStudents.isEmpty)
            Container(
              padding:
                  const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    hasSession
                        ? 'No students have marked attendance yet.'
                        : 'No active attendance session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          else
            ...liveStudents.asMap().entries.map(
              (entry) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child:
                      _studentAttendanceCard(
                    entry.value,
                    entry.key + 1,
                  ),
                );
              },
            ),

          // ======================================================
          // PDF REPORT
          // ======================================================

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      color: Colors.red,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Attendance Report',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a PDF containing the attendance records for this session.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        sessionId == null ||
                                generatingPdf
                            ? null
                            : generatePdfReport,
                    icon: generatingPdf
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .picture_as_pdf,
                          ),
                    label: Text(
                      generatingPdf
                          ? 'Generating PDF...'
                          : 'Generate PDF Report',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.red.shade700,
                      foregroundColor:
                          Colors.white,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // END SESSION
          // ======================================================

          if (hasSession) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmEndSession,
                icon: const Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.red,
                ),
                label: const Text(
                  'End Attendance Session',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
                style:
                    OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Colors.red,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT ATTENDANCE CARD
  // ============================================================

  Widget _studentAttendanceCard(
    Map<String, dynamic> student,
    int number,
  ) {
    final studentName =
        student['full_name']?.toString() ??
            student['name']?.toString() ??
            student['student_name']?.toString() ??
            'Student';

    final studentId =
        student['student_id']?.toString() ??
            student['studentId']?.toString() ??
            student['id']?.toString() ??
            '';

    final markedAt =
        student['marked_at']?.toString() ??
            student['markedAt']?.toString() ??
            student['created_at']?.toString() ??
            '';

    final method =
        student['method']?.toString() ??
            'QR+biometric';

    final locationVerified =
        student['location_verified'] == true ||
            student['locationVerified'] == true;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                const Color(0xFFE9EEFF),
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Color(0xFF283B66),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (studentId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    studentId,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _smallStatusChip(
                      method,
                      Icons.fingerprint,
                    ),
                    if (locationVerified)
                      _smallStatusChip(
                        'Location verified',
                        Icons.location_on,
                      ),
                  ],
                ),
                if (markedAt.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    markedAt,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL STATUS CHIP
  // ============================================================

  Widget _smallStatusChip(
    String text,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F3),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.green.shade700,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY TIMETABLE
  // ============================================================

  Widget _buildEmptyTimetable() {
    return Container(
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 65,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Timetable Classes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No classes have been assigned to your lecturer account yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}