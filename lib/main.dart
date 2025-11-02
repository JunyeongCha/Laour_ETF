// // lib/main.dart (수정)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:laour_etf/auth/auth_wrapper.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:laour_etf/providers/theme_provider.dart'; // (★신규★)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        StreamProvider<User?>(
          create: (context) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        // (★신규★) ThemeProvider 등록
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // (★신규★) ThemeProvider를 여기서 watch(감시)
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: '라오어 ETF',
      
      // (★수정★) 라이트/다크 테마 및 themeMode 설정
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // 다크 모드 테마
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: themeProvider.themeMode, // (★수정★)
      
      home: const AuthWrapper(),
    );
  }
}