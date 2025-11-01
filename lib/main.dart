// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:laour_etf/auth/auth_wrapper.dart';
import 'package:provider/provider.dart'; // (★추가★)
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // (★수정★) 템플릿처럼 MultiProvider로 앱을 감쌉니다.
  runApp(
    MultiProvider(
      providers: [
        // 1. AuthService 등록
        ChangeNotifierProvider(create: (context) => AuthService()),
        // 2. 템플릿처럼 유저 스트림 등록
        StreamProvider<User?>(
          create: (context) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '라오어 ETF',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 3. AuthWrapper (AuthGate)
      home: const AuthWrapper(),
    );
  }
}