import 'package:flutter/material.dart';
import 'package:laour_etf/auth/auth_service.dart'; 
import 'package:laour_etf/screens/signup_screen.dart';
import 'package:provider/provider.dart'; 
import 'package:laour_etf/auth/auth_wrapper.dart'; 

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        
        if (authService.errorMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(authService.errorMessage)),
            );
            authService.clearState();
          });
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('라오어 ETF - 로그인'),
            
            // "계정 선택으로 돌아가기" 버튼
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '계정 선택으로 돌아가기',
              onPressed: () {
                authService.clearState();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (route) => false,
                );
              },
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: '이메일 (아이디)'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !authService.isLoading, 
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                  enabled: !authService.isLoading,
                ),
                
                const SizedBox(height: 20),
                
                if (authService.isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    // (★핵심 수정★) onPressed를 async로 변경
                    onPressed: () async {
                      bool success = await context.read<AuthService>().signIn(
                            emailController.text.trim(),
                            passwordController.text.trim(),
                          );
                      
                      // (★핵심 수정★)
                      // 로그인이 성공하면, 스택의 모든 화면 (Login, Picker)을 닫고
                      // AuthWrapper가 HomeScreen을 그리도록 합니다.
                      if (success && context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                      // 실패하면 AuthService가 알아서 isLoading:false로 변경하고
                      // 스낵바를 띄우므로, 여기서는 아무것도 안 해도 됩니다.
                    },
                    child: const Text('로그인'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                TextButton(
                  onPressed: authService.isLoading ? null : () { 
                    context.read<AuthService>().clearState();
                    
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