// lib/screens/home_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:laour_etf/screens/cycle_create_screen.dart';
import 'package:laour_etf/widgets/cycle_list_view.dart';
import 'package:laour_etf/widgets/overall_status_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  // (★수정★) 'late final'을 지우고, Nullable(?)로 변경
  Stream<QuerySnapshot>? _cyclesStream;
  User? _user; // (★수정★) 'late final'을 지우고, Nullable(?)로 변경

  @override
  void initState() {
    super.initState();
    
    // (★수정★) 핫 리스타트 시 currentUser가 'null'일 수 있으므로
    // '!' 대신 '안전하게' _user 변수에 할당합니다.
    _user = FirebaseAuth.instance.currentUser;

    // (★수정★) _user가 null이 '아닐' 때만 데이터를 로드합니다.
    if (_user != null) {
      // _user가 null이 아니므로, _user!.uid (null check)는 안전합니다.
      _loadUserName(_user!); 
      _cyclesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('cycles')
          .snapshots();
    }
    // 'else' (user가 null인 경우)
    // 핫 리스타트 직후 이럴 수 있습니다.
    // _cyclesStream은 null로 유지되고, build() 메서드가 이를 처리합니다.
  }

  // (★수정★) _user를 매개변수로 받도록 변경
  void _loadUserName(User user) async {
    try {
      final DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists && mounted) {
        setState(() => _userName = userData.get('name'));
      } else if (mounted) {
        setState(() => _userName = user.email?.split('@').first ?? "사용자");
      }
    } catch (e) {
      if (mounted) setState(() => _userName = "사용자 (로드 실패)");
    }
  }

  @override
  Widget build(BuildContext context) {
    // (★수정★)
    // 핫 리스타트 직후 _user나 _cyclesStream이 null일 때,
    // AuthWrapper가 유저를 불러올 때까지 로딩 화면을 표시합니다.
    if (_user == null || _cyclesStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('포트폴리오 로딩 중...')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // _user와 _cyclesStream이 '정상적으로' 초기화된 후의 UI
    return Scaffold(
      appBar: AppBar(
        title: Text(_userName == null
            ? '포트폴리오'
            : '$_userName님의 포트폴리오'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          // (★수정★) _cyclesStream이 null이 아님을 보장 (! 사용)
          stream: _cyclesStream!,
          builder: (context, snapshot) {
            
            // ... (이하 로직은 2-5 단계와 동일) ...
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('데이터를 불러오는 데 실패했습니다.\n${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  '아직 생성된 사이클이 없습니다.\n아래 + 버튼을 눌러 시작하세요.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final cycleDocs = snapshot.data!.docs;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverallStatusCard(cycleDocs: cycleDocs),
                const SizedBox(height: 24),
                const Text(
                  '진행 중인 사이클',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: CycleListView(cycleDocs: cycleDocs),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CycleCreateScreen()),
          );
        },
      ),
    );
  }
}