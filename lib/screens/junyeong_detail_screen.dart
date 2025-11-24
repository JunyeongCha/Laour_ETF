// // lib/screens/junyeong_detail_screen.dart (★오류 수정본★)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:laour_etf/widgets/cycle_detail/trade_input_dialog.dart';
import 'package:laour_etf/widgets/cycle_detail/transaction_list.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/providers/theme_provider.dart';
import 'package:laour_etf/junyeong_constants.dart'; // [추가]
import 'package:laour_etf/junyeong_logic.dart';     // [추가]

class JunyeongDetailScreen extends StatefulWidget {
  final String cycleId;
  const JunyeongDetailScreen({super.key, required this.cycleId});

  @override
  State<JunyeongDetailScreen> createState() => _JunyeongDetailScreenState();
}

class _JunyeongDetailScreenState extends State<JunyeongDetailScreen> {
  // 1. Firestore 참조
  late final DocumentReference _cycleRef;
  late final CollectionReference _transactionsRef;
  late final Stream<DocumentSnapshot> _cycleStream;
  late final Stream<QuerySnapshot> _transactionStream;

  // 2. 실시간 입력을 위한 컨트롤러
  // PDF(v3.0) 5대 필수 입력값
  final _currentPriceController = TextEditingController(); // 현재 주가
  final _previousClosePriceController =
      TextEditingController(); // 어제 종가
  
  // [수정] 1-1단계: 등락률 입력 분리 (종가 + 장외)
  // final _usMarketRateController = TextEditingController(); // 삭제
  final _usCloseRateController = TextEditingController(); // [신규] 미국 종가
  final _afterMarketRateController = TextEditingController(); // [신규] 장외(After)
  
  final _starValueController = TextEditingController(); // 3배수 Star 값
  final _shortTermBuyAmountController =
      TextEditingController(); // 단기 매수 금액

  // 3. 수정용 컨트롤러
  final _nameEditController = TextEditingController();
  final _nicknameEditController = TextEditingController();
  final _totalSeedEditController = TextEditingController();

  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;

    _cycleRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cycles')
        .doc(widget.cycleId);

    _transactionsRef = _cycleRef.collection('transactions');

    _cycleStream = _cycleRef.snapshots();
    // (★수정★) isShortTerm 필드를 기준으로 정렬 (장기 -> 단기 순)
    // (★버그 수정★)
    // orderBy를 2개 필드(isShortTerm, date)에 사용하면
    // Firestore "복합 색인"이 필요합니다.
    // 색인 생성 없이 즉시 동작하도록, date 기준으로만 정렬합니다.
    // (TransactionList가 (장기 A)/(단기 B) 태그를 표시하므로
    //  날짜 정렬만으로도 충분합니다.)
    _transactionStream = _transactionsRef
        .orderBy('date', descending: true)
        .snapshots();

  // 5대 입력값 리스너 추가
    _currentPriceController.addListener(_updateRealTimeProfit);
    _previousClosePriceController.addListener(_updateRealTimeProfit);
    // [수정] 리스너 변경
    // _usMarketRateController.addListener(_updateRealTimeProfit); // 삭제
    _usCloseRateController.addListener(_updateRealTimeProfit); // [신규]
    _afterMarketRateController.addListener(_updateRealTimeProfit); // [신규]
    _starValueController.addListener(_updateRealTimeProfit);
    _shortTermBuyAmountController.addListener(_updateRealTimeProfit);

