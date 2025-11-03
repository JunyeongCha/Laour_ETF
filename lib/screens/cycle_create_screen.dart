import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CycleCreateScreen extends StatefulWidget {
  const CycleCreateScreen({super.key});

  @override
  State<CycleCreateScreen> createState() => _CycleCreateScreenState();
}

class _CycleCreateScreenState extends State<CycleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _totalSeedController = TextEditingController();
  final _splitCountController = TextEditingController();
  final _targetProfitRateController = TextEditingController();
  final _currentPriceController = TextEditingController(); 
  // (★수정★) 1번: Star 값 컨트롤러 제거
  // final _starValueController = TextEditingController(); 

  bool _isLoading = false;

  Future<void> _createCycle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      // 텍스트를 숫자로 변환
      final double totalSeed = double.tryParse(_totalSeedController.text) ?? 0.0;
      final int splitCount = int.tryParse(_splitCountController.text) ?? 1;
      final double targetProfitRate = double.tryParse(_targetProfitRateController.text) ?? 0.0;
      final double currentPrice = double.tryParse(_currentPriceController.text) ?? 0.0; 
      // (★수정★) 1번: Star 값 변수 제거
      // final double starValue = double.tryParse(_starValueController.text) ?? 0.0; 

      final Map<String, dynamic> cycleData = {
        'name': _nameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'totalSeed': totalSeed,
        'splitCount': splitCount,
        'targetProfitRate': targetProfitRate,
        'createdAt': Timestamp.now(),
        
        'currentPrice': currentPrice, 
        // (★수정★) 1번: starValue 필드 저장 제거
        // 'starValue': starValue,       
        
        // 초기화 필드
        'currentPurchaseAmount': 0.0,
        'totalSellAmount': 0.0,
        'currentQuantity': 0,
        'avgPrice': 0.0,
        'T_value': 0.0, // (★수정★) 2번: T값은 이제 double형이므로 0.0으로 초기화
        'realizedProfit': 0.0, 
        'isManuallyCompleted': false,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cycles')
          .add(cycleData);

      if (mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사이클 생성 실패: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _totalSeedController.dispose();
    _splitCountController.dispose();
    _targetProfitRateController.dispose();
    _currentPriceController.dispose(); 
    // (★수정★) 1번: Star 값 컨트롤러 dispose 제거
    // _starValueController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 사이클 생성'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
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
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _currentPriceController,
                decoration: const InputDecoration(labelText: '현재 주가 (원) (필수)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '현재 주가를 입력하세요.';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '유효한 금액을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // (★수정★) 1번: Star 값 입력 필드 완전히 제거
              // TextFormField( ... ),

              TextFormField(
                controller: _totalSeedController,
                decoration: const InputDecoration(labelText: '총 시드 (원)'),
                keyboardType: TextInputType.number,
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