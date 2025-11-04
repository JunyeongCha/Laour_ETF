import 'package:flutter/material.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:provider/provider.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    final authService = context.read<AuthService>();
    final success = await authService.changePassword(
      _currentPasswordController.text,
      newPassword,
    );

    if (mounted) {
      setState(() { _isLoading = false; });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 성공적으로 변경되었습니다.')),
        );
        Navigator.pop(context); // 마이페이지로 복귀
      } else {
        // AuthService가 오류 메시지를 Consumer에게 전달하므로
        // 여기서는 별도 스낵바가 필요 없지만, 로딩은 풀어야 함
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 변경'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 에러 메시지 표시
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  if (authService.errorMessage.isNotEmpty) {
                    // 빌드가 끝난 직후에 스낵바를 보여주기 위해 addPostFrameCallback 사용
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(authService.errorMessage)),
                      );
                      authService.clearState(); // 에러 메시지 초기화
                    });
                  }
                  return const SizedBox.shrink(); // UI에는 아무것도 그리지 않음
                },
              ),
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: '현재 비밀번호'),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty) ? '현재 비밀번호를 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: '새 비밀번호 (6자리 이상)'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '새 비밀번호를 입력하세요.';
                  }
                  if (value.length < 6) {
                    return '6자리 이상 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty) ? '새 비밀번호를 다시 입력하세요.' : null,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('비밀번호 변경하기'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}