import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/core/fcm_service.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/comment_viewmodel.dart';
import 'package:ziesocial/viewmodel/create_post_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/register_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/views/login_view.dart';

// untuk sertifikat di hp
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Inisialisasi Firebase & FCM secara asinkron setelah runApp terpanggil.
  // Menjamin UI halaman Login langsung tampil tanpa terhalang jaringan/Firebase.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FcmService().init(apiClient).catchError((e) {
      debugPrint('FCM init post-frame error: $e');
    });
  });
}

class ZieSocialApp extends StatelessWidget {
  const ZieSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZieSocial',
      navigatorKey: FcmService.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginView(),
    );
  }
}
