import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AdminApi {
  static const String baseUrl = 'http://localhost:8000';

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> headers(
    String token,
  ) {
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  // ============================================================
  // GENERIC REQUEST
  // ============================================================

  static Future<dynamic> request(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    late http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await http.get(
            uri,
            headers: headers(token),
          );
          break;

        case 'POST':
          response = await http.post(
            uri,
            headers: {
              ...headers(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body ?? {}),
          );
          break;

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
        'Could not connect to the server.\n$e',
      );
    }

    // ==========================================================
    // ERROR HANDLING
    // ==========================================================

    if (response.statusCode >= 400) {
      String message =
          'Request failed (${response.statusCode})';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded['detail'] != null) {
            message = decoded['detail'].toString();
          } else if (decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        }
      } catch (_) {}

      throw Exception(message);
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
  // ADMIN DASHBOARD
  // ============================================================

  static Future<Map<String, dynamic>> dashboard(
    String token,
  ) async {
    final response = await request(
      'GET',
      '/admin/dashboard',
      token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid dashboard response.',
    );
  }

  // ============================================================
  // ADMIN TIMETABLE
  // ============================================================

  static Future<List<dynamic>> timetable(
    String token,
  ) async {
    final response = await request(
      'GET',
      '/admin/timetable',
      token,
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
      'Invalid timetable response.',
    );
  }

  // ============================================================
  // UPLOAD EXCEL TIMETABLE
  // ============================================================

  static Future<Map<String, dynamic>> uploadTimetable(
    String token,
    String fileName,
    Uint8List bytes,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/admin/timetable/upload',
    );

    try {
      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.headers.addAll(
        headers(token),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      // ========================================================
      // UPLOAD ERROR
      // ========================================================

      if (response.statusCode >= 400) {
        String message =
            'Excel upload failed '
            '(${response.statusCode})';

        try {
          final decoded =
              jsonDecode(response.body);

          if (decoded is Map<String, dynamic> &&
              decoded['detail'] != null) {
            message =
                decoded['detail'].toString();
          }
        } catch (_) {}

        throw Exception(message);
      }

      // ========================================================
      // EMPTY RESPONSE
      // ========================================================

      if (response.body.isEmpty) {
        return {};
      }

      // ========================================================
      // RESPONSE
      // ========================================================

      final decoded =
          jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw Exception(
        'Invalid Excel upload response.',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Could not upload timetable.\n$e',
      );
    }
  }

  // ============================================================
  // DELETE TIMETABLE
  // ============================================================

  static Future<Map<String, dynamic>>
      deleteTimetable(
    String token,
    int timetableId,
  ) async {
    final response = await request(
      'DELETE',
      '/admin/timetable/$timetableId',
      token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {};
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout(
    String token,
  ) async {
    /*
     * UniAttend currently uses JWT authentication.
     *
     * JWT access tokens are stateless, so the client handles
     * logout by deleting the locally stored authentication
     * information.
     *
     * There is intentionally no /logout request here.
     */

    return;
  }
}