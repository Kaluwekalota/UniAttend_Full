import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api.dart';

class LecturerAttendanceScreen extends StatefulWidget {
  final String token; final Map<String,dynamic> entry;
  const LecturerAttendanceScreen({super.key,required this.token,required this.entry});
  @override State<LecturerAttendanceScreen> createState()=>_LecturerAttendanceScreenState();
}
class _LecturerAttendanceScreenState extends State<LecturerAttendanceScreen>{
  String? qr; int? sid; DateTime? expiry,endAt; Timer? timer; List<dynamic> present=[]; String message=''; bool loading=false;
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> start()async{
    setState(()=>loading=true);
    try{
      final c=Map<String,dynamic>.from(widget.entry['course']);
      final r=await Api.createSession(widget.token,c['id'],widget.entry['id']);
      setState((){qr=r['token'];sid=r['session_id'];expiry=DateTime.parse(r['qr_expires_at']);endAt=DateTime.parse(r['class_ends_at']);message='Attendance is active.';});
      timer=Timer.periodic(const Duration(seconds:1),(_)=>tick());
    }catch(e){setState(()=>message=e.toString());}
    setState(()=>loading=false);
  }
  Future<void> tick()async{
    if(!mounted||sid==null)return;
    final now=DateTime.now().toUtc();
    if(endAt!=null&&now.isAfter(endAt!)){await stop();return;}
    if(expiry!=null&&now.isAfter(expiry!)){try{final r=await Api.rotateQr(widget.token,sid!);if(mounted)setState((){qr=r['token'];expiry=DateTime.parse(r['qr_expires_at']);});}catch(e){}}
    try{final x=await Api.liveStudents(widget.token,sid!);if(mounted)setState(()=>present=x);}catch(_){}
  }
  Future<void> stop()async{if(sid!=null)try{await Api.endSession(widget.token,sid!);}catch(_){}timer?.cancel();if(mounted)setState(()=>message='Attendance session ended.');}
  String left(DateTime? t){if(t==null)return '--:--';final d=t.difference(DateTime.now().toUtc());if(d.isNegative)return '00:00';return '${d.inMinutes.toString().padLeft(2,'0')}:${(d.inSeconds%60).toString().padLeft(2,'0')}';}
  @override Widget build(BuildContext context){
    final c=Map<String,dynamic>.from(widget.entry['course']); final physical=widget.entry['class_mode']=='PHYSICAL';
    return Scaffold(appBar:AppBar(title:Text(physical?'Physical Attendance':'Live Attendance')),
      body:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
        Text('${c['code']} - ${c['title']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        Text('${widget.entry['day']} • ${widget.entry['start']} - ${widget.entry['end']}'),
        Text(physical?'ROOM: ${widget.entry['room']??'Not specified'}':'ONLINE CLASS',style:const TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        if(qr==null)FilledButton.icon(onPressed:loading?null:start,icon:const Icon(Icons.qr_code_2),label:Text(physical?'START PHYSICAL ATTENDANCE':'START LIVE ATTENDANCE')),
        if(qr!=null)...[
          Text(physical?'Students in class: scan this QR':'Students online: scan this QR',style:const TextStyle(fontSize:18)),
          QrImageView(data:qr!,size:240),
          Text('QR refreshes in ${left(expiry)}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
          Text('Present: ${present.length}',style:const TextStyle(fontSize:19)),
          Expanded(child:ListView(children:[for(final s in present)ListTile(leading:const Icon(Icons.verified),title:Text(s['student_name']??''),subtitle:Text('${s['student_no']??''} • ${s['marked_at']??''}'),trailing:const Text('PRESENT'))])),
          FilledButton.tonalIcon(onPressed:stop,icon:const Icon(Icons.stop),label:const Text('END ATTENDANCE'))
        ],
        if(message.isNotEmpty)Text(message,textAlign:TextAlign.center)
      ])));
  }
}
