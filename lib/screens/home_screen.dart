import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/auth/auth_service.dart';
import 'package:laour_etf/screens/cycle_create_screen.dart';
// (★신규★) 준영매수법 생성 화면 임포트
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

// (★수정★) TabController를 사용하기 위해 'SingleTickerProviderStateMixin' 추가
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin { 
  String? _userName;
  Stream<QuerySnapshot>? _cyclesStream;
  User? _user;

  // (★신규★) 탭 컨트롤러
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    
    // (★신규★) 탭 컨트롤러 초기화
    _tabController = TabController(length: 2, vsync: this);
    
    // (★신규★) 탭이 변경될 때마다 FAB를 다시 그리도록 setState 호출
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
  
  // (★신규★) dispose에서 컨트롤러 해제
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

    // (★신규★) 현재 선택된 탭 이름
    final String currentMode = _tabController.index == 0 ? '무매' : '준영';

    return Scaffold(
      appBar: AppBar(
        title: Text(_userName == null
            ? '포트폴리오 ($currentMode)' // (★수정★)
            : '$_userName님의 포트폴리오 ($currentMode)'), // (★수정★)
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
        // (★신규★) AppBar 하단에 탭 바 추가
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
                '아직 생성된 $currentMode 사이클이 없습니다.\n아래 + 버튼을 눌러 시작하세요.', // (★수정★)
                textAlign: TextAlign.center,
              ),
            );
          }

          final allCycleDocs = snapshot.data!.docs;
          
          // (★신규★) 현재 탭 인덱스에 따라 사이클 필터링
          final int currentTabIndex = _tabController.index;
          final List<QueryDocumentSnapshot> filteredDocs = allCycleDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            // (★중요★) type 필드가 없으면 '무매'(인덱스 0)로 간주
            final String type = data?['type'] ?? 'mumae'; 
            
            if (currentTabIndex == 0) {
              return type == 'mumae'; // "무매" 탭
            } else {
              return type == 'junyeong'; // "준영" 탭
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

          // --- [기존 로직 재사용] 필터링된 문서를 기반으로 정렬 ---
          final List<QueryDocumentSnapshot> ongoingCycles = [];
          final List<QueryDocumentSnapshot> completedCycles = [];

          for (var doc in filteredDocs) { // (★수정★) allCycleDocs -> filteredDocs
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
        // (★수정★) 탭에 따라 아이콘 변경 (선택적)
        child: Icon(_tabController.index == 0 ? Icons.add : Icons.add_chart),
        onPressed: () {
          // (★신규★) 탭 인덱스에 따라 다른 생성 화면으로 이동
          if (_tabController.index == 0) {
            // "무매" 탭
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CycleCreateScreen()),
            );
          } else {
            // "준영" 탭
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