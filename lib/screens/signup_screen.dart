// lib/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/auth/auth_wrapper.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        
        if (authService.errorMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(authService.errorMessage)),
            );
          });
        }
        
        return Scaffold(
          appBar: AppBar(title: const Text('회원가입')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '이름'),
                  enabled: !authService.isLoading,
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: '이메일 (아이디)'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !authService.isLoading,
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호 (6자리 이상)'),
                  obscureText: true,
                  enabled: !authService.isLoading,
                ),
                const SizedBox(height: 20),
                
                if (authService.isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () async {
                      // (★핵심 수정★) 팝업을 띄우기 위한 context 전달이 '제거'됨
                      bool success = await context.read<AuthService>().signUp(
                            context, // (수정) context는 여전히 필요할 수 있으니 남겨둡니다. (AuthService에서 제거했지만 혹시 모르니)
                            nameController.text.trim(),
                            emailController.text.trim(),
                            passwordController.text.trim(),
                          );
                      
                      // (수정 없음) 회원가입 성공 시 스택 리셋
                      if (success && context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthWrapper()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    },
                    child: const Text('회원가입 완료'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}