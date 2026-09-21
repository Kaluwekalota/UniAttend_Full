
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;

  const StudentDashboard({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<StudentDashboard> createState() =>
      _StudentDashboardState();
}

class _StudentDashboardState
    extends State<StudentDashboard> {

  int selectedIndex = 0;

  String? profileImagePath;

  final ImagePicker imagePicker =
      ImagePicker();

  Map<String, dynamic> get user =>
      widget.user;

  String get studentName {
    return (user['name'] ??
            user['full_name'] ??
            user['username'] ??
            'Student')
        .toString();
  }

  String get studentId {
    return (user['id'] ??
            user['student_id'] ??
            user['student_number'] ??
            'N/A')
        .toString();
  }

  String get programme {
    return (user['programme'] ??
            user['program'] ??
            'University Student')
        .toString();
  }

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  // ==========================================================
  // LOAD SAVED PROFILE PICTURE
  // ==========================================================

  Future<void> _loadProfilePicture() async {

    final prefs =
        await SharedPreferences.getInstance();

    final path =
        prefs.getString(
      'student_profile_picture_$studentId',
    );

    if (!mounted) return;

    if (path != null &&
        path.isNotEmpty &&
        File(path).existsSync()) {

      setState(() {
        profileImagePath = path;
      });
    }
  }

  // ==========================================================
  // SELECT PROFILE PICTURE FROM GALLERY
  // ==========================================================

  Future<void> _selectProfilePicture() async {

    try {

      final XFile? image =
          await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (image == null) {
        return;
      }

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        'student_profile_picture_$studentId',
        image.path,
      );

      if (!mounted) return;

      setState(() {
        profileImagePath = image.path;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Profile picture updated successfully.',
          ),
        ),
      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to select profile picture: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> _logout() async {

    final shouldLogout =
        await showDialog<bool>(
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
                'CANCEL',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'LOGOUT',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    // Remove authentication information.
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('role');

    if (!mounted) return;

    // Go back to login and remove
    // all previous screens.
    Navigator.of(context)
        .pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    final pages = [
      _buildDashboard(),
      _buildTimetablePage(),
      _buildAttendancePage(),
      _buildProfilePage(),
    ];

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'UniAttend',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,

        actions: [

          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: pages[selectedIndex],

      floatingActionButton:
          selectedIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: _openScanner,
                  icon: const Icon(
                    Icons.qr_code_scanner,
                  ),
                  label: const Text(
                    'Scan QR',
                  ),
                )
              : null,

      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            selectedIndex,

        onDestinationSelected:
            (index) {

          setState(() {
            selectedIndex = index;
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
              Icons.fact_check_outlined,
            ),
            selectedIcon: Icon(
              Icons.fact_check,
            ),
            label: 'Attendance',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  Widget _buildDashboard() {

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },

      child: ListView(
        padding:
            const EdgeInsets.all(18),

        children: [

          Text(
            'Welcome back,',
            style: TextStyle(
              fontSize: 16,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            studentName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            programme,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 25),

          Card(
            elevation: 2,

            child: Padding(
              padding:
                  const EdgeInsets.all(18),

              child: Row(
                children: [

                  _profileAvatar(
                    radius: 32,
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Text(
                          studentName,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          'Student ID: $studentId',
                          style: TextStyle(
                            color:
                                Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 58,

            child: FilledButton.icon(
              onPressed: _openScanner,

              icon: const Icon(
                Icons.qr_code_scanner,
                size: 28,
              ),

              label: const Text(
                'SCAN ATTENDANCE QR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _menuTile(
            Icons.calendar_month,
            'My Timetable',
            'View your class schedule',
            () {
              setState(() {
                selectedIndex = 1;
              });
            },
          ),

          _menuTile(
            Icons.fact_check,
            'Attendance History',
            'View attendance records',
            () {
              setState(() {
                selectedIndex = 2;
              });
            },
          ),

          _menuTile(
            Icons.person,
            'My Profile',
            'Manage your profile',
            () {
              setState(() {
                selectedIndex = 3;
              });
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PROFILE PAGE
  // ==========================================================

  Widget _buildProfilePage() {

    return ListView(
      padding:
          const EdgeInsets.all(18),

      children: [

        const SizedBox(height: 20),

        // ======================================================
        // PROFILE PHOTO
        // ======================================================

        Center(
          child: Stack(
            children: [

              _profileAvatar(
                radius: 65,
              ),

              Positioned(
                bottom: 0,
                right: 0,

                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .primary,

                  shape:
                      const CircleBorder(),

                  child: InkWell(
                    onTap:
                        _selectProfilePicture,

                    customBorder:
                        const CircleBorder(),

                    child: const Padding(
                      padding:
                          EdgeInsets.all(12),

                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: Text(
            'Tap the camera icon to change your photo',
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: Text(
            studentName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 5),

        Center(
          child: Text(
            programme,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
            ),
          ),
        ),

        const SizedBox(height: 30),

        _profileTile(
          Icons.badge,
          'Student ID',
          studentId,
        ),

        _profileTile(
          Icons.school,
          'Programme',
          programme,
        ),

        _profileTile(
          Icons.email,
          'Email',
          (user['email'] ??
                  'Not provided')
              .toString(),
        ),

        _profileTile(
          Icons.phone,
          'Phone',
          (user['phone'] ??
                  'Not provided')
              .toString(),
        ),

        const SizedBox(height: 25),

        // ======================================================
        // LOGOUT BUTTON
        // ======================================================

        SizedBox(
          width: double.infinity,
          height: 55,

          child: OutlinedButton.icon(
            onPressed: _logout,

            icon: const Icon(
              Icons.logout,
              color: Colors.red,
            ),

            label: const Text(
              'LOGOUT',
              style: TextStyle(
                color: Colors.red,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================
  // PROFILE AVATAR
  // ==========================================================

  Widget _profileAvatar({
    required double radius,
  }) {

    if (profileImagePath != null &&
        File(profileImagePath!)
            .existsSync()) {

      return CircleAvatar(
        radius: radius,

        backgroundImage:
            FileImage(
          File(profileImagePath!),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,

      child: Text(
        _initials(studentName),
        style: TextStyle(
          fontSize:
              radius * 0.45,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================================
  // TIMETABLE
  // ==========================================================

  Widget _buildTimetablePage() {

    return FutureBuilder<List<dynamic>>(
      future:
          Api.timetable(widget.token),

      builder:
          (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {

          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {

          return _errorCard(
            'Unable to load timetable.',
          );
        }

        final timetable =
            snapshot.data ?? [];

        if (timetable.isEmpty) {

          return const Center(
            child: Text(
              'No timetable available.',
            ),
          );
        }

        return ListView(
          padding:
              const EdgeInsets.all(18),

          children: [

            const Text(
              'My Timetable',
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            ...timetable.map(
              (item) =>
                  _timetableCard(item),
            ),
          ],
        );
      },
    );
  }

  Widget _timetableCard(
    dynamic item,
  ) {

    if (item is! Map) {
      return const SizedBox();
    }

    final course =
        (item['course_name'] ??
                item['course'] ??
                item['course_code'] ??
                'Course')
            .toString();

    final day =
        (item['day'] ??
                item['weekday'] ??
                'Day')
            .toString();

    final start =
        (item['start_time'] ??
                item['start'] ??
                '')
            .toString();

    final end =
        (item['end_time'] ??
                item['end'] ??
                '')
            .toString();

    final room =
        (item['room'] ??
                item['venue'] ??
                'Room not specified')
            .toString();

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.school,
          ),
        ),

        title: Text(
          course,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle: Text(
          '$day • $start - $end\n$room',
        ),
      ),
    );
  }

  // ==========================================================
  // ATTENDANCE
  // ==========================================================

  Widget _buildAttendancePage() {

    return FutureBuilder<List<dynamic>>(
      future:
          Api.myAttendance(widget.token),

      builder:
          (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {

          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {

          return _errorCard(
            'Unable to load attendance history.',
          );
        }

        final records =
            snapshot.data ?? [];

        return ListView(
          padding:
              const EdgeInsets.all(18),

          children: [

            const Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            if (records.isEmpty)
              const Center(
                child: Padding(
                  padding:
                      EdgeInsets.all(40),

                  child: Text(
                    'No attendance records found.',
                  ),
                ),
              ),

            ...records.map(
              (record) =>
                  _attendanceCard(record),
            ),
          ],
        );
      },
    );
  }

  Widget _attendanceCard(
    dynamic record,
  ) {

    if (record is! Map) {
      return const SizedBox();
    }

    final course =
        (record['course_name'] ??
                record['course'] ??
                record['course_code'] ??
                'Course')
            .toString();

    final date =
        (record['date'] ??
                record['attendance_date'] ??
                record['created_at'] ??
                '')
            .toString();

    final status =
        (record['status'] ??
                'Present')
            .toString();

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      child: ListTile(
        leading:
            const CircleAvatar(
          child: Icon(
            Icons.check,
          ),
        ),

        title: Text(
          course,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle: Text(date),

        trailing: Text(
          status,
          style: const TextStyle(
            color: Colors.green,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SCANNER
  // ==========================================================

  Future<void> _openScanner() async {

    final String? qrCode =
        await Navigator.push<String>(
      context,

      MaterialPageRoute(
        builder: (_) =>
            const QRScannerScreen(),
      ),
    );

    if (!mounted ||
        qrCode == null ||
        qrCode.trim().isEmpty) {
      return;
    }

    await _processAttendance(
      qrCode.trim(),
    );
  }

  // ==========================================================
  // ATTENDANCE PROCESS
  // ==========================================================

  Future<void> _processAttendance(
    String qrCode,
  ) async {

    final bool? biometricVerified =
        await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (_) =>
            const BiometricVerificationScreen(),
      ),
    );

    if (!mounted) return;

    if (biometricVerified != true) {

      _showMessage(
        'Fingerprint verification was not completed.',
        isError: true,
      );

      return;
    }

    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (_) {
        return const AlertDialog(
          content: Row(
            children: [

              CircularProgressIndicator(),

              SizedBox(width: 20),

              Expanded(
                child: Text(
                  'Validating attendance...',
                ),
              ),
            ],
          ),
        );
      },
    );

    try {

      final String key =
          const Uuid().v4();

      final response =
          await Api.mark(
        widget.token,
        int.tryParse(studentId) ?? 0,
        qrCode,
        key,
      );

      if (!mounted) return;

      Navigator.pop(context);

      await Navigator.push(
        context,

        MaterialPageRoute(
          builder: (_) =>
              AttendanceSuccessScreen(
            response: response,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {});

    } catch (e) {

      if (!mounted) return;

      Navigator.pop(context);

      Navigator.push(
        context,

        MaterialPageRoute(
          builder: (_) =>
              AttendanceFailedScreen(
            message: e
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  Widget _menuTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {

    return Card(
      child: ListTile(

        leading:
            CircleAvatar(
          child: Icon(icon),
        ),

        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle:
            Text(subtitle),

        trailing:
            const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),

        onTap: onTap,
      ),
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    String value,
  ) {

    return Card(
      child: ListTile(

        leading:
            Icon(icon),

        title: Text(
          title,
          style: TextStyle(
            color:
                Colors.grey.shade600,
          ),
        ),

        subtitle: Text(
          value,
          style:
              const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _errorCard(
    String message,
  ) {

    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          const Icon(
            Icons.cloud_off,
            size: 60,
          ),

          const SizedBox(height: 15),

          Text(message),

          const SizedBox(height: 15),

          FilledButton(
            onPressed: () {
              setState(() {});
            },

            child:
                const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  String _initials(
    String name,
  ) {

    final parts =
        name.trim().split(' ');

    if (parts.isEmpty) {
      return 'S';
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

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            isError
                ? Colors.red
                : null,
      ),
    );
  }
}


// ============================================================
// QR SCANNER
// ============================================================

class QRScannerScreen
    extends StatefulWidget {

  const QRScannerScreen({
    super.key,
  });

  @override
  State<QRScannerScreen>
      createState() =>
          _QRScannerScreenState();
}

class _QRScannerScreenState
    extends State<QRScannerScreen>
    with WidgetsBindingObserver {

  late final MobileScannerController
      controller;

  bool scanned = false;

  @override
  void initState() {

    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    controller =
        MobileScannerController(
      autoStart: true,
      detectionSpeed:
          DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {

    WidgetsBinding.instance
        .removeObserver(this);

    controller.dispose();

    super.dispose();
  }

  void _onDetect(
    BarcodeCapture capture,
  ) {

    if (scanned) return;

    for (final barcode
        in capture.barcodes) {

      final value =
          barcode.rawValue;

      if (value != null &&
          value.trim().isNotEmpty) {

        scanned = true;

        controller.stop();

        Navigator.pop(
          context,
          value.trim(),
        );

        return;
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      backgroundColor:
          Colors.black,

      appBar: AppBar(
        title: const Text(
          'Scan Attendance QR',
        ),

        actions: [

          IconButton(
            onPressed: () {
              controller
                  .toggleTorch();
            },

            icon: const Icon(
              Icons.flash_on,
            ),
          ),

          IconButton(
            onPressed: () {
              controller
                  .switchCamera();
            },

            icon: const Icon(
              Icons.cameraswitch,
            ),
          ),
        ],
      ),

      body: Stack(
        children: [

          MobileScanner(
            controller:
                controller,
            onDetect:
                _onDetect,
          ),

          Center(
            child: Container(
              width: 280,
              height: 280,

              decoration:
                  BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
            ),
          ),

          Positioned(
            top: 25,
            left: 20,
            right: 20,

            child: Container(
              padding:
                  const EdgeInsets.all(
                15,
              ),

              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withValues(alpha: 0.65),

                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),

              child: const Text(
                'Position the lecturer QR code inside the box.',
                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// BIOMETRIC VERIFICATION
// ============================================================

class BiometricVerificationScreen
    extends StatefulWidget {

  const BiometricVerificationScreen({
    super.key,
  });

  @override
  State<BiometricVerificationScreen>
      createState() =>
          _BiometricVerificationScreenState();
}

class _BiometricVerificationScreenState
    extends State<
        BiometricVerificationScreen> {

  final LocalAuthentication auth =
      LocalAuthentication();

  bool verifying = false;
  bool verified = false;

  String message =
      'Verify your identity using your fingerprint.';

  Future<void> verifyFingerprint() async {

    if (verifying || verified) {
      return;
    }

    setState(() {
      verifying = true;
      message =
          'Waiting for fingerprint verification...';
    });

    try {

      final supported =
          await auth.isDeviceSupported();

      final canCheck =
          await auth.canCheckBiometrics;

      if (!supported || !canCheck) {

        setState(() {
          verifying = false;
          message =
              'Biometric authentication is not available.';
        });

        return;
      }

      final available =
          await auth.getAvailableBiometrics();

      if (available.isEmpty) {

        setState(() {
          verifying = false;
          message =
              'No fingerprint is registered on this phone.';
        });

        return;
      }

      final authenticated =
          await auth.authenticate(
        localizedReason:
            'Verify your identity to record attendance.',

        options:
            const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {

        setState(() {
          verifying = false;
          verified = true;
          message =
              'Fingerprint verified successfully.';
        });

        await Future.delayed(
          const Duration(
            milliseconds: 700,
          ),
        );

        if (!mounted) return;

        Navigator.pop(
          context,
          true,
        );

      } else {

        setState(() {
          verifying = false;
          message =
              'Fingerprint verification failed.';
        });
      }

    } catch (e) {

      if (!mounted) return;

      setState(() {
        verifying = false;
        message =
            'Biometric verification failed.';
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'Identity Verification',
        ),

        centerTitle: true,
      ),

      body: Center(

        child: Padding(
          padding:
              const EdgeInsets.all(25),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              Container(
                width: 150,
                height: 150,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  color: verified
                      ? Colors.green
                          .withValues(
                          alpha: 0.12,
                        )
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(
                          alpha: 0.12,
                        ),
                ),

                child: Icon(
                  verified
                      ? Icons.verified_user
                      : Icons.fingerprint,

                  size: 90,

                  color: verified
                      ? Colors.green
                      : Theme.of(context)
                          .colorScheme
                          .primary,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              Text(
                verified
                    ? 'Identity Verified'
                    : 'Fingerprint Verification',

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  fontSize: 27,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              Text(
                message,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 55,

                child:
                    FilledButton.icon(
                  onPressed:
                      verifying ||
                              verified
                          ? null
                          : verifyFingerprint,

                  icon: verifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Icon(
                          verified
                              ? Icons.check
                              : Icons.fingerprint,
                        ),

                  label: Text(
                    verified
                        ? 'VERIFIED'
                        : verifying
                            ? 'VERIFYING...'
                            : 'VERIFY FINGERPRINT',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// SUCCESS SCREEN
// ============================================================

class AttendanceSuccessScreen
    extends StatelessWidget {

  final Map<String, dynamic>
      response;

  const AttendanceSuccessScreen({
    super.key,
    required this.response,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text('Attendance'),
        automaticallyImplyLeading:
            false,
      ),

      body: Center(

        child: Padding(
          padding:
              const EdgeInsets.all(25),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 110,
              ),

              const SizedBox(
                height: 25,
              ),

              const Text(
                'ATTENDANCE MARKED!',
                style:
                    TextStyle(
                  fontSize: 27,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              const Text(
                'Your attendance has been successfully recorded.',
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 55,

                child:
                    FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },

                  child:
                      const Text('DONE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// FAILED SCREEN
// ============================================================

class AttendanceFailedScreen
    extends StatelessWidget {

  final String message;

  const AttendanceFailedScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text('Attendance'),
      ),

      body: Center(

        child: Padding(
          padding:
              const EdgeInsets.all(25),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 100,
              ),

              const SizedBox(
                height: 25,
              ),

              const Text(
                'ATTENDANCE NOT RECORDED',
                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  fontSize: 23,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              Text(
                message,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 55,

                child:
                    FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },

                  child:
                      const Text('BACK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

