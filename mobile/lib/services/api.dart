import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  // ============================================================
  // BASE URL
  // ============================================================
  //
  // Flutter Web on the same computer:
  // http://localhost:8000
  //
  // Android Emulator:
  // http://10.0.2.2:8000
  //
  // Physical Android phone:
  // http://YOUR_PC_IP_ADDRESS:8000
  //
  static const String baseUrl =
    'https://uniattend-backend-gu8b.onrender.com';
  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> headers([String? token]) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',

      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // GENERAL REQUEST METHOD
  // ============================================================

  static Future<dynamic> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    late http.Response response;

    try {
      switch (method.toUpperCase()) {
        // ------------------------------------------------------
        // GET
        // ------------------------------------------------------

        case 'GET':
          response = await http.get(
            uri,
            headers: headers(token),
          );
          break;

        // ------------------------------------------------------
        // POST
        // ------------------------------------------------------

        case 'POST':
          response = await http.post(
            uri,
            headers: headers(token),
            body: jsonEncode(body ?? {}),
          );
          break;

        // ------------------------------------------------------
        // PUT
        // ------------------------------------------------------

        case 'PUT':
          response = await http.put(
            uri,
            headers: headers(token),
            body: jsonEncode(body ?? {}),
          );
          break;

        // ------------------------------------------------------
        // PATCH
        // ------------------------------------------------------

        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers(token),
            body: jsonEncode(body ?? {}),
          );
          break;

        // ------------------------------------------------------
        // DELETE
        // ------------------------------------------------------

        case 'DELETE':
          response = await http.delete(
            uri,
            headers: headers(token),
          );
          break;

        default:
          throw Exception(
            'Unsupported HTTP method: $method',
          );
      }
    } catch (e) {
      throw Exception(
        'Could not connect to the server.\n\n'
        'Make sure the FastAPI server is running.\n\n'
        '$e',
      );
    }

    // ==========================================================
    // HANDLE HTTP ERRORS
    // ==========================================================

    if (response.statusCode >= 400) {
      String message = 'Request failed';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded['detail'] != null) {
            message = decoded['detail'].toString();
          } else if (decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } else if (decoded is String) {
          message = decoded;
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          message = response.body;
        }
      }

      throw Exception(
        '$message (${response.statusCode})',
      );
    }

    // ==========================================================
    // EMPTY RESPONSE
    // ==========================================================

    if (response.body.isEmpty) {
      return {};
    }

    // ==========================================================
    // JSON RESPONSE
    // ==========================================================

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await request(
      'POST',
      '/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid login response received from server.',
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    final response = await request(
      'POST',
      '/auth/register',
      body: data,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid registration response received from server.',
    );
  }

  // ============================================================
  // CURRENT USER / PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> myProfile(
    String token,
  ) async {
    final response = await request(
      'GET',
      '/auth/me',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid profile data returned by server.',
    );
  }

  // ============================================================
  // STUDENT / USER TIMETABLE
  // ============================================================

  static Future<List<dynamic>> timetable(
    String token,
  ) async {
    final response = await request(
      'GET',
      '/timetable',
      token: token,
    );

    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map<String, dynamic> &&
        response['data'] is List) {
      return List<dynamic>.from(
        response['data'],
      );
    }

    throw Exception(
      'Invalid timetable data returned by server.',
    );
  }

  // ============================================================
  // TIMETABLE BY DAY
  // ============================================================

  static Future<List<dynamic>> timetableByDay(
    String token,
    String day,
  ) async {
    final encodedDay = Uri.encodeComponent(day);

    final response = await request(
      'GET',
      '/timetable/day/$encodedDay',
      token: token,
    );

    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map<String, dynamic> &&
        response['data'] is List) {
      return List<dynamic>.from(
        response['data'],
      );
    }

    throw Exception(
      'Invalid timetable data returned by server.',
    );
  }

  // ============================================================
  // LECTURER TODAY'S CLASSES
  // ============================================================

  static Future<List<dynamic>> lecturerToday(
    String token,
  ) async {
    final response = await request(
      'GET',
      '/lecturer/today',
      token: token,
    );

    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map<String, dynamic> &&
        response['data'] is List) {
      return List<dynamic>.from(
        response['data'],
      );
    }

    throw Exception(
      'Invalid lecturer timetable returned by server.',
    );
  }

  // ============================================================
  // MY ATTENDANCE
  // ============================================================

  static Future<List<dynamic>> myAttendance(
    String token,
  ) async {
    final response = await request(
      'GET',
      '/attendance/my',
      token: token,
    );

    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map<String, dynamic> &&
        response['data'] is List) {
      return List<dynamic>.from(
        response['data'],
      );
    }

    throw Exception(
      'Invalid attendance data returned by server.',
    );
  }

  // ============================================================
  // CREATE REAL ATTENDANCE SESSION
  // ============================================================
  //
  // IMPORTANT:
  //
  // The lecturer must provide BOTH:
  //
  // courseId
  // timetableId
  //
  // The backend then checks:
  //
  // 1. Lecturer owns the course
  // 2. Timetable belongs to the course
  // 3. Today matches the timetable
  // 4. Current time is within the class
  // 5. A valid QR session is created
  //
  // The returned "token" is the REAL QR value.
  //
  static Future<Map<String, dynamic>> createSession(
    String token,
    int courseId,
    int timetableId,
  ) async {
    final response = await request(
      'POST',
      '/attendance/sessions'
          '?course_id=$courseId'
          '&timetable_id=$timetableId',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid attendance session response '
      'received from server.',
    );
  }

  // ============================================================
  // ROTATE QR CODE
  // ============================================================

  static Future<Map<String, dynamic>> rotateQr(
    String token,
    int sessionId,
  ) async {
    final response = await request(
      'POST',
      '/attendance/sessions/$sessionId/rotate',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid QR rotation response received '
      'from server.',
    );
  }

  // ============================================================
  // END ATTENDANCE SESSION
  // ============================================================

  static Future<Map<String, dynamic>> endSession(
    String token,
    int sessionId,
  ) async {
    final response = await request(
      'POST',
      '/attendance/sessions/$sessionId/end',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid end-session response received '
      'from server.',
    );
  }

  // ============================================================
  // GET STUDENTS WHO MARKED ATTENDANCE
  // ============================================================

  static Future<List<dynamic>> liveStudents(
    String token,
    int sessionId,
  ) async {
    final response = await request(
      'GET',
      '/attendance/session/$sessionId/students',
      token: token,
    );

    if (response is List) {
      return List<dynamic>.from(response);
    }

    if (response is Map<String, dynamic> &&
        response['data'] is List) {
      return List<dynamic>.from(
        response['data'],
      );
    }

    throw Exception(
      'Invalid live attendance data returned '
      'from server.',
    );
  }

  // ============================================================
  // MARK ATTENDANCE
  // ============================================================
  //
  // Student scans lecturer QR.
  //
  // The QR contains the attendance session token.
  //
  // The student then completes biometric verification
  // in the Flutter application.
  //
  // After successful biometric verification, Flutter
  // calls this method.
  //
  static Future<Map<String, dynamic>> mark(
    String token,
    int studentId,
    String qr,
    String key, {
    String method = 'QR+biometric',
  }) async {
    if (qr.trim().isEmpty) {
      throw Exception(
        'The QR code is empty or invalid.',
      );
    }

    if (studentId <= 0) {
      throw Exception(
        'Invalid student ID.',
      );
    }

    if (key.trim().isEmpty) {
      throw Exception(
        'Invalid attendance request key.',
      );
    }

    final response = await request(
      'POST',
      '/attendance/mark',
      token: token,
      body: {
        'session_token': qr.trim(),
        'student_id': studentId,
        'idempotency_key': key,
        'method': method,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid attendance response received '
      'from server.',
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  //
  // JWT logout is currently handled locally by Flutter.
  //
  // The application should remove:
  //
  // - access token
  // - logged-in user information
  //
  // from SharedPreferences.
  //
  static Future<void> logout(
    String token,
  ) async {
    return;
  }
}