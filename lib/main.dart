import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; //
import 'package:ziesocial/viewmodel/create_post_viewmodel.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart';

// Sesuaikan import di bawah ini dengan struktur folder project Anda
import 'core/network.dart'; // atau lokasi ApiClient Anda
import 'viewmodel/login_viewmodel.dart'; // atau lokasi LoginViewModel Anda
import 'views/login_view.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
 //[cite: 2]

import 'dart:io';

// Tambahkan kelas ini di atas atau di file main.dart
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  final apiClient = ApiClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LoginViewModel(apiClient),
        ),
        // Cukup tulis 1 kali saja di sini:
        ChangeNotifierProvider(
          create: (_) => RegisterViewmodel(apiClient), // atau RegisterViewModel() jika tidak butuh apiClient
        ),
        ChangeNotifierProvider(
          create: (_) => CreatePostViewModel(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => PostViewModel(apiClient)
        ),
      ],
      child: const ZieSocialApp(),
    ),
  );
}

class ZieSocialApp extends StatelessWidget {
  const ZieSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZieSocial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), //[cite: 2]
      ),
      home: const LoginView(), //[cite: 2]
    );
  }
}