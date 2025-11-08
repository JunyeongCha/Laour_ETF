// lib/screens/home_screen.dart (★"정산 완료" 버그 수정 완료★)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:laour_etf/screens/cycle_create_screen.dart';
import 'package:laour_etf/screens/junyeong_create_screen.dart'; 
import 'package:laour_etf/widgets/completed_status_card.dart'; 
import 'package:laour_etf/widgets/cycle_list_view.dart';
import 'package:laour_etf/widgets/ongoing_status_card.dart'; 
import 'package:provider/provider.dart';
import 'package:laour_etf/screens/my_page_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin { 
  String? _userName;
  Stream<QuerySnapshot>? _cyclesStream;
  User? _user;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      setState(() {});
    });

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
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    final String currentMode = _tabController.index == 0 ? '무매' : '준영';

    return Scaffold(
      appBar: AppBar(
        title: Text(_userName == null
            ? '포트폴리오 ($currentMode)'
            : '$_userName님의 포트폴리오 ($currentMode)'),
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '무매 (Original)'),
            Tab(text: '준영매수법 (New)'),
          ],
        ),
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
            return Center(
              child: Text(
                '아직 생성된 $currentMode 사이클이 없습니다.\n아래 + 버튼을 눌러 시작하세요.', 
                textAlign: TextAlign.center,
              ),
            );
          }

          final allCycleDocs = snapshot.data!.docs;
          
          final int currentTabIndex = _tabController.index;
          final List<QueryDocumentSnapshot> filteredDocs = allCycleDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final String type = data?['type'] ?? 'mumae'; 
            
            if (currentTabIndex == 0) {
              return type == 'mumae';
            } else {
              return type == 'junyeong';
            }
          }).toList();
          
          if (filteredDocs.isEmpty) {
             return Center(
              child: Text(
                '아직 생성된 $currentMode 사이클이 없습니다.\n아래 + 버튼을 눌러 시작하세요.',
                textAlign: TextAlign.center,
              ),
            );
          }

          // --- [★핵심 버그 수정★] "정산 완료" 분류 로직 ---
          final List<QueryDocumentSnapshot> ongoingCycles = [];
          final List<QueryDocumentSnapshot> completedCycles = [];

          for (var doc in filteredDocs) { 
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final String cycleType = data['type'] ?? 'mumae';
            final bool isManuallyCompleted = (data['isManuallyCompleted'] as bool?) ?? false;

            int quantity = 0;
            double purchaseAmount = 0.0;

            if (cycleType == 'junyeong') {
              // "준영"은 A/B 수량/금액 합산
              quantity = ((data['currentQuantity_A'] as num?)?.toInt() ?? 0) +
                         ((data['currentQuantity_B'] as num?)?.toInt() ?? 0);
              purchaseAmount = ((data['currentPurchaseAmount_A'] as num?)?.toDouble() ?? 0.0) +
                               ((data['currentPurchaseAmount_B'] as num?)?.toDouble() ?? 0.0);
            } else {
              // "무매"는 기존 필드 사용
              quantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
              purchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
            }

            // (★수정된 로직★)
            if (isManuallyCompleted || (quantity == 0 && purchaseAmount > 0)) {
              completedCycles.add(doc);
            } else {
              ongoingCycles.add(doc);
            }
          }
          // --- [버그 수정 끝] ---

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- 진행중 섹션 ---
              const Text(
                '진행중 사이클 상황',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // (★수정★) 이제 이 카드는 A/B 데이터를 읽을 수 있습니다.
              OngoingStatusCard(cycleDocs: ongoingCycles), 
              const SizedBox(height: 24),
              const Text(
                '진행중 사이클',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // (★수정★) 이 리스트뷰는 "진행중" 사이클만 표시합니다.
              CycleListView(cycleDocs: ongoingCycles), 
              
              // --- 정산완료 섹션 ---
              const SizedBox(height: 24),
              const Divider(height: 32),
              const Text(
                '정산완료 사이클 통계',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // (★수정★) 이제 이 카드는 A/B 데이터를 읽을 수 있습니다.
              CompletedStatusCard(cycleDocs: completedCycles), 
              const SizedBox(height: 24),
              const Text(
                '정산완료 사이클',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // (★수정★) 이 리스트뷰는 "정산 완료" 사이클만 표시합니다.
              CycleListView(cycleDocs: completedCycles), 
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(_tabController.index == 0 ? Icons.add : Icons.add_chart),
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CycleCreateScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const JunyeongCreateScreen()),
            );
          }
        },
      ),
    );
  }
}