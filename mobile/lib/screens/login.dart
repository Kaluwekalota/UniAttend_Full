
import 'package:flutter/material.dart';

import '../services/api.dart';

import 'student_dashboard.dart';
import 'lecturer_dashboard.dart';
import 'admin_dashboard.dart';

// ================================================================
// UNIATTEND PROFESSIONAL NAVY BLUE THEME
// ================================================================

const Color primaryNavy = Color(0xFF0B1F3A);
const Color darkNavy = Color(0xFF07152A);
const Color navyBlue = Color(0xFF123B66);
const Color accentBlue = Color(0xFF2F80ED);
const Color lightBlue = Color(0xFFEAF2FB);

const Color pageBackground = Color(0xFFF4F7FB);
const Color textDark = Color(0xFF172B3F);
const Color textGrey = Color(0xFF718096);
const Color borderGrey = Color(0xFFDCE4ED);

// ================================================================
// LOGIN SCREEN
// ================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==============================================================
  // LOGIN
  // ==============================================================

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await Api.login(
        email,
        password,
      );

      final token =
          response['access_token'] ??
          response['token'];

      final user =
          response['user'] ??
          response['data'] ??
          response;

      if (token == null) {
        throw Exception(
          'No authentication token returned by server.',
        );
      }

      if (user is! Map) {
        throw Exception(
          'Invalid user information returned by server.',
        );
      }

      final Map<String, dynamic> userData =
          Map<String, dynamic>.from(user);

      final role =
          userData['role']?.toString().toLowerCase();

      if (!mounted) return;

      Widget screen;

      if (role == 'student') {
        screen = StudentDashboard(
          user: userData,
          token: token.toString(),
        );
      } else if (role == 'lecturer') {
        screen = LecturerDashboard(
          user: userData,
          token: token.toString(),
        );
      } else if (role == 'admin') {
        screen = AdminDashboard(
          user: userData,
          token: token.toString(),
        );
      } else {
        throw Exception(
          'Unknown user role: $role',
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => screen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==============================================================
  // OPEN REGISTRATION
  // ==============================================================

  void openRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistrationScreen(),
      ),
    );
  }

  // ==============================================================
  // MESSAGE
  // ==============================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        duration: const Duration(seconds: 3),
        backgroundColor: primaryNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 30,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 470,
              ),
              child: _buildLoginCard(),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // LOGIN CARD
  // ==============================================================

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: borderGrey,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryNavy.withValues(
              alpha: 0.09,
            ),
            blurRadius: 35,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // ========================================================
          // NAVY HEADER
          // ========================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              25,
              34,
              25,
              30,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  darkNavy,
                  primaryNavy,
                  navyBlue,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: _buildUniAttendHeader(),
          ),

          // ========================================================
          // LOGIN CONTENT
          // ========================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              30,
              30,
              30,
              28,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Sign in to continue to your UniAttend account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textGrey,
                  ),
                ),

                const SizedBox(height: 30),

                _buildFieldLabel('Email Address'),

                const SizedBox(height: 8),

                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.next,
                  decoration: _inputDecoration(
                    hint: 'Enter your email address',
                    icon: Icons.email_outlined,
                  ),
                ),

                const SizedBox(height: 20),

                _buildFieldLabel('Password'),

                const SizedBox(height: 8),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction:
                      TextInputAction.done,
                  onSubmitted: (_) => login(),
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                              !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: primaryNavy,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // SIGN IN
                // ==================================================

                SizedBox(
                  height: 55,
                  child: FilledButton(
                    onPressed:
                        loading ? null : login,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryNavy,
                      disabledBackgroundColor:
                          const Color(0xFF9AA9B9),
                      elevation: 2,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.login_rounded,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 27),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      child: Text(
                        'NEW USER?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                          color: textGrey,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==================================================
                // CREATE ACCOUNT
                // ==================================================

                OutlinedButton(
                  onPressed:
                      loading
                          ? null
                          : openRegistration,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor: primaryNavy,
                    side: const BorderSide(
                      color: primaryNavy,
                      width: 1.3,
                    ),
                    minimumSize:
                        const Size(
                      double.infinity,
                      51,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'CREATE ACCOUNT',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'UNIATTEND',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: primaryNavy,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'SMART ATTENDANCE • SECURE • SIMPLE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: textGrey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // UNIATTEND HEADER
  // ==============================================================

  Widget _buildUniAttendHeader() {
    return Column(
      children: [
        // ----------------------------------------------------------
        // PROFESSIONAL SYSTEM ICON
        // ----------------------------------------------------------

        Container(
          width: 94,
          height: 94,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.15,
                ),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 51,
                color: primaryNavy,
              ),

              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: accentBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'UNIATTEND',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),

        const SizedBox(height: 7),

        Container(
          width: 65,
          height: 3,
          decoration: BoxDecoration(
            color: accentBlue,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'SMART ATTENDANCE MANAGEMENT SYSTEM',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // FIELD LABEL
  // ==============================================================

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
    );
  }

  // ==============================================================
  // INPUT DECORATION
  // ==============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: primaryNavy,
      ),

      suffixIcon: suffixIcon,

      filled: true,

      fillColor: const Color(0xFFF7F9FC),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: borderGrey,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: accentBlue,
          width: 1.6,
        ),
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 17,
        horizontal: 16,
      ),
    );
  }
}

