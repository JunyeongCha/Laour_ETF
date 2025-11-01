// lib/screens/account_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:laour_etf/auth/auth_wrapper.dart'; // (★추가★)
import 'package:laour_etf/auth/secure_storage_service.dart';
import 'package:laour_etf/screens/login_screen.dart';

class AccountPickerScreen extends StatefulWidget {
  final List<String> savedEmails;
  const AccountPickerScreen({super.key, required this.savedEmails});

  @override
  State<AccountPickerScreen> createState() => _AccountPickerScreenState();
}

class _AccountPickerScreenState extends State<AccountPickerScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  bool _isLoggingIn = false;

  // (수정 없음) 원터치 로그인
  void _loginWithSavedAccount(String email) async {
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    try {
      final String? password = await _storageService.readPassword(email);
      if (password == null) throw Exception("저장된 비밀번호를 찾을 수 없습니다.");
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      setState(() => _isLoggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 로그인 실패: ${e.toString()}')),
      );
    }
  }

  // (★핵심 추가★) 계정 삭제 로직
  void _deleteAccount(String email) async {
    // 1. 확인 팝업 (선택 사항이지만 권장)
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: Text('"$email" 계정을 이 기기에서 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제')),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      // 2. 보안 저장소에서 삭제
      await _storageService.deleteAccount(email);

      // 3. (★핵심★) 화면 새로고침
      // AuthWrapper를 다시 로드하여 변경사항(계정 목록)을 반영합니다.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 선택')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '저장된 계정으로 로그인',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: widget.savedEmails.length,
                itemBuilder: (context, index) {
                  final email = widget.savedEmails[index];
                  return Card(
                    child: ListTile(
                      title: Text(email),
                      leading: const Icon(Icons.account_circle),
                      onTap: () => _loginWithSavedAccount(email),
                      // (★핵심 추가★) 삭제 버튼
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteAccount(email),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoggingIn) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('다른 계정으로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}