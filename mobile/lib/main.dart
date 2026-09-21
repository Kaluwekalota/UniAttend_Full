import 'package:flutter/material.dart';

import 'screens/login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const UniAttendApp());
}

class UniAttendApp extends StatelessWidget {
  const UniAttendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'UniAttend',

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),

      initialRoute: '/login',

      routes: {
        '/login': (context) =>
            const LoginScreen(),
      },
    );
  }
}