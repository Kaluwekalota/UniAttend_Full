import 'package:flutter/material.dart';
import '../services/api.dart';

class RegisterScreen extends StatefulWidget{const RegisterScreen({super.key});@override State<RegisterScreen>createState()=>_RegisterState();}
class _RegisterState extends State<RegisterScreen>{
 final name=TextEditingController(),email=TextEditingController(),pass=TextEditingController(),number=TextEditingController(),programme=TextEditingController();
 String role='student',error='';
 Future<void> save()async{
  try{
   await Api.register({'full_name':name.text,'email':email.text,'password':pass.text,'role':role,'student_no':role=='student'?number.text:null,'staff_no':role=='lecturer'?number.text:null,'programme':programme.text});
   if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Account created successfully')));Navigator.pop(context);}
  }catch(e){setState(()=>error=e.toString());}
 }
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Create Account')),body:ListView(padding:const EdgeInsets.all(20),children:[
 TextField(controller:name,decoration:const InputDecoration(labelText:'Full name')),TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),
 TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password (minimum 8 characters)')),
 DropdownButtonFormField(initialValue:role,items:const[DropdownMenuItem(value:'student',child:Text('Student')),DropdownMenuItem(value:'lecturer',child:Text('Lecturer'))],onChanged:(v)=>setState(()=>role=v!),decoration:const InputDecoration(labelText:'Role')),
 TextField(controller:number,decoration:InputDecoration(labelText:role=='student'?'Student Number':'Staff Number')),TextField(controller:programme,decoration:const InputDecoration(labelText:'Programme')),
 if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.red)),const SizedBox(height:20),FilledButton(onPressed:save,child:const Text('REGISTER'))
 ]));
}
