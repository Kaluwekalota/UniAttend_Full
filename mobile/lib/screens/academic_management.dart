import 'package:flutter/material.dart';
import '../services/academic_api.dart';

class AcademicManagement extends StatefulWidget{
  final String token;
  const AcademicManagement({super.key,required this.token});
  @override State<AcademicManagement> createState()=>_AcademicManagementState();
}

class _AcademicManagementState extends State<AcademicManagement>{
  int tab=0;
  late Future<List<dynamic>> lecturersF,studentsF,coursesF,timetableF;

  @override void initState(){
    super.initState();
    reload();
  }
  void reload(){
    lecturersF=AcademicApi.lecturers(widget.token);
    studentsF=AcademicApi.students(widget.token);
    coursesF=AcademicApi.courses(widget.token);
    timetableF=AcademicApi.timetable(widget.token);
    if(mounted)setState((){});
  }
  void msg(String x)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));

  Future<void> addCourse()async{
    final code=TextEditingController(),title=TextEditingController(),programme=TextEditingController();
    int? lecturer;
    final ls=await AcademicApi.lecturers(widget.token);
    if(!mounted)return;
    await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:const Text('Add Course'),
      content:SingleChildScrollView(child:Column(children:[
        TextField(controller:code,decoration:const InputDecoration(labelText:'Course code')),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Course title')),
        TextField(controller:programme,decoration:const InputDecoration(labelText:'Programme')),
        DropdownButtonFormField<int>(initialValue:lecturer,decoration:const InputDecoration(labelText:'Lecturer'),
          items:[for(final x in ls)DropdownMenuItem<int>(value:x['id'],child:Text(x['full_name']))],
          onChanged:(v)=>setD(()=>lecturer=v))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),
        FilledButton(onPressed:()async{
          try{await AcademicApi.createCourse(widget.token,{'code':code.text,'title':title.text,'programme':programme.text,'lecturer_id':lecturer});if(context.mounted)Navigator.pop(d);reload();msg('Course created.');}
          catch(e){msg(e.toString());}
        },child:const Text('SAVE'))]
    )));
  }

  Future<void> addEnrollment()async{
    final ss=await AcademicApi.students(widget.token),cs=await AcademicApi.courses(widget.token);
    int? student,course;
    if(!mounted)return;
    await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:const Text('Enroll Student'),
      content:SingleChildScrollView(child:Column(children:[
        DropdownButtonFormField<int>(initialValue:student,decoration:const InputDecoration(labelText:'Student'),
          items:[for(final x in ss)DropdownMenuItem(value:x['id'],child:Text('${x['student_id']??''} - ${x['full_name']}'))],onChanged:(v)=>setD(()=>student=v)),
        DropdownButtonFormField<int>(initialValue:course,decoration:const InputDecoration(labelText:'Course'),
          items:[for(final x in cs)DropdownMenuItem(value:x['id'],child:Text('${x['code']} - ${x['title']}'))],onChanged:(v)=>setD(()=>course=v))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),
        FilledButton(onPressed:()async{if(student==null||course==null){msg('Select both student and course.');return;}
          try{await AcademicApi.enroll(widget.token,student!,course!);if(context.mounted)Navigator.pop(d);reload();msg('Student enrolled.');}catch(e){msg(e.toString());}},child:const Text('ENROLL'))]
    )));
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Academic Management')),
    body:tab==0?_lecturers():tab==1?_courses():tab==2?_students():_timetable(),
    floatingActionButton:tab==1?FloatingActionButton.extended(onPressed:addCourse,icon:const Icon(Icons.add),label:const Text('Course')):
      tab==2?FloatingActionButton.extended(onPressed:addEnrollment,icon:const Icon(Icons.person_add),label:const Text('Enroll')):null,
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),
      destinations:const[
        NavigationDestination(icon:Icon(Icons.people),label:'Lecturers'),
        NavigationDestination(icon:Icon(Icons.menu_book),label:'Courses'),
        NavigationDestination(icon:Icon(Icons.school),label:'Students'),
        NavigationDestination(icon:Icon(Icons.calendar_month),label:'Timetable')]),
  );

  Widget _lecturers()=>_futureList(lecturersF,(x)=>Card(child:ListTile(
    leading:const CircleAvatar(child:Icon(Icons.person)),
    title:Text(x['full_name']??''),subtitle:Text('${x['staff_id']??''} • ${x['email']??''}'),
    trailing:Text('${(x['courses'] as List).length} courses'))));

  Widget _courses()=>_futureList(coursesF,(x)=>Card(child:ListTile(
    leading:const CircleAvatar(child:Icon(Icons.menu_book)),
    title:Text('${x['code']} - ${x['title']}'),
    subtitle:Text('Lecturer: ${x['lecturer_name']??'Not assigned'}\nProgramme: ${x['programme']??'-'}'))));

  Widget _students()=>_futureList(studentsF,(x)=>Card(child:ListTile(
    leading:const CircleAvatar(child:Icon(Icons.school)),
    title:Text('${x['student_id']??''} - ${x['full_name']}'),
    subtitle:Text('${x['programme']??'-'} • ${x['enrolments']} course(s)'))));

  Widget _timetable()=>_futureList(timetableF,(x)=>Card(child:ListTile(
    leading:CircleAvatar(child:Icon(x['class_mode']=='PHYSICAL'?Icons.school:Icons.wifi)),
    title:Text('${x['course_code']} - ${x['course_title']}'),
    subtitle:Text('${x['day']} ${x['start']}-${x['end']} • ${x['room']??'ONLINE'} • ${x['group']??''}'))));

  Widget _futureList(Future<List<dynamic>> f,Widget Function(dynamic) item)=>FutureBuilder<List<dynamic>>(
    future:f,builder:(c,s){
      if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:Text('Error: ${s.error}'));
      final a=s.data??[];if(a.isEmpty)return const Center(child:Text('No records found.'));
      return RefreshIndicator(onRefresh:()async=>reload(),child:ListView(padding:const EdgeInsets.all(10),children:[for(final x in a)item(x)]));
    });
}
