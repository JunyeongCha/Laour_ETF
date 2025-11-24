// // lib/screens/junyeong_create_screen.dart (★4단계: 3배수 목표수익률 적용★)

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

  final _usCloseRateController = TextEditingController(); // [신규] 종가
  final _afterMarketRateController = TextEditingController(); // [신규] 장외

  final _starValueController = TextEditingController();

  bool _isLoading = false;

  // [!] Step 4.1 + 6: 4개 종목으로 리스트 수정 (PLUS 제외, TIGER(합성) 추가)
  final List<String> _junyeongItems = [
    'TIGER 미국필라델피아반도체레버리지',
    'KODEX 미국나스닥100레버리지',
    'TIGER 미국나스닥100레버리지(합성)', // [!] 신규 추가
    'ACE 미국빅테크TOP7 Plus레버리지'
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
      
      // (★4단계 수정★) "3배수 목표 수익률"을 읽음
      final double targetProfitRate_3x =
          double.tryParse(_targetProfitRateController.text) ?? 0.0;
      
      final double currentPrice =
          double.tryParse(_currentPriceController.text) ?? 0.0;

      final double initialUsClose =
          double.tryParse(_usCloseRateController.text) ?? 0.0;
      final double initialAfterMarket =
          double.tryParse(_afterMarketRateController.text) ?? 0.0;
      
      final double starValue =
          double.tryParse(_starValueController.text) ?? 0.0;

      // (★2-2단계 수정★) k-Factor 할당 로직 확장
      double kMin, kMax, kAvg;
      if (_selectedJunyeongItem == 'TIGER 미국필라델피아반도체레버리지') {
        kMin = 0.2589;
        kMax = 0.9843;
        kAvg = 0.5703;
      } else if (_selectedJunyeongItem == 'KODEX 미국나스닥100레버리지') {
        kMin = 0.3089;
        kMax = 0.7087;
        kAvg = 0.5531;
      } else if (_selectedJunyeongItem == 'TIGER 미국나스닥100레버리지(합성)') {
        kMin = 0.4412;
        kMax = 0.8830;
        kAvg = 0.6621;
      } else if (_selectedJunyeongItem == 'ACE 미국빅테크TOP7 Plus레버리지') {
        kMin = 0.4000;
        kMax = 0.9037;
        kAvg = 0.6512;
      } else {
        // (임시) KODEX 값 사용 (위 리스트 외의 값이 들어올 경우 대비)
        kMin = 0.3089;
        kMax = 0.7087;
        kAvg = 0.5531;
      }

      final Map<String, dynamic> cycleData = {
        'name': _selectedJunyeongItem!, // 선택된 종목명
        'nickname': _nicknameController.text.trim(),
        'totalSeed': totalSeed,
        'splitCount': splitCount,
        
        // (★4단계 수정★) 'targetProfitRate' 대신 'targetProfitRate_3x'로 저장
        'targetProfitRate_3x': targetProfitRate_3x,
        
        'createdAt': Timestamp.now(),

        'currentPrice': currentPrice,

        'type': 'junyeong', // (★핵심★)

        'usCloseRate': initialUsClose,
        'afterMarketRate': initialAfterMarket,
        // 'usMarketRate': initialUsMarketRate, // 삭제 (더 이상 저장 안 함)

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
    _usCloseRateController.dispose();
    _afterMarketRateController.dispose();
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
              // [수정] 1-1단계: 입력 필드 2개로 분리 (Row 사용)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _usCloseRateController,
                      decoration: const InputDecoration(
                        labelText: '[미국] 종가 (%)',
                        helperText: '예: -1.5',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '필수';
                        if (double.tryParse(value) == null) return '숫자만';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _afterMarketRateController,
                      decoration: const InputDecoration(
                        labelText: '[장외] 선물 (%)',
                        helperText: '예: 0.5',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '필수';
                        if (double.tryParse(value) == null) return '숫자만';
                        return null;
                      },
                    ),
                  ),
                ],
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
              
              // (★4단계 수정★)
              TextFormField(
                controller: _targetProfitRateController,
                decoration: const InputDecoration(
                    labelText: '3배수 목표 수익률 (%)', // (★4단계 수정★)
                    helperText: 'TQQQ 기준 3배수 수익률을 입력하세요. (예: 10)'), // (★4단계 수정★)
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