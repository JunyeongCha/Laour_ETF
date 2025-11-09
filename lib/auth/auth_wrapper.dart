//lib/auth/auth_wrapper.dart (★4.5단계 수정 완료★)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/auth/secure_storage_service.dart';
import 'package:laour_etf/screens/account_picker_screen.dart';
import 'package:laour_etf/screens/home_screen.dart';
// import 'package:laour_etf/screens/login_screen.dart'; // (★4.5단계★) 더 이상 사용 안 함
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
        
        // (★4.5단계 수정★)
        // 저장된 계정이 있든(storageSnapshot.data) 없든(null)
        // "항상" AccountPickerScreen을 보여줍니다.
        // AccountPickerScreen이 (data ?? []) 빈 리스트를 받아
        // "저장된 계정이 없습니다" UI를 표시합니다.
        return AccountPickerScreen(savedEmails: storageSnapshot.data ?? []);
        
        // (★4.5단계★) 이 로직은 더 이상 사용되지 않습니다.
        // if (storageSnapshot.hasData && storageSnapshot.data!.isNotEmpty) {
        //   return AccountPickerScreen(savedEmails: storageSnapshot.data!);
        // }
        // return const LoginScreen();
      },
    );
  }
}