// ==================================================================
// REGISTRATION SCREEN
// ==================================================================

class RegistrationScreen
    extends StatefulWidget {
  const RegistrationScreen({
    super.key,
  });

  @override
  State<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState
    extends State<RegistrationScreen> {
  final nameController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final studentIdController =
      TextEditingController();

  final staffIdController =
      TextEditingController();

  final programmeController =
      TextEditingController();

  String role = 'student';

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    studentIdController.dispose();
    staffIdController.dispose();
    programmeController.dispose();

    super.dispose();
  }

  // ==============================================================
  // REGISTER
  // ==============================================================

  Future<void> register() async {
    final name =
        nameController.text.trim();

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showMessage(
        'Please fill in all required fields.',
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (role == 'student' &&
        studentIdController.text
            .trim()
            .isEmpty) {
      showMessage(
        'Please enter your student ID.',
      );
      return;
    }

    if (role == 'lecturer' &&
        staffIdController.text
            .trim()
            .isEmpty) {
      showMessage(
        'Please enter your staff ID.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final Map<String, dynamic> data = {
        'full_name': name,
        'email': email,
        'password': password,
        'role': role,
      };

      if (role == 'student') {
        data['student_id'] =
            studentIdController.text.trim();

        data['programme'] =
            programmeController.text.trim();
      } else {
        data['staff_id'] =
            staffIdController.text.trim();
      }

      await Api.register(data);

      if (!mounted) return;

      showMessage(
        'Registration successful. Please login.',
      );

      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==============================================================
  // MESSAGE
  // ==============================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        margin:
            const EdgeInsets.all(16),
        backgroundColor: primaryNavy,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final isStudent =
        role == 'student';

    return Scaffold(
      backgroundColor:
          pageBackground,

      appBar: AppBar(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Create Account',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),

          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 520,
              ),

              child: Container(
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    26,
                  ),
                  border: Border.all(
                    color:
                        borderGrey,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          primaryNavy
                              .withValues(
                        alpha: 0.08,
                      ),
                      blurRadius: 30,
                      offset:
                          const Offset(
                        0,
                        12,
                      ),
                    ),
                  ],
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    28,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,

                    children: [
                      // =================================================
                      // UNIATTEND ICON
                      // =================================================

                      Center(
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration:
                              BoxDecoration(
                            gradient:
                                const LinearGradient(
                              colors: [
                                darkNavy,
                                navyBlue,
                              ],
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              25,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    primaryNavy
                                        .withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius:
                                    15,
                                offset:
                                    const Offset(
                                  0,
                                  7,
                                ),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment:
                                Alignment
                                    .center,
                            children: [
                              const Icon(
                                Icons
                                    .qr_code_scanner_rounded,
                                color:
                                    Colors.white,
                                size: 48,
                              ),
                              Positioned(
                                right: 9,
                                bottom: 9,
                                child:
                                    Container(
                                  width: 27,
                                  height: 27,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        accentBlue,
                                    shape:
                                        BoxShape
                                            .circle,
                                    border:
                                        Border.all(
                                      color:
                                          Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .check_rounded,
                                    color:
                                        Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'UNIATTEND',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              primaryNavy,
                          fontSize: 22,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing:
                              2,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      const Text(
                        'Create your account',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              textDark,
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      const Text(
                        'Register to access the smart attendance system.',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              textGrey,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // =================================================
                      // ACCOUNT TYPE
                      // =================================================

                      _buildLabel(
                        'Account Type',
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value:
                                'student',
                            icon: Icon(
                              Icons
                                  .school_outlined,
                            ),
                            label:
                                Text(
                              'Student',
                            ),
                          ),
                          ButtonSegment<String>(
                            value:
                                'lecturer',
                            icon: Icon(
                              Icons
                                  .person_outline,
                            ),
                            label:
                                Text(
                              'Lecturer',
                            ),
                          ),
                        ],
                        selected: {role},
                        onSelectionChanged:
                            (selection) {
                          setState(() {
                            role =
                                selection
                                    .first;
                          });
                        },
                        style:
                            ButtonStyle(
                          foregroundColor:
                              WidgetStateProperty
                                  .resolveWith(
                            (states) {
                              if (states
                                  .contains(
                                WidgetState
                                    .selected,
                              )) {
                                return Colors
                                    .white;
                              }

                              return primaryNavy;
                            },
                          ),
                          backgroundColor:
                              WidgetStateProperty
                                  .resolveWith(
                            (states) {
                              if (states
                                  .contains(
                                WidgetState
                                    .selected,
                              )) {
                                return primaryNavy;
                              }

                              return Colors
                                  .white;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      // =================================================
                      // FULL NAME
                      // =================================================

                      _buildLabel(
                        'Full Name *',
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                            nameController,
                        decoration:
                            _registrationInput(
                          hint:
                              'Enter your full name',
                          icon:
                              Icons
                                  .person_outline,
                        ),
                      ),

                      const SizedBox(
                        height: 17,
                      ),

                      // =================================================
                      // EMAIL
                      // =================================================

                      _buildLabel(
                        'Email Address *',
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                            emailController,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        decoration:
                            _registrationInput(
                          hint:
                              'Enter your email address',
                          icon:
                              Icons
                                  .email_outlined,
                        ),
                      ),

                      const SizedBox(
                        height: 17,
                      ),

                      // =================================================
                      // STUDENT FIELDS
                      // =================================================

                      if (isStudent) ...[
                        _buildLabel(
                          'Student ID *',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        TextField(
                          controller:
                              studentIdController,
                          decoration:
                              _registrationInput(
                            hint:
                                'Enter your student ID',
                            icon:
                                Icons
                                    .badge_outlined,
                          ),
                        ),

                        const SizedBox(
                          height: 17,
                        ),

                        _buildLabel(
                          'Programme',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        TextField(
                          controller:
                              programmeController,
                          decoration:
                              _registrationInput(
                            hint:
                                'Enter your programme',
                            icon:
                                Icons
                                    .menu_book_outlined,
                          ),
                        ),

                        const SizedBox(
                          height: 17,
                        ),
                      ],

                      // =================================================
                      // LECTURER FIELD
                      // =================================================

                      if (!isStudent) ...[
                        _buildLabel(
                          'Staff ID *',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        TextField(
                          controller:
                              staffIdController,
                          decoration:
                              _registrationInput(
                            hint:
                                'Enter your staff ID',
                            icon:
                                Icons
                                    .badge_outlined,
                          ),
                        ),

                        const SizedBox(
                          height: 17,
                        ),
                      ],

                      // =================================================
                      // PASSWORD
                      // =================================================

                      _buildLabel(
                        'Password *',
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                            passwordController,
                        obscureText:
                            obscurePassword,
                        decoration:
                            _registrationInput(
                          hint:
                              'Create a password',
                          icon:
                              Icons
                                  .lock_outline,
                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword =
                                    !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                              color:
                                  primaryNavy,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // =================================================
                      // REGISTER
                      // =================================================

                      SizedBox(
                        height: 54,
                        child:
                            FilledButton(
                          onPressed:
                              loading
                                  ? null
                                  : register,
                          style:
                              FilledButton
                                  .styleFrom(
                            backgroundColor:
                                primaryNavy,
                            disabledBackgroundColor:
                                const Color(
                              0xFF9AA9B9,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                13,
                              ),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.5,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Icon(
                                      Icons
                                          .person_add_alt_1_rounded,
                                      size:
                                          20,
                                    ),
                                    SizedBox(
                                      width:
                                          10,
                                    ),
                                    Text(
                                      'CREATE ACCOUNT',
                                      style:
                                          TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        fontSize:
                                            14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      TextButton(
                        onPressed:
                            loading
                                ? null
                                : () =>
                                    Navigator.pop(
                                      context,
                                    ),
                        child: const Text(
                          'Already have an account? Sign In',
                          style: TextStyle(
                            color:
                                primaryNavy,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      const Text(
                        'UNIATTEND • SMART ATTENDANCE',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color:
                              textGrey,
                          letterSpacing:
                              0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // LABEL
  // ==============================================================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
    );
  }

  // ==============================================================
  // REGISTRATION INPUT
  // ==============================================================

  InputDecoration _registrationInput({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: primaryNavy,
      ),

      suffixIcon: suffixIcon,

      filled: true,

      fillColor:
          const Color(0xFFF7F9FC),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: borderGrey,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: accentBlue,
          width: 1.6,
        ),
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 17,
        horizontal: 16,
      ),
    );
  }
}

