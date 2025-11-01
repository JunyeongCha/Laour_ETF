// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:laour_etf/auth/auth_service.dart'; // (★수정★)
import 'package:laour_etf/screens/signup_screen.dart';
import 'package:provider/provider.dart'; // (★수정★)

// (★수정★) StatefulWidget -> StatelessWidget
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    // 1. 템플릿처럼 'Consumer'를 사용해 AuthService의 상태(isLoading)를 감시
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        
        // 2. 에러가 있으면 SnackBar 표시 (빌드 후 즉시)
        if (authService.errorMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(authService.errorMessage)),
            );
          });
        }
        
        return Scaffold(
          appBar: AppBar(title: const Text('라오어 ETF - 로그인')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: '이메일 (아이디)'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !authService.isLoading, // 3. 중앙 상태로 활성화/비활성화
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                  enabled: !authService.isLoading, // 3. 중앙 상태로 활성화/비활성화
                ),
                const SizedBox(height: 20),
                
                // 4. 중앙 상태에 따라 로딩 또는 버튼 표시
                if (authService.isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () {
                      // 5. 템플릿처럼 AuthService의 함수 호출
                      context.read<AuthService>().signIn(
                            emailController.text.trim(),
                            passwordController.text.trim(),
                          );
                    },
                    child: const Text('로그인'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                TextButton(
                  onPressed: authService.isLoading ? null : () { 
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupScreen()),
                    );
                  },
                  child: const Text('회원가입 하러가기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}