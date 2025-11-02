// // lib/screens/my_page_screen.dart (수정)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/auth/auth_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/providers/theme_provider.dart'; // (★신규★)

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();
    
    // (★신규★) 5-3 ThemeProvider 가져오기
    final themeProvider = context.watch<ThemeProvider>();

    final Stream<QuerySnapshot>? completedCyclesStream = (user != null)
      ? FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cycles')
          .snapshots() 
      : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- 1. 내 정보 섹션 ---
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
                    user?.email ?? '로그인 정보 없음',
                  ),
                ),
                
                StreamBuilder<QuerySnapshot>(
                  stream: completedCyclesStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || user == null) {
                      return const ListTile(
                        leading: Icon(Icons.assessment_outlined),
                        title: Text('누적 총 수익'),
                        subtitle: Text('... (계산 중)'),
                      );
                    }

                    double totalRealizedProfit = 0.0;
                    
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) continue;
                      
                      final int quantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
                      final double purchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
                      final bool isManuallyCompleted = (data['isManuallyCompleted'] as bool?) ?? false;

                      if (isManuallyCompleted || (quantity == 0 && purchaseAmount > 0)) {
                        totalRealizedProfit += (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
                      }
                    }
                    
                    final Color profitColor = totalRealizedProfit >= 0 ? Colors.red : Colors.blue.shade700;

                    return ListTile(
                      leading: Icon(Icons.assessment_outlined, color: profitColor),
                      title: const Text('누적 총 수익'),
                      subtitle: Text(
                        '${totalRealizedProfit.toStringAsFixed(0)} 원',
                        style: TextStyle(
                          color: profitColor, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- 2. 환경 설정 섹션 ---
          const Text(
            '환경 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2.0,
            child: Column(
              children: [
                // (★수정★) 5-3 다크 모드
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('다크 모드'),
                  value: themeProvider.isDarkMode, // (★수정★)
                  onChanged: (bool value) {
                    // (★수정★)
                    context.read<ThemeProvider>().toggleTheme(value);
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
                    context.read<AuthService>().signOut();
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