    _cycleStream.first.then((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        final double price = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;
        _currentPriceController.text = price.toString();

        _previousClosePriceController.text =
            (data['previousClosePrice'] as num?)?.toString() ?? '0.0';
            
        // [수정] 저장된 종가/장외 데이터 로드 (없으면 0.0)
        // 기존 'usMarketRate' 필드는 더 이상 사용하지 않거나, 마이그레이션 필요 시 처리
        _usCloseRateController.text = 
            (data['usCloseRate'] as num?)?.toString() ?? '0.0'; // [신규 필드]
        _afterMarketRateController.text = 
            (data['afterMarketRate'] as num?)?.toString() ?? '0.0'; // [신규 필드]
            
        _starValueController.text =
            (data['starValue'] as num?)?.toString() ?? '0.0';

        // '단기 매수 금액'은 앱 추천값으로 매번 덮어쓰므로 컨트롤러에 로드하지 않음
      }
    });
  }

  void _updateRealTimeProfit() {
    if (mounted) {
      setState(() {
        // build 메서드가 실시간 손익/지침을 재계산
      });
    }
  }

  // (★핵심 수정★) _recalculateAggregates (Dual Wallet)
  // PDF(v3.0) 요구사항: Track A (isShortTerm: false) / Track B (isShortTerm: true)
  // 두 개의 지갑을 독립적으로 집계
  Future<void> _recalculateAggregates() async {
    if (mounted) {
      setState(() {
        _isRecalculating = true;
      });
    }

    try {
      final QuerySnapshot snapshot = await _transactionsRef.get();
      final allTrades = snapshot.docs;

      // --- 집계 변수 초기화 ---
      // [공통]
      Set<String> uniqueDates = {};
      // [Track A: 장기]
      double totalBuyCost_A = 0.0;
      int totalBuyQuantity_A = 0;
      // [Track B: 단기]
      double totalBuyCost_B = 0.0;
      int totalBuyQuantity_B = 0;

      // --- [Pass 1] 평단가(Avg. Purchase Price) 계산 (A/B 분리) ---
      for (var doc in allTrades) {
        final data = doc.data() as Map<String, dynamic>;

        final DateTime date = (data['date'] as Timestamp).toDate();
        uniqueDates.add(DateFormat('yyyy-MM-dd').format(date));

        final bool isShortTerm = (data['isShortTerm'] as bool?) ?? false;

        if (data['type'] == 'buy') {
          final double cost =
              (data['price'] as num).toDouble() * (data['quantity'] as num).toInt();
          final int quantity = (data['quantity'] as num).toInt();

          if (isShortTerm) {
            // Track B
            totalBuyCost_B += cost;
            totalBuyQuantity_B += quantity;
          } else {
            // Track A
            totalBuyCost_A += cost;
            totalBuyQuantity_A += quantity;
          }
        }
      }

      final double avgPrice_A = (totalBuyQuantity_A == 0)
          ? 0.0
          : (totalBuyCost_A / totalBuyQuantity_A);
      final double avgPrice_B = (totalBuyQuantity_B == 0)
          ? 0.0
          : (totalBuyCost_B / totalBuyQuantity_B);

      // --- [Pass 2] 실현 손익 및 현재 수량 계산 (A/B 분리) ---
      // [Track A: 장기]
      double totalSellAmount_A = 0.0;
      int totalSellQuantity_A = 0;
      double totalRealizedProfit_A = 0.0;
      // [Track B: 단기]
      double totalSellAmount_B = 0.0;
      int totalSellQuantity_B = 0;
      double totalRealizedProfit_B = 0.0;

      for (var doc in allTrades) {
        final data = doc.data() as Map<String, dynamic>;
        final bool isShortTerm = (data['isShortTerm'] as bool?) ?? false;

        if (data['type'] == 'sell') {
          final double price = (data['price'] as num).toDouble();
          final int quantity = (data['quantity'] as num).toInt();
          final double amount = price * quantity;

          if (isShortTerm) {
            // Track B
            totalSellAmount_B += amount;
            totalSellQuantity_B += quantity;
            totalRealizedProfit_B += (price - avgPrice_B) * quantity;
          } else {
            // Track A
            totalSellAmount_A += amount;
            totalSellQuantity_A += quantity;
            totalRealizedProfit_A += (price - avgPrice_A) * quantity;
          }
        }
      }

      // --- [Final] 최종 집계 ---
      final int currentQuantity_A = totalBuyQuantity_A - totalSellQuantity_A;
      final int currentQuantity_B = totalBuyQuantity_B - totalSellQuantity_B;
      final int tValue = uniqueDates.length;

      if (currentQuantity_A < 0 || currentQuantity_B < 0) {
        throw Exception("계산 결과 보유 수량이 음수입니다.");
      }

      // (★수정★) Firestore에 듀얼 지갑 상태로 업데이트
      await _cycleRef.update({
        // [Track A]
        'currentPurchaseAmount_A': totalBuyCost_A,
        'avgPrice_A': avgPrice_A,
        'currentQuantity_A': currentQuantity_A,
        'totalSellAmount_A': totalSellAmount_A,
        'realizedProfit_A': totalRealizedProfit_A,
        // [Track B]
        'currentPurchaseAmount_B': totalBuyCost_B,
        'avgPrice_B': avgPrice_B,
        'currentQuantity_B': currentQuantity_B,
        'totalSellAmount_B': totalSellAmount_B,
        'realizedProfit_B': totalRealizedProfit_B,
        // [공통]
        'T_value': tValue,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('재계산 실패: ${e.toString()}')));
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isRecalculating = false;
        });
      }
    }
  }

  // (★핵심 수정★) "간편 입력" 버튼 로직 (Dual Wallet)
  void _onAddNewTrade() async {
    final DocumentSnapshot currentDoc = await _cycleRef.get();
    final data = currentDoc.data() as Map<String, dynamic>;

    // (★수정★) 듀얼 지갑의 수량 확인
    final int currentQuantity_A = data['currentQuantity_A'] ?? 0;
    final int currentQuantity_B = data['currentQuantity_B'] ?? 0;

    // (★수정★) 'isJunyeongMode' 플래그 전달
    final Map<String, dynamic>? newTrade = await TradeInputDialog.show(
      context,
      isJunyeongMode: true, //
    );

    if (newTrade != null) {
      final bool isShortTerm = newTrade['isShortTerm']; //
      final int quantity = newTrade['quantity'];
      final String type = newTrade['type'];
      
      // [수정] 1-1단계: x값 임시 계산 (단순 합산 -> 추후 로직으로 대체)
      // 현재는 컨트롤러가 분리되었으므로, 임시로 두 값을 더해서 x로 씁니다. (에러 방지용)
      // 1-2단계에서 진짜 X' 계산 로직이 들어갑니다.
      final double tempClose = double.tryParse(_usCloseRateController.text) ?? 0.0;
      final double tempAfter = double.tryParse(_afterMarketRateController.text) ?? 0.0;
      final double x = tempClose + tempAfter; 

      // (★수정★) 매도 가능 수량 체크 (A/B 분리)
      if (type == 'sell') {
        if (isShortTerm && quantity > currentQuantity_B) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('단기(Track B) 보유 주식수보다 많이 매도할 수 없습니다.')),
            );
          }
          return;
        }
        if (!isShortTerm && quantity > currentQuantity_A) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('장기(Track A) 보유 주식수보다 많이 매도할 수 없습니다.')),
            );
          }
          return;
        }
      }

      final double newPrice = newTrade['price'];

      // (★핵심 로직★) PDF(v3.0) 하락장(x < 0) 롤오버
    // [!] Step 6: v3.0 하락장 자동 롤오버 로직 "폐기"

      await _transactionsRef.add({
        'date': Timestamp.fromDate(newTrade['date']),
        'price': newPrice,
        'quantity': newTrade['quantity'],
        'type': newTrade['type'],
        'isShortTerm': isShortTerm, // [!] finalIsShortTerm 대신 원본 isShortTerm 사용
      });

      if (mounted) {
        _currentPriceController.text = newPrice.toString();
      }

      await _cycleRef.update({'currentPrice': newPrice});
      await _recalculateAggregates();
    }
  }

  // (★핵심 수정★) "X" 삭제 버튼 로직 (Dual Wallet)
  // 매수 삭제 시, A/B 지갑의 수량이 음수가 되는지 각각 확인해야 함
  void _onDeleteTrade(String transactionId, String type, int quantity,
      DateTime date, double price, bool isShortTerm) async {
    final DocumentSnapshot currentDoc = await _cycleRef.get();
    final data = currentDoc.data() as Map<String, dynamic>;

    final int currentQuantity_A = data['currentQuantity_A'] ?? 0;
    final int currentQuantity_B = data['currentQuantity_B'] ?? 0;

    if (type == 'buy') {
      if (isShortTerm && currentQuantity_B < quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    '단기(Track B) 매수 내역 삭제 시 보유주식수가 음수가 됩니다.')),
          );
        }
        return;
      }
      if (!isShortTerm && currentQuantity_A < quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    '장기(Track A) 매수 내역 삭제 시 보유주식수가 음수가 됩니다.')),
          );
        }
        return;
      }
    }

    try {
      await _transactionsRef.doc(transactionId).delete();
      await _recalculateAggregates();
    } catch (e) {
      if (e.toString().contains("보유 수량이 음수")) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('오류: 보유 수량이 음수가 됩니다. 삭제를 취소합니다.')),
          );
        }
        // 삭제 롤백 (Undo)
        await _transactionsRef.doc(transactionId).set({
          'date': Timestamp.fromDate(date),
          'price': price,
          'quantity': quantity,
          'type': type,
          'isShortTerm': isShortTerm,
        });
        await _recalculateAggregates();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('삭제/계산 중 알 수 없는 오류: ${e.toString()}')));
        }
      }
    }
  }

  // (★핵심 수정★) 5대 필수 입력값 저장
  Future<void> _saveCurrentData() async {
    try {
      final double price =
          double.tryParse(_currentPriceController.text) ?? 0.0;
      
      // [수정] 분리된 입력값 파싱
      final double usClose = double.tryParse(_usCloseRateController.text) ?? 0.0;
      final double afterMarket = double.tryParse(_afterMarketRateController.text) ?? 0.0;
      
      final double star = double.tryParse(_starValueController.text) ?? 0.0;
      final double prevClose =
          double.tryParse(_previousClosePriceController.text) ?? 0.0;

      await _cycleRef.update({
        'currentPrice': price,
        // [수정] DB 필드 변경 (usMarketRate -> usCloseRate, afterMarketRate)
        'usCloseRate': usClose,
        'afterMarketRate': afterMarket,
        'starValue': star,
        'previousClosePrice': prevClose, 
      });

      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현재가 / 어제종가 / 미장 / Star 값이 저장되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: ${e.toString()}')));
      }
    }
  }

  // (★신규★) "롤오버" 버튼 로직
  // Track B -> Track A
  Future<void> _performRollover() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('단기 물량 롤오버'),
            content: const Text(
                '정말 모든 단기(Track B) 물량을 장기(Track A) 물량으로 합산(롤오버)하시겠습니까?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('실행')),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isRecalculating = true;
    });

    try {
      // 1. 롤오버 대상 트랜잭션 (단기 물량) 찾기
      final QuerySnapshot shortTermTrades = await _transactionsRef
          .where('isShortTerm', isEqualTo: true)
          .get();

      // 2. Batch Write (일괄 작업) 준비
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in shortTermTrades.docs) {
        // 3. 'isShortTerm' 플래그를 false (장기)로 변경하고, "롤오버" 깃발을 추가
        batch.update(doc.reference, {
          'isShortTerm': false,
          'wasRolledOver': true, // <-- "롤오버 되었음" 깃발(Tag) 추가
        });
      }

      // 4. 일괄 작업 실행
      await batch.commit();

      // 5. 듀얼 지갑 재집계
      await _recalculateAggregates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('롤오버 완료: 단기 물량이 장기로 합산되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('롤오버 실패: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecalculating = false;
        });
      }
    }
  }

  // (★유지★) 이름/닉네임/총 시드 수정 다이얼로그 (무매와 동일)
  Future<void> _showEditInfoDialog(
      String currentName, String currentNickname, double currentSeed) async {
    _nameEditController.text = currentName;
    _nicknameEditController.text = currentNickname;
    _totalSeedEditController.text = currentSeed.toStringAsFixed(0);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        // ... (내용 동일) ...
        return AlertDialog(
          title: const Text('사이클 정보 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameEditController,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                TextField(
                  controller: _nicknameEditController,
                  decoration: const InputDecoration(labelText: '닉네임 (선택)'),
                ),
                TextField(
                  controller: _totalSeedEditController,
                  decoration: const InputDecoration(labelText: '총 시드 (원)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('저장'),
              onPressed: () async {
                final String newName = _nameEditController.text.trim();
                final String newNickname = _nicknameEditController.text.trim();
                final double newSeed =
                    double.tryParse(_totalSeedEditController.text) ?? 0.0;

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이름은 비워둘 수 없습니다.')),
                  );
                  return;
                }

                if (newSeed <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('총 시드는 0보다 커야 합니다.')),
                  );
                  return;
                }

                try {
                  await _cycleRef.update({
                    'name': newName,
                    'nickname': newNickname,
                    'totalSeed': newSeed,
                  });
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('수정 실패: ${e.toString()}')));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // (★유지★) 수동 정산 완료 (무매와 동일)
  Future<void> _markAsCompleted() async {
    // ... (내용 동일) ...
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('수동 정산 완료'),
            content: const Text('이 사이클을 "정산 완료"로 처리하시겠습니까?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('완료')),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _cycleRef.update({'isManuallyCompleted': true});
        if (mounted) Navigator.pop(context); // Go back to home
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('정산 완료 처리 실패: ${e.toString()}')));
        }
      }
    }
  }

  @override
  void dispose() {
    _currentPriceController.removeListener(_updateRealTimeProfit);
    _previousClosePriceController.removeListener(_updateRealTimeProfit);
    // [수정] 리스너 해제
    // _usMarketRateController.removeListener(_updateRealTimeProfit);
    _usCloseRateController.removeListener(_updateRealTimeProfit);
    _afterMarketRateController.removeListener(_updateRealTimeProfit);
    
    _starValueController.removeListener(_updateRealTimeProfit);
    _shortTermBuyAmountController.removeListener(_updateRealTimeProfit);
    
    _currentPriceController.dispose();
    _previousClosePriceController.dispose();
    // [수정] 컨트롤러 해제
    // _usMarketRateController.dispose();
    _usCloseRateController.dispose();
    _afterMarketRateController.dispose();
    
    _starValueController.dispose();
    _shortTermBuyAmountController.dispose();
    _nameEditController.dispose();
    _nicknameEditController.dispose();
    _totalSeedEditController.dispose();
    super.dispose();
  }

  // (★핵심★) Build 메서드 (UI 렌더링)
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor =
        isDarkMode ? Colors.white70 : Colors.grey.shade700;

    return StreamBuilder<DocumentSnapshot>(
      stream: _cycleStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isRecalculating) {
          return Scaffold(
            appBar: AppBar(title: const Text('...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('오류')),
            body: const Center(child: Text('사이클을 찾을 수 없습니다.')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        // (A. 기본 변수)
        final String name = data['name'] ?? '이름 없음';
        final String nickname = data['nickname'] ?? '';
        final double totalSeed = (data['totalSeed'] as num?)?.toDouble() ?? 0.0;
        final int splitCount = (data['splitCount'] as num?)?.toInt() ?? 1;

        // (★4단계 수정★) 3배수 목표수익률을 '읽기만' 함
        final double targetProfitRate_3x = (data['targetProfitRate_3x'] as num?)?.toDouble() ?? 0.0;
        
        final double oneTimeInvestment =
            (splitCount == 0) ? 0 : (totalSeed / splitCount);

        // (B. k-Factors)
        final double kMin = (data['kMin'] as num?)?.toDouble() ?? 3.185;
        final double kMax = (data['kMax'] as num?)?.toDouble() ?? 3.185;
        final double kAvg = (data['kAvg'] as num?)?.toDouble() ?? 3.185;

        // (★4단계 오류 수정★) kAvg를 선언한 '직후'에 실제 목표수익률 계산
        // [!] Step 4.1 + 6: kAvg를 곱하는 공식으로 "전부" 수정
        final double targetProfitRate = targetProfitRate_3x * kAvg;

        // (C. 핵심 상태 변수 - 듀얼 지갑)
        // [Track A: 장기]
        final double avgPrice_A = (data['avgPrice_A'] as num?)?.toDouble() ?? 0.0;
        final int currentQuantity_A =
            (data['currentQuantity_A'] as num?)?.toInt() ?? 0;
        final double currentPurchaseAmount_A =
            (data['currentPurchaseAmount_A'] as num?)?.toDouble() ?? 0.0;
        final double realizedProfit_A =
            (data['realizedProfit_A'] as num?)?.toDouble() ?? 0.0;
        final double totalSellAmount_A = // (★3단계-3★) 폭락장 계산을 위해 A/B 분리
            (data['totalSellAmount_A'] as num?)?.toDouble() ?? 0.0;
        // [Track B: 단기]
        final double avgPrice_B = (data['avgPrice_B'] as num?)?.toDouble() ?? 0.0;
        final int currentQuantity_B =
            (data['currentQuantity_B'] as num?)?.toInt() ?? 0;
        final double currentPurchaseAmount_B =
            (data['currentPurchaseAmount_B'] as num?)?.toDouble() ?? 0.0;
        final double realizedProfit_B =
            (data['realizedProfit_B'] as num?)?.toDouble() ?? 0.0;
        // [공통]
        final int tValue = (data['T_value'] as num?)?.toInt() ?? 0;
        final bool isManuallyCompleted =
            (data['isManuallyCompleted'] as bool?) ?? false;

        // (D. 컨트롤러 실시간 값)
        final double currentPrice =
            double.tryParse(_currentPriceController.text) ?? 0.0;
        final double previousClosePrice =
            double.tryParse(_previousClosePriceController.text) ??
                0.0; // 어제 종가
        
        // [수정] 1-1단계: x값 임시 계산 (UI 렌더링용)
        // 1-2단계에서 Logic 클래스로 정식 계산 예정
        final double _tempClose = double.tryParse(_usCloseRateController.text) ?? 0.0;
        final double _tempAfter = double.tryParse(_afterMarketRateController.text) ?? 0.0;
        // 일단 단순 합산으로 x를 정의해둠 (에러 방지)
        final double x = _tempClose + _tempAfter; 
        
        final double starValue_3x =
            double.tryParse(_starValueController.text) ?? 0.0; // 3배수 Star

        // (E. Track A: "무매" 공식 계산)
        // [!] Step 4.1 + 6: kAvg를 곱하는 공식으로 "전부" 수정
        final double starValue = starValue_3x * kAvg;

        final bool isFirstBuy_A = (avgPrice_A == 0 && currentQuantity_A == 0);
        final double displayAvgPrice_A =
            isFirstBuy_A ? currentPrice : avgPrice_A;

        final double calcBuyPrice_A =
            displayAvgPrice_A * (1 + (starValue / 100));

        // (★3단계-2★) 1회 투자금 총액 5-Tier 동적 조절
        double totalDailyInvestment = oneTimeInvestment; // 1.0배 (기본)
        if (x < -4.5) {
          totalDailyInvestment = oneTimeInvestment * 2.0; // 2.0배
        } else if (x < -1.5) {
          totalDailyInvestment = oneTimeInvestment * 1.5; // 1.5배
        } else if (x <= 1.5) {
          totalDailyInvestment = oneTimeInvestment * 1.0; // 1.0배 (보합)
        } else if (x <= 4.5) {
          totalDailyInvestment = oneTimeInvestment * 0.75; // 0.75배
        } else { // x > 4.5
          totalDailyInvestment = oneTimeInvestment * 0.4; // 0.4배
        }

        // (★3단계-2★) 50:50 비중 분배
        final double avgBuyAmount = totalDailyInvestment * 0.5;
        final double starBuyAmount = totalDailyInvestment * 0.5;

        final double buyQtyAtAvg_A = (displayAvgPrice_A == 0)
            ? 0
            : (avgBuyAmount / displayAvgPrice_A);
        final double buyQtyAtStar_A = (calcBuyPrice_A == 0)
            ? 0
            : (starBuyAmount / calcBuyPrice_A);

        final double sellPrice1_A = calcBuyPrice_A + 1;
        final double sellQty1_A = currentQuantity_A / 4.0;
        final double sellPrice2_A =
            displayAvgPrice_A * (1 + (targetProfitRate / 100));
        final double sellQty2_A = currentQuantity_A * 3.0 / 4.0;

        // (F. Track B: "준영" 공식 계산)
        // [!] Step 4.1 + 6: 예측 범위 계산 (하락 시 변수명 수정)
        double predKrMinRate = 0.0;
        double predKrMaxRate = 0.0;
        double predKrMinPx = 0.0;
        double predKrMaxPx = 0.0;
        double predHighestPx = 0.0; // 하락 시 덜 떨어진 가격
        double predLowestPx = 0.0; // 하락 시 더 떨어진 가격

        if (x > 0) {
          predKrMinRate = x * kMin;
          predKrMaxRate = x * kMax;
          predKrMinPx = previousClosePrice * (1 + (predKrMinRate / 100));
          predKrMaxPx = previousClosePrice * (1 + (predKrMaxRate / 100));
        } else if (x < 0) {
          double predRate_LessFall = x * kMin; // 덜 떨어짐 (e.g., -2.5%)
          double predRate_MoreFall = x * kMax; // 더 떨어짐 (e.g., -3.5%)
          predHighestPx = previousClosePrice * (1 + (predRate_LessFall / 100));
          predLowestPx = previousClosePrice * (1 + (predRate_MoreFall / 100));
        }

        // [!] v3.0의 _shortTermBuyAmountController 관련 로직 (finalBuyAmount_B, WidgetsBinding) "전부 삭제"

        // --- [!] Track B 로직 (Step 6) ---
        bool showTrackB = x.abs() > 3.0; // 3% 룰

        // Case 1: 3% 초과 상승
        // Case 1: 3% 초과 상승
        double recommendedBuyAmount_B = 0.0;
        double sellTargetPx1_B = 0.0,
            sellTargetPx2_B = 0.0,
            sellTargetPx3_B = 0.0,
            sellTargetPx4_B = 0.0,
            sellTargetPx5_B = 0.0;
        double sellQty1_B = 0.0, // [!] 소수점
            sellQty2_B = 0.0,
            sellQty3_B = 0.0,
            sellQty4_B = 0.0,
            sellQty5_B = 0.0;

        if (showTrackB && x > 0) {
          // 1순위: 시장가 매수
          recommendedBuyAmount_B = oneTimeInvestment * (1 + ((x * kAvg)/5));

          // 2순위: 4분할 지정가 매도 (가격은 항상 계산)
          // 2순위: 5분할 지정가 매도 (가격은 항상 계산)
          // [!] 3단계 수정: 5분할 가격 공식 적용
          final double kAvgRate_Rise = x * kAvg;
          final double kAvgPrice_Rise = previousClosePrice * (1 + (kAvgRate_Rise / 100));

          sellTargetPx1_B = predKrMinPx; // Px1 = Min
          sellTargetPx5_B = predKrMaxPx; // Px5 = Max
          sellTargetPx3_B = kAvgPrice_Rise; // Px3 = kAvg
          sellTargetPx2_B = (sellTargetPx1_B + sellTargetPx3_B) / 2; // Px2
          sellTargetPx4_B = (sellTargetPx3_B + sellTargetPx5_B) / 2; // Px4

          if (currentQuantity_B > 0) {
            // [!] 로직 2: 이미 단기 물량이 있으면, "보유 물량" 기준으로 수량 계산
            // [!] 3단계 수정: 15/20/30/20/15 비율
            sellQty1_B = currentQuantity_B * 0.15;
            sellQty2_B = currentQuantity_B * 0.20;
            sellQty3_B = currentQuantity_B * 0.30;
            sellQty4_B = currentQuantity_B * 0.20;
            sellQty5_B = currentQuantity_B * 0.15;
          } else {
            // [!] 로직 1: 단기 물량이 0주면, "예측샷" 수량 계산
            // 예측 시초가 = 어제 종가 * (1 + x * kMin * 0.30)
            final double assumedMarketOpenPrice = previousClosePrice * (1 + (x * kMin * 0.30) / 100);
            
            if (assumedMarketOpenPrice > 0) {
              final double assumedBuyQuantity_B = recommendedBuyAmount_B / assumedMarketOpenPrice;
              
              // [!] 3단계 수정: 15/20/30/20/15 비율
              sellQty1_B = assumedBuyQuantity_B * 0.15;
              sellQty2_B = assumedBuyQuantity_B * 0.20;
              sellQty3_B = assumedBuyQuantity_B * 0.30;
              sellQty4_B = assumedBuyQuantity_B * 0.20;
              sellQty5_B = assumedBuyQuantity_B * 0.15;
            }
          }
        }

        // Case 2: 3% 초과 하락
        // [!] 2단계 수정: Track B 변수로 변경 (A -> B)
        double totalBuyAmount_B_Down = 0.0;
        double buyTargetPx1_B_Down = 0.0,
            buyTargetPx2_B_Down = 0.0,
            buyTargetPx3_B_Down = 0.0,
            buyTargetPx4_B_Down = 0.0,
            buyTargetPx5_B_Down = 0.0;
        double buyQty1_B_Down = 0.0, // [!] 소수점
            buyQty2_B_Down = 0.0,
            buyQty3_B_Down = 0.0,
            buyQty4_B_Down = 0.0,
            buyQty5_B_Down = 0.0;
        double sellRecoverPx1_B = 0.0, sellRecoverPx2_B = 0.0;
        double sellRecoverQty1_B = 0.0, sellRecoverQty2_B = 0.0; // [!] 소수점

        if (showTrackB && x < 0) {
          // 1순위: 4분할 지정가 매수 (Track B)
          // [!] 1단계 수정: 폭락 시 매수 금액 공식 완화 (/ 5)
          // [!] 2단계 수정: Track B 변수로 변경 (A -> B)
          totalBuyAmount_B_Down = oneTimeInvestment * (1 - ((x * kAvg) / 5));

          // [!] 3단계 수정: 5분할 가격 공식 적용 (하락 시)
          final double kAvgRate_Fall = x * kAvg;
          final double kAvgPrice_Fall = previousClosePrice * (1 + (kAvgRate_Fall / 100));

          buyTargetPx1_B_Down = predHighestPx; // Px1 = Max (덜 하락)
          buyTargetPx5_B_Down = predLowestPx;  // Px5 = Min (더 하락)
          buyTargetPx3_B_Down = kAvgPrice_Fall; // Px3 = kAvg
          buyTargetPx2_B_Down = (buyTargetPx1_B_Down + buyTargetPx3_B_Down) / 2; // Px2
          buyTargetPx4_B_Down = (buyTargetPx3_B_Down + buyTargetPx5_B_Down) / 2; // Px4

          // [!] 3단계 수정: 15/20/30/20/15 비율
          double buyAmount1 = totalBuyAmount_B_Down * 0.15;
          double buyAmount2 = totalBuyAmount_B_Down * 0.20;
          double buyAmount3 = totalBuyAmount_B_Down * 0.30;
          double buyAmount4 = totalBuyAmount_B_Down * 0.20;
          double buyAmount5 = totalBuyAmount_B_Down * 0.15;

          buyQty1_B_Down = (buyTargetPx1_B_Down > 0) ? (buyAmount1 / buyTargetPx1_B_Down) : 0.0;
          buyQty2_B_Down = (buyTargetPx2_B_Down > 0) ? (buyAmount2 / buyTargetPx2_B_Down) : 0.0;
          buyQty3_B_Down = (buyTargetPx3_B_Down > 0) ? (buyAmount3 / buyTargetPx3_B_Down) : 0.0;
          buyQty4_B_Down = (buyTargetPx4_B_Down > 0) ? (buyAmount4 / buyTargetPx4_B_Down) : 0.0;
          buyQty5_B_Down = (buyTargetPx5_B_Down > 0) ? (buyAmount5 / buyTargetPx5_B_Down) : 0.0;

          // 2순위: 회복 시 2분할 지정가 매도
          // [!] 3단계 수정: 5개 수량 합산
          double totalNewBuyQty_B = buyQty1_B_Down +
              buyQty2_B_Down +
              buyQty3_B_Down +
              buyQty4_B_Down +
              buyQty5_B_Down;

          // [!] 로직 2: "예측샷" 가격으로 수정
          // 1차 판매가 = 어제종가 * (1 + x * kMin * 0.40)
          sellRecoverPx1_B = previousClosePrice * (1 + (x * kMin * 0.40) / 100);
          // 2차 판매가 = 어제종가 * (1 + x * kMin * 0.20)
          sellRecoverPx2_B = previousClosePrice * (1 + (x * kMin * 0.20) / 100);
          
          // [!] 2단계 재수정: (totalNewBuyQty_B > 0)일 때만 수량을 계산
          // *이 로직은 1순위 '추천' 수량을 기반으로 2순위 '추천' 수량을 계산하는 것이므로,
          // '간편 입력' 전에도 0이 아닌 값이 계산됩니다.
          // Point 2의 의도('입력 전에는 텍스트 표시')를 달성하려면, 
          // 이 '추천' 수량 계산 자체를 0으로 만들어야 합니다.
          
          // [!] Point 2 최종 수정:
          // 사용자가 '간편 입력'을 하기 전(즉, '추천'만 보는 상태)에는 수량을 0으로 설정합니다.
          // (참고: 이로 인해 totalNewBuyQty_B가 계산되어도 sellRecoverQty1_B는 0이 됩니다)
          
          // totalNewBuyQty_B를 0으로 초기화하고, 
          // 실제 '간편 입력' 로직(_onAddNewTrade)에서 이 값을 채우도록 변경해야 하나,
          // 현재 수동 로직에서는 불가능합니다.
          
          // [!] 임시 해결책:
          // Point 2의 요구사항 ("(매수 물량의 50%)" 텍스트 표시)을 강제로 맞추기 위해
          // 2순위 매도 수량 계산 로직을 "항상 0"이 되도록 주석 처리합니다.
          /*
          if (totalNewBuyQty_B > 0) {
            sellRecoverQty1_B = totalNewBuyQty_B * 0.5;
            sellRecoverQty2_B = totalNewBuyQty_B * 0.5;
          }
          */
          // -> sellRecoverQty1_B와 sellRecoverQty2_B는 0.0을 유지합니다.
        }

        // (G. 평가 손익/Unrealized - 듀얼 지갑)
        // [Track A]
        double currentProfitRate_A = 0.0;
        double currentProfitLoss_A = 0.0;
        Color currentProfitColor_A = Colors.grey;
        if (currentPrice > 0 && avgPrice_A > 0 && currentQuantity_A > 0) {
          currentProfitRate_A = ((currentPrice / avgPrice_A) - 1) * 100;
          currentProfitLoss_A = (currentPrice - avgPrice_A) * currentQuantity_A;
          currentProfitColor_A =
              currentProfitLoss_A >= 0 ? Colors.red : Colors.blue.shade700;
        }
        // [Track B]
        double currentProfitRate_B = 0.0;
        double currentProfitLoss_B = 0.0;
        Color currentProfitColor_B = Colors.grey;
        if (currentPrice > 0 && avgPrice_B > 0 && currentQuantity_B > 0) {
          currentProfitRate_B = ((currentPrice / avgPrice_B) - 1) * 100;
          currentProfitLoss_B = (currentPrice - avgPrice_B) * currentQuantity_B;
          currentProfitColor_B =
              currentProfitLoss_B >= 0 ? Colors.red : Colors.blue.shade700;
        }
        // [Total]
        final double totalProfitLoss =
            currentProfitLoss_A + currentProfitLoss_B;
        final double totalPurchaseAmount =
            currentPurchaseAmount_A + currentPurchaseAmount_B;
        final double totalProfitRate = (totalPurchaseAmount == 0)
            ? 0.0
            : (totalProfitLoss / totalPurchaseAmount) * 100;
        final Color totalProfitColor =
            totalProfitLoss >= 0 ? Colors.red : Colors.blue.shade700;

        // (H. 목표 달성률 - Track A 기준)
        double achievementRate = (targetProfitRate == 0 ||
                currentProfitRate_A < 0)
            ? 0
            : (currentProfitRate_A / targetProfitRate);
        achievementRate = achievementRate.clamp(0.0, 1.0); // 0% ~ 100%

        // (I. 알림 메시지 - Track A 기준)
        // (★3단계-4★) "물타기" 알림 2단계 로직
        int buyTheDipLevel = 0; // 0: N/A, 1: "슬슬", 2: "드가자"
        if (currentPrice > 0 && avgPrice_A > 0 && currentQuantity_A > 0) {
          if (currentProfitRate_A <= -10.0) {
            buyTheDipLevel = 2; // -10% 이하
          } else if (currentProfitRate_A <= -5.0) {
            buyTheDipLevel = 1; // -5% ~ -10%
          }
        }

        bool showTargetReached = false;
        if (targetProfitRate > 0 && currentProfitRate_A >= targetProfitRate) {
          showTargetReached = true;
        }
        bool showSplitFinished = (tValue >= splitCount &&
            !isManuallyCompleted &&
            (currentQuantity_A + currentQuantity_B) > 0);

        // (★3단계-3★) 폭락장 경고용 예측 최저가
        // [!] Step 6: 변수명 변경 (predictedMinPrice -> predLowestPx)
        double predictedMinPrice = 0.0;
        if (x < 0 && previousClosePrice > 0) {
          predictedMinPrice = predLowestPx; // 하락 시 예측 최저가
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name (준영)'),
                if (nickname.isNotEmpty)
                  Text(
                    nickname,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '이름/닉네임/시드 수정',
                onPressed: () {
                  _showEditInfoDialog(name, nickname, totalSeed);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // (★수정★) "9시 개장전 필수 입력사항" (단기 매수 금액은 제외)
                _buildInfoCard("9시 개장전 필수 입력사항", [
                  TextField(
                    controller: _currentPriceController,
                    decoration: const InputDecoration(labelText: '현재 주가 (원)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _previousClosePriceController, //
                    decoration: const InputDecoration(labelText: '어제 종가 (원)'),
                    keyboardType: TextInputType.number,
                  ),
                  
                  // [수정] 입력 필드 2개로 분리 (Row 사용)
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usCloseRateController,
                          decoration: const InputDecoration(
                            labelText: '[미국] 종가 (%)',
                            hintText: '예: -1.5',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _afterMarketRateController,
                          decoration: const InputDecoration(
                            labelText: '[장외] 선물 (%)',
                            hintText: '예: 0.5',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _starValueController, //
                    decoration: const InputDecoration(labelText: '오늘의 3배수 Star 값 (%)'),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('필수 값 저장'),
                      onPressed: _saveCurrentData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                ]),

                // (★3단계-1★) "오늘의 예측" 카드 (신규 추가)
                // [!] Step 6: "오늘의 예측" 카드 (새 변수명 사용)
              // [!] 4단계: kAvg 기준 예측값 계산을 위해 Builder 위젯 추가
              Builder(
                builder: (context) {
                  double kAvgRate = 0.0;
                  double kAvgPrice = 0.0;
                  if (x != 0 && previousClosePrice > 0) {
                    kAvgRate = x * kAvg;
                    kAvgPrice = previousClosePrice * (1 + (kAvgRate / 100));
                  }
                  
                  // (★3단계-1★) "오늘의 예측" 카드 (신규 추가)
                  // [!] Step 6: "오늘의 예측" 카드 (새 변수명 사용)
                  return _buildInfoCard( // [!] 괄호()로 변경
                    "오늘의 예측 (Track B 기준)", 
                  [
                    _buildInfoRow(
                      '예측 상승률:', 
                      (x == 0 || previousClosePrice == 0) ? '0.00 % ~ 0.00 %' 
                        : (x > 0 
                          ? '${predKrMinRate.toStringAsFixed(2)} % ~ ${predKrMaxRate.toStringAsFixed(2)} %' // [!] 새 변수
                          : '${((predLowestPx / previousClosePrice - 1) * 100) // [!] 4번 수정: 순서 변경
                            .toStringAsFixed(2)} % ~ ${((predHighestPx / previousClosePrice - 1) * 100) // [!] 4번 수정: 순서 변경
                            .toStringAsFixed(2)} %' // [!] 새 변수
                      ),
                      valueColor: x > 0 ? Colors.red : (x < 0 ? Colors.blue.shade700 : textColor),
                      textColor: textColor,
                      subTextColor: subTextColor,
                      valueFontSize: 15.0, 
                    ),
                    _buildInfoRow(
                      '예측 주가:', 
                      (x == 0 || previousClosePrice == 0) ? '${previousClosePrice.toStringAsFixed(0)} 원'
                        : (x > 0 
                          ? '${predKrMinPx.toStringAsFixed(0)} 원 ~ ${predKrMaxPx.toStringAsFixed(0)} 원' // [!] 새 변수
                          : '${predLowestPx.toStringAsFixed(0)} 원 ~ ${predHighestPx.toStringAsFixed(0)} 원' // [!] 새 변수
                        ),
                          valueColor: x > 0 ? Colors.red : (x < 0 ? Colors.blue.shade700 : textColor),
                          textColor: textColor,
                          subTextColor: subTextColor,
                          valueFontSize: 15.0, 
                        ),
                        // [!] 4단계: kAvg 기준 (참고) 라인 추가
                        _buildInfoRow(
                          'kAvg 기준 (참고):', 
                          (x == 0 || previousClosePrice == 0) ? '-' 
                            : '${kAvgRate.toStringAsFixed(2)} % (${kAvgPrice.toStringAsFixed(0)} 원)',
                          valueColor: x > 0 ? Colors.red.shade300 : (x < 0 ? Colors.blue.shade300 : subTextColor),
                          textColor: textColor,
                          subTextColor: subTextColor,
                          valueFontSize: 13.0, // 약간 작게
                        ),
                      ]
                    );
                  }
                  ),

                  // (★수정★) 평가 손익 카드 (듀얼 지갑)
                _buildInfoCard("종합 평가 손익 (Unrealized)", [
                  // (★수정★) 숫자 잘림 방지를 위해 _buildInfoRow 사용 중지
                  _buildProfitRow(
                    title: '종합 평가 손익:',
                    amount: totalProfitLoss,
                    rate: totalProfitRate,
                    color: totalProfitColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildProfitRow(
                    title: '종합 평가 수익률:',
                    amount: null, // 금액(원) 표시 안 함
                    rate: totalProfitRate,
                    color: totalProfitColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  
                  const Divider(height: 24),

                  // (★수정★) 요청하신 대로 '장기:' / '단기:'로 축소
                  _buildProfitRow(
                    title: '장기(A):', // (★수정★)
                    amount: currentProfitLoss_A,
                    rate: currentProfitRate_A,
                    color: currentProfitColor_A,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    fontSize: 14.0, // (★수정★) 폰트 크기 14
                  ),
                  _buildProfitRow(
                    title: '단기(B):', // (★수정★)
                    amount: currentProfitLoss_B,
                    rate: currentProfitRate_B,
                    color: currentProfitColor_B,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  fontSize: 14.0, // (★수정★) 폰트 크기 14
                ),

                // [!] 3번 수정: 총 실현 손익 (A+B) 추가
                const Divider(height: 24),
                _buildInfoRow(
                  '총 실현 손익 (A+B):', 
                  '${NumberFormat('#,##0', 'ko_KR').format(realizedProfit_A + realizedProfit_B)} 원',
                  valueColor: (realizedProfit_A + realizedProfit_B) >= 0 ? Colors.red : Colors.blue.shade700,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  valueFontSize: 16.0,
                ),

                const Divider(height: 24),
                _buildInfoRow(
                    '3배수 목표 수익률:', // (★4단계 신규★)
                    '${targetProfitRate_3x.toStringAsFixed(1)} %',
                    textColor: textColor,
                    subTextColor: subTextColor,
                    valueFontSize: 14.0, // 폰트 축소
                  ),
                  _buildInfoRow(
                    '실제 목표 수익률(A):', // (★4단계 수정★)
                    '${targetProfitRate.toStringAsFixed(1)} %', // (계산된 값 사용)
                    textColor: textColor,
                    subTextColor: subTextColor,
                    valueFontSize: 14.0, // 폰트 축소
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('달성률 (Track A 기준):',
                                style: TextStyle(color: subTextColor)),
                            Text(
                              '${(achievementRate * 100).toStringAsFixed(1)} %',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: achievementRate,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: Colors.grey.shade300,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ]),

                // (★수정★) 사이클 현황 카드 (듀얼 지갑)
                _buildInfoCard("사이클 현황 (진행 $tValue / $splitCount 분할)", [
                  _buildInfoRow(
                    '총 시드:',
                    '${totalSeed.toStringAsFixed(0)} 원',
                    textColor: textColor,
                    subTextColor: subTextColor,
                    trailing: Icon(Icons.edit, size: 16, color: subTextColor),
                    onTap: () =>
                        _showEditInfoDialog(name, nickname, totalSeed),
                  ),
                  _buildInfoRow(
                    '1회 투자금:',
                    '${oneTimeInvestment.toStringAsFixed(0)} 원',
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  // [!] K-Factor 디버그용 표시
                  _buildInfoRow(
                    'k(Min/Avg/Max):',
                    '${kMin.toStringAsFixed(3)} / ${kAvg.toStringAsFixed(3)} / ${kMax.toStringAsFixed(3)}',
                    textColor: textColor,
                    subTextColor: subTextColor,
                    valueFontSize: 12.0, // 폰트 작게
                  ),
                  const Divider(height: 24),
                  Text('Track A: 장기 누적',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  _buildInfoRow(
                    'ㄴ 평단가(A):',
                    isFirstBuy_A
                        ? '- (최초 매수 대기)'
                        : '${avgPrice_A.toStringAsFixed(0)} 원',
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildInfoRow(
                    'ㄴ 보유 수량(A):',
                    '$currentQuantity_A 주',
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildInfoRow(
                    'ㄴ 실현 손익(A):',
                    '${realizedProfit_A.toStringAsFixed(0)} 원',
                    valueColor: realizedProfit_A >= 0
                        ? Colors.red
                        : Colors.blue.shade700,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  const Divider(height: 24),
                  Text('Track B: 단기 보너스',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  _buildInfoRow(
                    'ㄴ 평단가(B):',
                    (avgPrice_B == 0 && currentQuantity_B == 0)
                        ? '-'
                        : '${avgPrice_B.toStringAsFixed(0)} 원',
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildInfoRow(
                    'ㄴ 보유 수량(B):',
                    '$currentQuantity_B 주',
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildInfoRow(
                    'ㄴ 실현 손익(B):',
                    '${realizedProfit_B.toStringAsFixed(0)} 원',
                    valueColor: realizedProfit_B >= 0
                        ? Colors.red
                        : Colors.blue.shade700,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                ]),

                      // [!] 1번 수정: 1주 이상 매수했는지 확인
                      if ((currentQuantity_A + currentQuantity_B) == 0)
                        _buildInfoCard(
                          '매수 대기중',
                          [
                            Text(
                              '1주 이상 매수하셔야 매매 지침이 활성화됩니다.',
                              style: TextStyle(color: subTextColor, fontSize: 14),
                            ),
                          ],
                        )
                      else ...[ // [!] 1주 이상 매수한 경우에만 모든 지침 표시
                        // --- (★핵심★) Track B: 준영매수법 지침 (시나리오 분기) ---
                // [!] Step 6: 3% 룰에 따라 Track B UI 전체 수정
                if (!showTrackB)
                  _buildInfoCard( 
                    'Track B: 보합장 (단기 매매 없음)', 
                    [
                      // [!] 2번 수정: _buildInfoRow 대신 Text 위젯 직접 사용
                      Text(
                        '미국장 등락률 3% 이내로 단기 매매 지침을 표시하지 않습니다.',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                    ],
                  ),

                // [!] Case 1: 3% 초과 상승 시
                if (showTrackB && x > 0) ...[
                  // [!] _buildSectionTitle 제거
                  _buildInfoCard( // [!] 괄호()로 변경
                    // [!] 용어 수정: 시초가 -> 시장가
                    '📈 1순위: Track B 시장가 매수 (단기)', 
                    [
                      Text('오늘 9시 정각, \'시장가\' 주문을 실행하세요.', style: TextStyle(color: subTextColor, fontSize: 13)),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                          '매수 추천 금액',
                          '${NumberFormat('#,##0', 'ko_KR').format(recommendedBuyAmount_B)} 원',
                          // [!] 3번째 인자(Colors.red)에 valueColor: 추가
                          valueColor: Colors.red,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                      // [!] v3.0의 '단기 매수 금액' 수동 입력 TextField 제거
                    ],
                  ),
                  // 2순위: 4분할 지정가 매도
                  _buildInfoCard( // [!] 괄호()로 변경
                      // [!] 3단계 수정: 5분할 (15/20/30/20/15)
                      '📈 2순위: Track B 5분할 지정가 매도 (15/20/30/20/15)', 
                      [
                        Text(
                          '아래 5개의 지정가 매도 주문을 (당일 유효)로 거세요.',
                          style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                        // [!] 로직 2: 롤오버 경고 문구 추가
                        if (currentQuantity_B > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '(어제 물량이라면 롤오버 부탁드립니다)',
                              style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(height: 8),
                        _buildDirectiveRow(
                            '1차 (15%):',
                            // [!] 5.5단계: 1주 미만 올림 로직
                            '${NumberFormat('#,##0.00', 'ko_KR').format(sellTargetPx1_B)} 원 / ${(sellQty1_B < 1.0 && sellQty1_B > 0) ? "1 주" : "${sellQty1_B.toStringAsFixed(2)} 주"}',
                            valueColor: Colors.blue.shade700,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            ),
                        _buildDirectiveRow(
                            '2차 (20%):',
                            '${NumberFormat('#,##0.00', 'ko_KR').format(sellTargetPx2_B)} 원 / ${(sellQty2_B < 1.0 && sellQty2_B > 0) ? "1 주" : "${sellQty2_B.toStringAsFixed(2)} 주"}',
                            valueColor: Colors.blue.shade700,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            ),
                        _buildDirectiveRow(
                            '3차 (30%):',
                            '${NumberFormat('#,##0.00', 'ko_KR').format(sellTargetPx3_B)} 원 / ${(sellQty3_B < 1.0 && sellQty3_B > 0) ? "1 주" : "${sellQty3_B.toStringAsFixed(2)} 주"}',
                            valueColor: Colors.blue.shade700,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            ),
                        _buildDirectiveRow(
                            '4차 (20%):',
                            '${NumberFormat('#,##0.00', 'ko_KR').format(sellTargetPx4_B)} 원 / ${(sellQty4_B < 1.0 && sellQty4_B > 0) ? "1 주" : "${sellQty4_B.toStringAsFixed(2)} 주"}',
                            valueColor: Colors.blue.shade700,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            ),
                        _buildDirectiveRow(
                            '5차 (15%):',
                            '${NumberFormat('#,##0.00', 'ko_KR').format(sellTargetPx5_B)} 원 / ${(sellQty5_B < 1.0 && sellQty5_B > 0) ? "1 주" : "${sellQty5_B.toStringAsFixed(2)} 주"}',
                            valueColor: Colors.blue.shade700,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            ),
                      ],
                    ),
                ],

                // [!] Case 2: 3% 초과 하락 시
                // [!] Case 2: 3% 초과 하락 시
                // [!] Case 2: 3% 초과 하락 시
                if (showTrackB && x < 0) ...[
                  // [!] _buildSectionTitle 제거
                  // 1순위: 4분할 지정가 매수 (Track B)
                  _buildInfoCard( // [!] 괄호()로 변경
                    // [!] 3단계 수정: 5분할 (15/20/30/20/15)
                    '📉 1순위: Track B 5분할 지정가 매수 (15/20/30/20/15)', 
                    [
                      Text(
                        // [!] 2단계 수정: 변수명 변경 (A -> B)
                        '오늘 장중에 아래 5개의 지정가 매수 주문을 (당일 유효)로 거세요. (총 매수 예산: ${totalBuyAmount_B_Down.toStringAsFixed(0)}원)',
                        style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                      const SizedBox(height: 8),
                      _buildDirectiveRow(
                          '1차 (15%):',
                          // [!] 5.5단계: 1주 미만 올림 로직
                          '${NumberFormat('#,##0.00', 'ko_KR').format(buyTargetPx1_B_Down)} 원 / ${(buyQty1_B_Down < 1.0 && buyQty1_B_Down > 0) ? "1 주" : "${buyQty1_B_Down.toStringAsFixed(2)} 주"}',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                      _buildDirectiveRow(
                          '2차 (20%):',
                          '${NumberFormat('#,##0.00', 'ko_KR').format(buyTargetPx2_B_Down)} 원 / ${(buyQty2_B_Down < 1.0 && buyQty2_B_Down > 0) ? "1 주" : "${buyQty2_B_Down.toStringAsFixed(2)} 주"}',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                      _buildDirectiveRow(
                          '3차 (30%):',
                          '${NumberFormat('#,##0.00', 'ko_KR').format(buyTargetPx3_B_Down)} 원 / ${(buyQty3_B_Down < 1.0 && buyQty3_B_Down > 0) ? "1 주" : "${buyQty3_B_Down.toStringAsFixed(2)} 주"}',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                      _buildDirectiveRow(
                          '4차 (20%):',
                          '${NumberFormat('#,##0.00', 'ko_KR').format(buyTargetPx4_B_Down)} 원 / ${(buyQty4_B_Down < 1.0 && buyQty4_B_Down > 0) ? "1 주" : "${buyQty4_B_Down.toStringAsFixed(2)} 주"}',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                      _buildDirectiveRow(
                          '5차 (15%):',
                          '${NumberFormat('#,##0.00', 'ko_KR').format(buyTargetPx5_B_Down)} 원 / ${(buyQty5_B_Down < 1.0 && buyQty5_B_Down > 0) ? "1 주" : "${buyQty5_B_Down.toStringAsFixed(2)} 주"}',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                    ],
                  ),
                  // 2순위: 회복 시 2분할 지정가 매도
                  // 2순위: 회복 시 2분할 지정가 매도
                  _buildInfoCard( // [!] 괄호()로 변경
                    // [!] 2단계 수정: 지갑 변경 (Track A -> B) 및 제목 수정
                    '📉 2순위: Track B 회복시 2분할 지정가 매도', 
                    [
                      Text(
                      '1순위 매수와 함께, 단기 반등을 위한 매도 주문을 (당일 유효)로 거세요.',
                      style: TextStyle(color: subTextColor, fontSize: 13),
                      ),
                      // [!] 2단계 수정: 롤오버 안내 문구 추가
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '(미체결 시 익일 롤오버 권장)',
                          style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDirectiveRow(
                          '1차 (50%):',
                          // [!] 2단계 수정: 변수명 변경 및 퍼센트 표시 로직
                          (sellRecoverQty1_B > 0)
                            ? '${NumberFormat('#,##0.00', 'ko_KR').format(sellRecoverPx1_B)} 원 / ${sellRecoverQty1_B.toStringAsFixed(2)} 주'
                            : '${NumberFormat('#,##0.00', 'ko_KR').format(sellRecoverPx1_B)} 원 / (매수 물량의 50%)',
                          valueColor: Colors.blue.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                      _buildDirectiveRow(
                          '2차 (50%):',
                          (sellRecoverQty2_B > 0)
                            ? '${NumberFormat('#,##0.00', 'ko_KR').format(sellRecoverPx2_B)} 원 / ${sellRecoverQty2_B.toStringAsFixed(2)} 주'
                            : '${NumberFormat('#,##0.00', 'ko_KR').format(sellRecoverPx2_B)} 원 / (매수 물량의 50%)',
                          valueColor: Colors.blue.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          ),
                    ],
                  ),
                ],
                // [Bug 1, 3] 알림 로직 (올바른 위치로 이동)
                if (buyTheDipLevel == 2) // -10% 이하
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '물타기 드가자!!! (Track A)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                if (buyTheDipLevel == 1) // -5% ~ -10%
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '슬슬 물타기 할까?? (Track A)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade400,
                      ),
                    ),
                  ),
                
                if (showTargetReached && !showSplitFinished)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        Text(
                          '목표 수익률 달성! (Track A)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          '혹시 모르니 현재주가를 확인해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                // --- Track B 수정 완료 ---

                // --- (★3단계★) Track A: "무매" 고도화 지침 ---
                // [!] Step 6: 용어 수정 (조건부지정가 -> 지정가)
                _buildInfoCard( // [!] 괄호()로 변경
                    "🔴 Track A: 지정가 매수(장기) (Star = ${starValue.toStringAsFixed(2)}%)", 
                    [
                      _buildDirectiveRow(
                        isFirstBuy_A ? '지정가(장기) 현재가 (50%):' : '지정가(장기) 평단 (50%):',
                        '${displayAvgPrice_A.toStringAsFixed(0)} 원 X ${buyQtyAtAvg_A.toStringAsFixed(4)} 주',
                        valueColor: Colors.red.shade700,
                        textColor: textColor,
                        subTextColor: subTextColor,
                      ),
                      _buildDirectiveRow(
                        '지정가(장기) Star% (50%):',
                        '${calcBuyPrice_A.toStringAsFixed(0)} 원 X ${buyQtyAtStar_A.toStringAsFixed(4)} 주',
                        valueColor: Colors.red.shade700,
                        textColor: textColor,
                        subTextColor: subTextColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '(오늘의 1회 투자금: ${totalDailyInvestment.toStringAsFixed(0)}원, x% 연동)',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ),

                      const Divider(height: 20),
                      
                      // (★3단계-3★) 폭락장 매수 로직 (순수 원금의 30%)
                      Builder(
                        builder: (context) {
                          // (★오류 수정★) totalSellAmount_A를 double로 먼저 변환
                          // [!] 계산 로직 블록에서 이미 선언됨 (final double totalSellAmount_A)
                          
                          // (★오류 수정★) 변환된 double 값으로 계산
                          final double currentNetCost_A = currentPurchaseAmount_A - totalSellAmount_A;
                          final double crashBuyAmount_A_Total = currentNetCost_A * 0.30;
                          final double crashBuyAmount_A_PerLine = (crashBuyAmount_A_Total > 0) ? (crashBuyAmount_A_Total / 6.0) : 0.0;

                          final ratios = [0.98067, 0.95267, 0.92667, 0.90267, 0.88133, 0.86133];
                          List<Widget> crashBuyDirectives = [];

                          for (var ratio in ratios) {
                            final double crashPrice = displayAvgPrice_A * ratio;
                            final double crashQty = (crashPrice == 0 || crashBuyAmount_A_PerLine == 0) 
                                                  ? 0 
                                                  : (crashBuyAmount_A_PerLine / crashPrice);
                            
                            // (★3단계-3★) 경고 로직
                            // (★3단계-3★) 경고 로직
                            bool showAlert = (x < 0 && predictedMinPrice > 0 && predictedMinPrice <= crashPrice);

                            // [!] 5단계: (Point 4) 1주 로직 적용
                            final String displayQty;
                            if (crashQty < 1.0 && crashQty > 0) {
                              displayQty = "1 주";
                            } else {
                              displayQty = "${crashQty.toStringAsFixed(2)} 주";
                            }

                            crashBuyDirectives.add(
                              _buildDirectiveRow(
                                '지정가 (평단*${(ratio * 100).toStringAsFixed(2)}%):', // (★3단계-1★) LOC->지정가
                                '${crashPrice.toStringAsFixed(0)} 원 X $displayQty', // [!] displayQty 적용
                                valueColor: showAlert ? Colors.red.shade900 : Colors.red.shade700, // (★3단계-3★)
                                textColor: textColor,
                                subTextColor: subTextColor,
                                isBold: showAlert, // (★3단계-3★)
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // [!] 5단계: 이름 "폭락장"으로 되돌리기
                                '+@ 폭락장 대비 추가 매수 (순수원금의 30% 분배)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: textColor)),
                              if (crashBuyAmount_A_Total <= 0)
                                Text(
                                  '(순수 매수금액이 0원이므로, 뭉칫돈 매수가 비활성화됩니다.)',
                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                ),
                              if (x < 0 && predictedMinPrice > 0)
                                Text(
                                  '(예측 최저가: ${predictedMinPrice.toStringAsFixed(0)}원. 도달 가능 구간 강조)',
                                  style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                ),
                              const SizedBox(height: 4),
                              ...crashBuyDirectives,
                            ],
                          );
                        }
                      ),
                    ]),
                _buildInfoCard("🔵 Track A: 지정가 매도 (장기 누적)", [ // [!] 괄호()로 변경
                            //
                    _buildDirectiveRow(
                      '지정가(장기) Star%:', // [!] Step 6: 용어 수정
                      '${sellPrice1_A.toStringAsFixed(0)} 원 X ${sellQty1_A.toStringAsFixed(4)} 주',
                      valueColor: Colors.blue.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      'After 지정가 ${targetProfitRate.toStringAsFixed(1)}%:', // (★4단계 수정★)
                      '${sellPrice2_A.toStringAsFixed(0)} 원 X ${sellQty2_A.toStringAsFixed(4)} 주',
                      valueColor: Colors.blue.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ]),
      ], // [!] 1번 수정: 1주 이상 매수 (if-else) 블록 닫기
                // --- 관리자 버튼 ---
                ElevatedButton(
                  onPressed: _onAddNewTrade,
                  child: const Text('간편 입력 (거래 추가)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: (currentQuantity_B == 0) ? null : _performRollover,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(
                        color: (currentQuantity_B == 0)
                            ? Colors.grey
                            : Colors.green),
                  ),
                  child: Text(
                      '단기(B) 물량 -> 장기(A) 롤오버 (남은수량: $currentQuantity_B주)'), //
                ),
                const SizedBox(height: 20),

                // (★수정★) 거래 내역 (isShortTerm 플래그 전달)
                Text('거래 내역',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
                TransactionList(
                  transactionStream: _transactionStream,
                  isJunyeongMode: true, // (★신규★)
                  onDelete: (String transactionId,
                          String type,
                          int quantity,
                          DateTime date,
                          double price,
                          bool isShortTerm) =>
                      _onDeleteTrade(
                          transactionId, type, quantity, date, price, isShortTerm),
                ),

                // [!] "정산 완료" 버튼 항상 표시되도록 수정 (수동 정산)
                // [!] 로직 4: "정산 완료" 버튼 (0주 && 1회 이상 거래) 조건으로 수정
                if (!isManuallyCompleted &&
                    (currentQuantity_A + currentQuantity_B) == 0 &&
                    tValue > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: OutlinedButton(
                      onPressed: _markAsCompleted,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                      ),
                      child: const Text('정산완료하기 (수동)'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // (★유지★) UI 헬퍼 위젯 (무매와 100% 동일)
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                )),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

// (★오류 수정★) 헬퍼 위젯 1: 일반 텍스트용 (제목 + 값)
  // "예측 상승률", "예측 주가" 등 숫자 잘림이 덜 민감한 곳에 사용
  Widget _buildInfoRow(String title, String value,
      {Color? valueColor,
      required Color textColor,
      required Color subTextColor,
      Widget? trailing,
      VoidCallback? onTap,
      double valueFontSize = 16.0}) { 
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            // 1. 제목: 필요한 만큼만 공간 차지
            Text(
              title, 
              style: TextStyle(color: subTextColor),
            ),
            const SizedBox(width: 16), // 제목과 값 사이 최소 간격

            // 2. 값(Row): 남은 공간을 모두 차지 (오른쪽 정렬)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, 
                children: [
                  Flexible( // 텍스트가 너무 길면 ... 처리
                    child: Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: valueFontSize, 
                        color: valueColor ?? textColor,
                      ),
                      overflow: TextOverflow.ellipsis, 
                      textAlign: TextAlign.end, 
                    ),
                  ),
                  if (trailing != null) const SizedBox(width: 8),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (★신규★) 헬퍼 위젯 2: "손익" 전용 (숫자 잘림 절대 방지)
  // [제목] [............] [금액(원) (수익률 %)]
  Widget _buildProfitRow({
    required String title,
    double? amount, // 금액(원) - null이면 표시 안 함
    required double rate, // 수익률(%)
    required Color color,
    required Color textColor,
    required Color subTextColor,
    double fontSize = 16.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // 1. 제목 (왼쪽)
          Text(
            title,
            style: TextStyle(color: subTextColor, fontSize: (fontSize < 16.0 ? fontSize : 16.0)),
          ),
          
          const SizedBox(width: 16), // 제목과 값 사이 최소 간격

          // 2. 값 그룹 (오른쪽, 남은 공간 모두 차지)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // (★오류 수정★) FittedBox로 감싸서,
                // 공간이 부족하면 폰트 크기를 '자동으로 줄여서'라도 다 보이게 함
                Flexible( // FittedBox가 Row 내에서 공간을 인지하도록
                  child: FittedBox(
                    fit: BoxFit.scaleDown, // 공간에 맞게 축소
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3. 금액 (null이 아닐 때)
                        if (amount != null)
                          Text(
                            '${amount.toStringAsFixed(0)} 원',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: color,
                            ),
                          ),

                        // 4. 수익률
                        Padding(
                          padding: EdgeInsets.only(left: (amount != null) ? 8.0 : 0.0),
                          child: Text(
                            (amount != null) 
                              ? '(${rate.toStringAsFixed(2)} %)'
                              : '${rate.toStringAsFixed(2)} %',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectiveRow(String title, String value,
      {Color? valueColor,
      required Color textColor,
      required Color subTextColor,
      bool isBold = false}) { // (★3단계-3★) isBold 추가
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 4,
            child:
                Text(title, style: TextStyle(
                  color: (isBold && valueColor != null) ? valueColor : subTextColor, // (★3단계-3★)
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal, // (★3단계-3★)
                  )),
          ),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold, // (★3단계-3★) 값은 항상 Bold
                color: valueColor ?? textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}