import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:laour_etf/auth/auth_wrapper.dart';
import 'package:laour_etf/auth/secure_storage_service.dart';
import 'package:laour_etf/screens/login_screen.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:provider/provider.dart';

class AccountPickerScreen extends StatefulWidget {
  final List<String> savedEmails;
  const AccountPickerScreen({super.key, required this.savedEmails});

  @override
  State<AccountPickerScreen> createState() => _AccountPickerScreenState();
}

class _AccountPickerScreenState extends State<AccountPickerScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  bool _isLoggingIn = false; // 원터치 로그인 시 로컬 로딩 상태

  // 원터치 로그인
  void _loginWithSavedAccount(String email) async {
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    try {
      final String? password = await _storageService.readPassword(email);
      if (password == null) throw Exception("저장된 비밀번호를 찾을 수 없습니다.");
      
      // (★수정★) 6-3: saveAccount 파라미터 제거
      final success = await context.read<AuthService>().signIn(email, password);

      if (!success && mounted) {
        setState(() => _isLoggingIn = false);
      }
      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('자동 로그인 실패: ${e.toString()}')),
        );
      }
    }
    if (mounted) {
       setState(() => _isLoggingIn = false);
    }
  }

  // (★수정★) 6-2: 이 함수는 존재하지만, 아래 build()에서 호출하지 않음
  void _deleteAccount(String email) async {
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
      try { 
        await _storageService.deleteAccount(email);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('삭제 실패 (환경 설정 오류): ${e.toString()}')),
           );
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthLoading = context.watch<AuthService>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 선택'),
        automaticallyImplyLeading: false, 
      ),
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
                      onTap: isAuthLoading ? null : () => _loginWithSavedAccount(email),
                      // (★수정★) 6-2: 삭제 버튼 비활성화
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: null, // ★비활성화★
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isAuthLoading || _isLoggingIn) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            
            OutlinedButton(
              onPressed: isAuthLoading ? null : () { 
                context.read<AuthService>().clearState();
                
                // (★핵심 수정★) 
                // "뒤로 가기" 버튼을 만들기 위해 pushReplacement -> push로 변경
                Navigator.of(context).push(
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