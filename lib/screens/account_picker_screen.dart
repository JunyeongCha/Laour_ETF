// lib/screens/account_picker_screen.dart (★4.5단계 수정 완료★)

import 'package:flutter/material.dart';
import 'package:laour_etf/auth/auth_wrapper.dart';
import 'package:laour_etf/auth/secure_storage_service.dart';
import 'package:laour_etf/screens/login_screen.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:provider/provider.dart';
// (★4.5단계 신규★)
import 'package:laour_etf/screens/save_account_screen.dart'; 

class AccountPickerScreen extends StatefulWidget {
  final List<String> savedEmails;
  const AccountPickerScreen({super.key, required this.savedEmails});

  @override
  State<AccountPickerScreen> createState() => _AccountPickerScreenState();
}

class _AccountPickerScreenState extends State<AccountPickerScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  bool _isLoggingIn = false; 

  // (주석) 원터치 로그인 (수정 없음)
  void _loginWithSavedAccount(String email) async {
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    try {
      final String? password = await _storageService.readPassword(email);
      if (password == null) throw Exception("저장된 비밀번호를 찾을 수 없습니다.");
      
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
    // (★수정★) 성공/실패 여부와 관계없이 로딩 해제 (AuthService가 성공 시 화면 전환)
    if (mounted) {
       setState(() => _isLoggingIn = false);
    }
  }

  // (주석) 계정 삭제 (수정 없음)
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
             SnackBar(content: Text('삭제 실패 (환경 설정 오류): ${e.toString()}'))
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
            
            // (★4.5단계 수정★) 저장된 계정이 없을 때 UI 처리
            Expanded(
              child: widget.savedEmails.isEmpty
                ? const Center(
                    child: Text(
                      '저장된 계정이 없습니다.\n아래 버튼으로 새 계정 정보를 수동 저장하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.savedEmails.length,
                    itemBuilder: (context, index) {
                      final email = widget.savedEmails[index];
                      return Card(
                        child: ListTile(
                          title: Text(email),
                          leading: const Icon(Icons.account_circle),
                          onTap: (isAuthLoading || _isLoggingIn) ? null : () => _loginWithSavedAccount(email),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: (isAuthLoading || _isLoggingIn) ? null : () => _deleteAccount(email), 
                          ),
                        ),
                      );
                    },
                  ),
            ),
            
            if (isAuthLoading || _isLoggingIn) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            
            // (★4.5단계 신규★) "새로운 아이디 저장하기" 버튼
            ElevatedButton(
              onPressed: (isAuthLoading || _isLoggingIn) ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SaveAccountScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45), 
              ),
              child: const Text('새로운 아이디 저장하기'),
            ),
            const SizedBox(height: 8), // 버튼 사이 간격

            OutlinedButton(
              onPressed: (isAuthLoading || _isLoggingIn) ? null : () { 
                context.read<AuthService>().clearState();
                
                // (★4.5단계 수정★) pushReplacement -> push
                // LoginScreen에서 뒤로가기(<-)를 눌렀을 때 
                // 이 AccountPickerScreen으로 돌아와야 함.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }, 
              child: const Text('다른 계정으로 로그인 (저장 안 함)'), // (★수정★)
            ),
          ],
        ),
      ),
    );
  }
}