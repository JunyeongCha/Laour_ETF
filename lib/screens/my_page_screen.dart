import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/auth/auth_service.dart'; // 로그아웃을 위해 미리 import
import 'package:firebase_auth/firebase_auth.dart'; // (★수정★) User 타입을 알기 위해 import

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // (★수정★)
    // StreamProvider를 통해 현재 로그인된 User 객체를 직접 받습니다.
    final User? user = context.watch<User?>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- 1. 내 정보 섹션 (5-2 단계에서 구현) ---
          const Text(
            '내 정보',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2.0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('계정'),
                  subtitle: Text(
                    // (★수정★)
                    // user 변수에서 직접 이메일을 읽습니다.
                    user?.email ?? '로그인 정보 없음',
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.assessment_outlined),
                  title: Text('누적 총 수익'),
                  subtitle: Text('... (계산 중)'), // (5-2 단계에서 구현)
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- 2. 환경 설정 섹션 (5-3, 5-4, 5-5 단계) ---
          const Text(
            '환경 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2.0,
            child: Column(
              children: [
                // (5-3 단계) 다크 모드
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('다크 모드'),
                  value: false, // (5-3 단계에서 ThemeProvider와 연결)
                  onChanged: (bool value) {
                    // (5-3 단계에서 구현)
                  },
                ),
                // (5-4 단계) 비밀번호 변경
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('비밀번호 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // (5-4 단계) 비밀번호 변경 화면으로 이동
                  },
                ),
                // (5-5 단계) 로그아웃
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade700),
                  title: Text('로그아웃', style: TextStyle(color: Colors.red.shade700)),
                  onTap: () {
                    // (5-5 단계) 로그아웃 확인 팝업 후 실행
                    context.read<AuthService>().signOut();
                    // (수정) popUntil로 홈까지 안전하게 이동
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}