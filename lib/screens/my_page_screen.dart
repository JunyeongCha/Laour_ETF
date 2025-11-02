// // lib/screens/my_page_screen.dart (5-4 수정)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/auth/auth_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/providers/theme_provider.dart';
import 'package:laour_etf/screens/target_setting_screen.dart'; // (★신규★)

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();
    final themeProvider = context.watch<ThemeProvider>();

    // (★수정★)
    // 2개의 스트림이 필요 (1. 유저 정보, 2. 사이클 정보)
    // 1. 유저 정보(목표 금액) 스트림
    final Stream<DocumentSnapshot>? userDocStream = (user != null)
      ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
      : null;
      
    // 2. 사이클(누적 수익) 스트림
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
          // --- 1. 내 정보 섹션 (5-4 수정) ---
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
                
                // (★수정★)
                // 2개의 스트림을 조합하기 위해 StreamBuilder를 중첩합니다.
                // 바깥쪽: 유저 정보(목표 금액)
                // 안쪽: 사이클 정보(누적 수익)
                StreamBuilder<DocumentSnapshot>(
                  stream: userDocStream,
                  builder: (context, userSnapshot) {
                    
                    double targetProfit = 0.0;
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                       final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                       targetProfit = (userData['targetProfit'] as num?)?.toDouble() ?? 0.0;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: completedCyclesStream,
                      builder: (context, cycleSnapshot) {
                        if (!cycleSnapshot.hasData || user == null) {
                          return const ListTile(
                            leading: Icon(Icons.assessment_outlined),
                            title: Text('누적 총 수익'),
                            subtitle: Text('... (계산 중)'),
                          );
                        }

                        double totalRealizedProfit = 0.0;
                        
                        for (var doc in cycleSnapshot.data!.docs) {
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
                        
                        // (★신규★) 목표 달성률 계산
                        double achievementRate = 0.0;
                        if (targetProfit > 0) {
                          achievementRate = totalRealizedProfit / targetProfit;
                        }
                        // 0% ~ 100% 사이로 고정
                        achievementRate = achievementRate.clamp(0.0, 1.0); 

                        return Column(
                          children: [
                            ListTile(
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
                            ),
                            // (★신규★) 목표 달성률 UI
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('목표 달성률', style: TextStyle(fontSize: 14)),
                                      Text(
                                        '${(achievementRate * 100).toStringAsFixed(1)} %',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: achievementRate,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                    backgroundColor: Colors.grey.shade300,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '목표: ${targetProfit.toStringAsFixed(0)} 원',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- 2. 환경 설정 섹션 (5-4 수정) ---
          const Text(
            '환경 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2.0,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('다크 모드'),
                  value: themeProvider.isDarkMode, 
                  onChanged: (bool value) {
                    context.read<ThemeProvider>().toggleTheme(value);
                  },
                ),
                
                // (★신규★) 5-4 목표 금액 설정 메뉴
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('목표 금액 설정'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TargetSettingScreen()),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('비밀번호 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // (미래에 구현)
                  },
                ),
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