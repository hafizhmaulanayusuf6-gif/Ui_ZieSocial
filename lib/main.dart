import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/create_post_viewmodel.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'core/network.dart';
import 'viewmodel/login_viewmodel.dart';
import 'views/login_view.dart';
import 'package:ziesocial/viewmodel/comment_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';

import 'dart:io';

// untuk sertifikat di hp saya
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  final apiClient = ApiClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => RegisterViewmodel(apiClient)),
        ChangeNotifierProvider(create: (_) => CreatePostViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => PostViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => CommentViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => ProfileViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => SearchViewModel(apiClient)),
        ChangeNotifierProvider(create: (_) => ChatViewModel(apiClient)),
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginView(),
    );
  }
}
