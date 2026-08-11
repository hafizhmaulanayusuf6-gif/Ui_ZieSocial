import 'package:flutter/material.dart';
import 'views/login_view.dart';

void main() {
  runApp(const ZieSocialApp());
}

class ZieSocialApp extends StatelessWidget {
  const ZieSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZieSocial',
      home: const LoginView(),
    );
  }
}