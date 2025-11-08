// // lib/screens/junyeong_create_screen.dart (★2-2단계: k-Factor 확장 완료★)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JunyeongCreateScreen extends StatefulWidget {
  const JunyeongCreateScreen({super.key});

  @override
  State<JunyeongCreateScreen> createState() => _JunyeongCreateScreenState();
}

class _JunyeongCreateScreenState extends State<JunyeongCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _totalSeedController = TextEditingController();
  final _splitCountController = TextEditingController();
  final _targetProfitRateController = TextEditingController();
  final _currentPriceController = TextEditingController();

  final _usMarketRateController = TextEditingController();
  final _starValueController = TextEditingController();

  bool _isLoading = false;

  // (★2-2단계 수정★) ACE, PLUS 종목 추가
  final List<String> _junyeongItems = [
    'TIGER 미국필라델피아반도체레버리지',
    'KODEX 미국나스닥100레버리지',
    'PLUS 미국테크TOP10레버리지',
    'ACE 미국빅테크TOP7 PLUS레버리지'
  ];
  String? _selectedJunyeongItem;

  Future<void> _createCycle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("로그인이 필요합니다.");

      // 텍스트를 숫자로 변환
      final double totalSeed =
          double.tryParse(_totalSeedController.text) ?? 0.0;
      final int splitCount = int.tryParse(_splitCountController.text) ?? 1;
      final double targetProfitRate =
          double.tryParse(_targetProfitRateController.text) ?? 0.0;
      final double currentPrice =
          double.tryParse(_currentPriceController.text) ?? 0.0;

      final double initialUsMarketRate =
          double.tryParse(_usMarketRateController.text) ?? 0.0;
      final double starValue =
          double.tryParse(_starValueController.text) ?? 0.0;

      // (★2-2단계 수정★) k-Factor 할당 로직 확장
      double kMin, kMax, kAvg;
      if (_selectedJunyeongItem == 'TIGER 미국필라델피아반도체레버리지') {
        kMin = 2.68; // [cite: 21]
        kMax = 3.69; // [cite: 21]
        kAvg = 3.185; // [cite: 23]
      } else if (_selectedJunyeongItem == 'KODEX 미국나스닥100레버리지') {
        kMin = 3.47; // [cite: 22]
        kMax = 3.53; // [cite: 22]
        kAvg = 3.50; // 
      } else if (_selectedJunyeongItem == 'PLUS 미국테크TOP10레버리지' ||
                 _selectedJunyeongItem == 'ACE 미국빅테크TOP7 PLUS레버리지') {
        // (★2-2단계★) 요청사항: ACE와 PLUS는 KODEX 값을 임시로 사용
        // TODO: 6단계에서 이 종목들의 k-Factor 확정 필요
        kMin = 3.47; 
        kMax = 3.53; 
        kAvg = 3.50; 
      } else {
        // (임시) TIGER 필반 값 사용 (위 리스트 외의 값이 들어올 경우 대비)
        kMin = 2.68;
        kMax = 3.69;
        kAvg = 3.185;
      }

      final Map<String, dynamic> cycleData = {
        'name': _selectedJunyeongItem!, // 선택된 종목명
        'nickname': _nicknameController.text.trim(),
        'totalSeed': totalSeed,
        'splitCount': splitCount,
        'targetProfitRate': targetProfitRate,
        'createdAt': Timestamp.now(),

        'currentPrice': currentPrice,

        'type': 'junyeong', // (★핵심★)

        'usMarketRate': initialUsMarketRate,

        'starValue': starValue, 

        'kMin': kMin,
        'kMax': kMax,
        'kAvg': kAvg,

        // "준영매수법" Track A/B를 위한 듀얼 지갑 초기화
        // 1. 장기(Track A) 지갑
        'currentPurchaseAmount_A': 0.0,
        'totalSellAmount_A': 0.0,
        'currentQuantity_A': 0,
        'avgPrice_A': 0.0,
        'realizedProfit_A': 0.0,

        // 2. 단기(Track B) 지갑
        'currentPurchaseAmount_B': 0.0,
        'totalSellAmount_B': 0.0,
        'currentQuantity_B': 0,
        'avgPrice_B': 0.0,
        'realizedProfit_B': 0.0,

        // 3. 기존(공통) 집계 변수 (T값, 정산완료 플래그)
        'T_value': 0, 
        'isManuallyCompleted': false,

        'previousClosePrice': 0.0, 
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사이클 생성 실패: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _totalSeedController.dispose();
    _splitCountController.dispose();
    _targetProfitRateController.dispose();
    _currentPriceController.dispose();
    _usMarketRateController.dispose();
    _starValueController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 사이클 생성 (준영)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedJunyeongItem,
                decoration: const InputDecoration(labelText: '종목 (준영매수법)'),
                items: _junyeongItems.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    // (★2-2단계 수정★) 긴 이름이 잘리지 않도록 ellipsis 처리
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedJunyeongItem = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '종목을 선택하세요.';
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return '현재 주가를 입력하세요.';
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return '유효한 금액을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usMarketRateController,
                decoration: const InputDecoration(
                  labelText: '최초 미장 등락율 (%) (필수)',
                  helperText: '예: +3.5% -> 3.5, -5% -> -5.0',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return '등락율을 입력하세요.';
                  if (double.tryParse(value) == null) {
                    return '유효한 숫자를 입력하세요. (예: -2.5)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _starValueController,
                decoration: const InputDecoration(
                  labelText: '초기 3배수 Star 값 (%) (필수)',
                  helperText:
                      '예: TQQQ 3배수 Star 값 입력 시, 2배수 ETF 공식에 맞게 자동 변환됩니다.',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Star 값을 입력하세요.';
                  if (double.tryParse(value) == null) {
                    return '유효한 숫자를 입력하세요. (마이너스 가능)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _totalSeedController,
                decoration: const InputDecoration(labelText: '총 시드 (원)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) return '총 시드를 입력하세요.';
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                decoration: const InputDecoration(
                    labelText: '목표 수익률 (%)', hintText: '예: 10'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return '목표 수익률을 입력하세요.';
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
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