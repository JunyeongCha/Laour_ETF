// lib/screens/cycle_create_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  // 1. 폼의 상태를 관리하기 위한 글로벌 키
  final _formKey = GlobalKey<FormState>();

  // 2. 각 텍스트 필드의 입력을 제어하기 위한 컨트롤러
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController(); // 닉네임 (선택)
  final _totalSeedController = TextEditingController();
  final _splitCountController = TextEditingController();
  final _targetProfitRateController = TextEditingController();

  // 3. Firestore 저장 시 로딩 상태를 표시하기 위한 변수
  bool _isLoading = false;

  // 4. (★핵심★) Firestore에 사이클 저장 함수
  Future<void> _createCycle() async {
    // 4-1. 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      return; // 유효성 검사 실패 시 중단
    }

    // 4-2. 로딩 시작
    setState(() {
      _isLoading = true;
    });

    try {
      // 4-3. 현재 로그인한 사용자 정보 가져오기
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("로그인이 필요합니다.");
      }

      // 4-4. 텍스트를 숫자로 변환
      final double totalSeed = double.tryParse(_totalSeedController.text) ?? 0.0;
      final int splitCount = int.tryParse(_splitCountController.text) ?? 1;
      final double targetProfitRate = double.tryParse(_targetProfitRateController.text) ?? 0.0;

      // 4-5. Firestore에 저장할 데이터 맵 생성 [cite: 37]
      final Map<String, dynamic> cycleData = {
        'name': _nameController.text.trim(), // 종목명 [cite: 37]
        'nickname': _nicknameController.text.trim(), // 닉네임
        'totalSeed': totalSeed, // 총 시드 (원) [cite: 37]
        'splitCount': splitCount, // 분할수 [cite: 37]
        'targetProfitRate': targetProfitRate, // 목표 수익률 (%) [cite: 37]
        'createdAt': Timestamp.now(), // 생성일
        
        // (★중요★) 2단계/4단계에서 사용할 필드들 초기화
        'currentPurchaseAmount': 0.0, // 현재 총 매입 금액 (OverallStatusCard용)
        'currentQuantity': 0,       // 현재 보유 수량 (CycleCard 정렬용)
        'avgPrice': 0.0,            // 평단가 (CycleCard 표시용)
      };

      // 4-6. (★핵심★) Firestore 'cycles' 하위 컬렉션에 문서 추가 
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cycles')
          .add(cycleData);

      // 4-7. 저장 성공 시, 홈 화면으로 복귀 
      if (mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      // 4-8. 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사이클 생성 실패: ${e.toString()}'))
        );
      }
    } finally {
      // 4-9. 로딩 종료
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 5. 컨트롤러 메모리 해제
  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _totalSeedController.dispose();
    _splitCountController.dispose();
    _targetProfitRateController.dispose();
    super.dispose();
  }

  // 6. UI 빌드
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 사이클 생성'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // 폼 위젯으로 감싸 유효성 검사 활성화
        child: Form(
          key: _formKey,
          // 키보드가 올라올 때 화면이 밀리도록 ListView 사용
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름 (예: TIGER 나스닥100)'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: '닉네임 (선택)'),
                // 닉네임은 선택 사항이므로 validator 없음
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalSeedController,
                decoration: const InputDecoration(labelText: '총 시드 (원)'),
                keyboardType: TextInputType.number, // 숫자 키보드
                validator: (value) {
                  if (value == null || value.isEmpty) return '총 시드를 입력하세요.';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '유효한 금액을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _splitCountController,
                decoration: const InputDecoration(labelText: '분할수 (예: 40)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '분할수를 입력하세요.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '유효한 숫자를 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetProfitRateController,
                decoration: const InputDecoration(labelText: '목표 수익률 (%)', hintText: '예: 10'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '목표 수익률을 입력하세요.';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '유효한 수익률을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // (★핵심★) 생성 버튼
              // 로딩 중이면 스피너, 아니면 버튼 표시
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _createCycle,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('사이클 생성'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}