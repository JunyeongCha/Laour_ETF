// // lib/screens/save_account_screen.dart (★4.5단계 신규 파일★)

import 'package:flutter/material.dart';
import 'package:laour_etf/auth/auth_wrapper.dart';
import 'package:laour_etf/auth/secure_storage_service.dart';

class SaveAccountScreen extends StatefulWidget {
  const SaveAccountScreen({super.key});

  @override
  State<SaveAccountScreen> createState() => _SaveAccountScreenState();
}

class _SaveAccountScreenState extends State<SaveAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final SecureStorageService _storageService = SecureStorageService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. SecureStorage에 저장
      await _storageService.saveAccount(email, password);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$email" 계정 정보가 기기에 저장되었습니다.')),
        );
        
        // 2. AuthWrapper로 되돌아가서 계정 선택창을 새로고침
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 계정 정보 저장'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '로그인하려는 계정의 이메일과 비밀번호를 이 기기에 수동으로 저장합니다.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일 (아이디)'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveAccount,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('이 기기에 저장하기'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}