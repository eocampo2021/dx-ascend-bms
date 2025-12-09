import 'package:flutter/material.dart';
import 'workstation_shell.dart';

class WorkstationApp extends StatelessWidget {
  const WorkstationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DX Ascend Workstation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF3DCD58),
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
        dividerColor: const Color(0xFFD0D0D0),
        fontFamily: 'Segoe UI',
        visualDensity: VisualDensity.compact,
        iconTheme: const IconThemeData(size: 16, color: Color(0xFF555555)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 12, color: Colors.black87),
          bodySmall: TextStyle(fontSize: 11, color: Colors.black54),
          titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      home: const MainShell(),
    );
  }
}
