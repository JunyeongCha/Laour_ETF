//lib/auth/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/auth/secure_storage_service.dart';
import 'package:laour_etf/screens/account_picker_screen.dart';
import 'package:laour_etf/screens/home_screen.dart';
import 'package:laour_etf/screens/login_screen.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final SecureStorageService storageService = SecureStorageService();

    // 1. StreamProvider를 'watch' (감시)
    final User? user = context.watch<User?>();

    // 2. 유저가 있으면 (로그인 됨)
    if (user != null) {
      return const HomeScreen();
    }

    // 3. 유저가 없으면 (로그아웃 상태)
    //    우리의 SecureStorage 로직 실행
    return FutureBuilder<List<String>>(
      future: storageService.readAllAccountEmails(),
      builder: (context, storageSnapshot) {
        
        if (storageSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // 4. 저장된 계정이 있으면
        if (storageSnapshot.hasData && storageSnapshot.data!.isNotEmpty) {
          return AccountPickerScreen(savedEmails: storageSnapshot.data!);
        }

        // 5. 저장된 계정이 없으면
        return const LoginScreen();
      },
    );
  }
}