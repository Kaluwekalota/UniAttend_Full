import 'dart:convert';
import 'package:http/http.dart' as http;

class AcademicApi {
  static const String baseUrl='http://localhost:8000';
  static Map<String,String> headers(String token)=>{'Content-Type':'application/json','Authorization':'Bearer $token'};

  static Future<dynamic> req(String method,String path,String token,{Object? body})async{
    final u=Uri.parse('$baseUrl$path');late http.Response r;
    if(method=='GET')r=await http.get(u,headers:headers(token));
    else if(method=='POST')r=await http.post(u,headers:headers(token),body:body);
    else if(method=='PATCH')r=await http.patch(u,headers:headers(token),body:body);
    else if(method=='DELETE')r=await http.delete(u,headers:headers(token));
    else throw Exception('Unsupported method');
    if(r.statusCode>=400){
      try{throw Exception(jsonDecode(r.body)['detail']??'Request failed');}
      catch(e){if(e.toString().startsWith('Exception:'))rethrow;throw Exception('Request failed (${r.statusCode})');}
    }
    return r.body.isEmpty?{}:jsonDecode(r.body);
  }
  static Future<List<dynamic>> lecturers(String t)async=>List<dynamic>.from(await req('GET','/admin/lecturers',t));
  static Future<List<dynamic>> students(String t)async=>List<dynamic>.from(await req('GET','/admin/students',t));
  static Future<List<dynamic>> courses(String t)async=>List<dynamic>.from(await req('GET','/admin/courses',t));
  static Future<List<dynamic>> timetable(String t)async=>List<dynamic>.from(await req('GET','/admin/timetable',t));

  static Future<dynamic> createCourse(String t,Map<String,dynamic> body)async=>req('POST','/admin/courses',t,body:jsonEncode(body));
  static Future<dynamic> updateCourse(String t,int id,Map<String,dynamic> body)async=>req('PATCH','/admin/courses/$id',t,body:jsonEncode(body));
  static Future<dynamic> enroll(String t,int studentId,int courseId)async=>req('POST','/admin/enrollments',t,body:jsonEncode({'student_id':studentId,'course_id':courseId}));
  static Future<dynamic> unenroll(String t,int studentId,int courseId)async=>req('DELETE','/admin/enrollments/$studentId/$courseId',t);
  static Future<dynamic> addTimetable(String t,Map<String,dynamic> body)async=>req('POST','/admin/timetable',t,body:jsonEncode(body));
}
