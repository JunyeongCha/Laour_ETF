import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:laour_etf/screens/cycle_create_screen.dart';
import 'package:laour_etf/widgets/completed_status_card.dart'; 
import 'package:laour_etf/widgets/cycle_list_view.dart';
import 'package:laour_etf/widgets/ongoing_status_card.dart'; 
import 'package:provider/provider.dart';
import 'package:laour_etf/screens/my_page_screen.dart'; // (★ 5-1 신규 ★)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  Stream<QuerySnapshot>? _cyclesStream;
  User? _user;

  @override
  void initState() {
    super.initState();
    
    _user = FirebaseAuth.instance.currentUser;

    if (_user != null) {
      _loadUserName(_user!); 
      _cyclesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('cycles')
          .orderBy('createdAt', descending: true) 
          .snapshots();
    }
  }

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
    if (_user == null || _cyclesStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('포트폴리오 로딩 중...')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_userName == null
            ? '포트폴리오'
            : '$_userName님의 포트폴리오'),
        actions: [
          // (★ 5-1 신규 ★) 마이페이지 버튼
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: '마이페이지',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyPageScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cyclesStream!,
        builder: (context, snapshot) {
          
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
          
          final List<QueryDocumentSnapshot> ongoingCycles = [];
          final List<QueryDocumentSnapshot> completedCycles = [];

          for (var doc in cycleDocs) {
            final data = doc.data() as Map<String, dynamic>?;
            final int quantity = (data?['currentQuantity'] as num?)?.toInt() ?? 0;
            final double purchaseAmount = (data?['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
            final bool isManuallyCompleted = (data?['isManuallyCompleted'] as bool?) ?? false;

            if (isManuallyCompleted || (quantity == 0 && purchaseAmount > 0)) {
              completedCycles.add(doc);
            } else {
              ongoingCycles.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- 진행중 섹션 ---
              const Text(
                '진행중 사이클 상황',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              OngoingStatusCard(cycleDocs: ongoingCycles), 
              const SizedBox(height: 24),
              const Text(
                '진행중 사이클',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CycleListView(cycleDocs: ongoingCycles), 
              
              // --- 정산완료 섹션 ---
              const SizedBox(height: 24),
              const Divider(height: 32),
              const Text(
                '정산완료 사이클 통계',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CompletedStatusCard(cycleDocs: completedCycles), 
              const SizedBox(height: 24),
              const Text(
                '정산완료 사이클',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CycleListView(cycleDocs: completedCycles), 
            ],
          );
        },
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