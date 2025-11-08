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
  final _usMarketRateController = TextEditingController(); // x% (미국장 등락율)
  final _starValueController = TextEditingController(); // 3배수 Star 값
  final _shortTermBuyAmountController =
      TextEditingController(); // 단기 매수 금액

  // 3. 수정용 컨트롤러
  final _nameEditController = TextEditingController();
  final _nicknameEditController = TextEditingController();
  final _totalSeedEditController = TextEditingController();

  bool _isRecalculating = false;
  double _savedPrice = 0.0;

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
    _usMarketRateController.addListener(_updateRealTimeProfit);
    _starValueController.addListener(_updateRealTimeProfit);
    _shortTermBuyAmountController.addListener(_updateRealTimeProfit);

    _cycleStream.first.then((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        final double price = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;
        _currentPriceController.text = price.toString();
        _savedPrice = price;

        _previousClosePriceController.text =
            (data['previousClosePrice'] as num?)?.toString() ?? '0.0';
        _usMarketRateController.text =
            (data['usMarketRate'] as num?)?.toString() ?? '0.0';
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
      final double x =
          double.tryParse(_usMarketRateController.text) ?? 0.0; // 현재 x%

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
      // "하락장"에 "단기(Track B)"로 "매수"한 물량은
      // "즉시 장기(Track A) 물량으로 합산"
      bool finalIsShortTerm = isShortTerm;
      if (x < 0 && type == 'buy' && isShortTerm) {
        finalIsShortTerm = false; // 즉시 Track A로 강제 롤오버
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('하락장 단기 매수: 즉시 장기(Track A) 물량으로 합산합니다.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }

      await _transactionsRef.add({
        'date': Timestamp.fromDate(newTrade['date']),
        'price': newPrice,
        'quantity': newTrade['quantity'],
        'type': newTrade['type'],
        'isShortTerm': finalIsShortTerm, // (★수정★)
      });

      if (mounted) {
        _currentPriceController.text = newPrice.toString();
        _savedPrice = newPrice;
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
      final double usRate =
          double.tryParse(_usMarketRateController.text) ?? 0.0;
      final double star = double.tryParse(_starValueController.text) ?? 0.0;
      final double prevClose =
          double.tryParse(_previousClosePriceController.text) ?? 0.0;
      // '단기 매수 금액'은 저장하지 않음 (휘발성 추천값)

      await _cycleRef.update({
        'currentPrice': price,
        'usMarketRate': usRate,
        'starValue': star,
        'previousClosePrice': prevClose, //
      });

      if (mounted) {
        _savedPrice = price;
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
    _usMarketRateController.removeListener(_updateRealTimeProfit);
    _starValueController.removeListener(_updateRealTimeProfit);
    _shortTermBuyAmountController.removeListener(_updateRealTimeProfit);
    _currentPriceController.dispose();
    _previousClosePriceController.dispose();
    _usMarketRateController.dispose();
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
        final double targetProfitRate =
            (data['targetProfitRate'] as num?)?.toDouble() ?? 0.0;
        final double oneTimeInvestment =
            (splitCount == 0) ? 0 : (totalSeed / splitCount);

        // (B. k-Factors)
        final double kMin = (data['kMin'] as num?)?.toDouble() ?? 3.185;
        final double kMax = (data['kMax'] as num?)?.toDouble() ?? 3.185;
        final double kAvg = (data['kAvg'] as num?)?.toDouble() ?? 3.185;

        // (C. 핵심 상태 변수 - 듀얼 지갑)
        // [Track A: 장기]
        final double avgPrice_A = (data['avgPrice_A'] as num?)?.toDouble() ?? 0.0;
        final int currentQuantity_A =
            (data['currentQuantity_A'] as num?)?.toInt() ?? 0;
        final double currentPurchaseAmount_A =
            (data['currentPurchaseAmount_A'] as num?)?.toDouble() ?? 0.0;
        final double realizedProfit_A =
            (data['realizedProfit_A'] as num?)?.toDouble() ?? 0.0;
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
        final double x = double.tryParse(_usMarketRateController.text) ??
            0.0; // x% (미국장)
        final double starValue_3x =
            double.tryParse(_starValueController.text) ?? 0.0; // 3배수 Star

        // (E. Track A: "무매" 공식 계산)
        final double starValue = (starValue_3x * 2) / 3.0; // 2배수 변환
        final bool isFirstBuy_A = (avgPrice_A == 0 && currentQuantity_A == 0);
        final double displayAvgPrice_A =
            isFirstBuy_A ? currentPrice : avgPrice_A;

        final double calcBuyPrice_A =
            displayAvgPrice_A * (1 + (starValue / 100));
        final double oneTimeSplitAmount = oneTimeInvestment / 2;
        final double buyQtyAtAvg_A = (displayAvgPrice_A == 0)
            ? 0
            : (oneTimeSplitAmount / displayAvgPrice_A);
        final double buyQtyAtStar_A = (calcBuyPrice_A == 0)
            ? 0
            : (oneTimeSplitAmount / calcBuyPrice_A);

        final double sellPrice1_A = calcBuyPrice_A + 1;
        final double sellQty1_A = currentQuantity_A / 4.0;
        final double sellPrice2_A =
            displayAvgPrice_A * (1 + (targetProfitRate / 100));
        final double sellQty2_A = currentQuantity_A * 3.0 / 4.0;

        // (F. Track B: "준영" 공식 계산)
        // [F-1. 상승장 (x > 0) 매수]
        final double recommendedBuyAmount_B =
            oneTimeInvestment * (1 + (x / kAvg)); //

        // (★오류 수정★)
        // A. build 메서드 실행 중에는 '계산'만 합니다.
        //    (컨트롤러에 이미 값이 있으면 그 값을 쓰고, 없으면 추천값을 사용)
        final double finalBuyAmount_B =
            double.tryParse(_shortTermBuyAmountController.text) ??
                recommendedBuyAmount_B;

        // (★오류 수정★)
        // B. build가 완료된 '직후'에 컨트롤러의 텍스트를 '설정'합니다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final String recommendedText = recommendedBuyAmount_B.toStringAsFixed(0);
          
          // (x > 0)이거나, (컨트롤러가 비어있을 때) 추천값으로 텍스트를 업데이트합니다.
          if ((_shortTermBuyAmountController.text.isEmpty || x > 0) &&
              _shortTermBuyAmountController.text != recommendedText) {
            _shortTermBuyAmountController.text = recommendedText;
          }
        });

        // [F-2. 상승장 (x > 0) 매도]
        final double predKrMinRate = x / kMax; //
        final double predKrMaxRate = x / kMin; //
        final double minTargetPx =
            previousClosePrice * (1 + (predKrMinRate / 100)); //
        final double maxTargetPx =
            previousClosePrice * (1 + (predKrMaxRate / 100)); //
        final double interval =
            (maxTargetPx - minTargetPx) / 3; //

        final double sellTargetPx1 = minTargetPx; //
        final double sellTargetPx2 = minTargetPx + (interval * 1); //
        final double sellTargetPx3 = minTargetPx + (interval * 2); //
        final double sellTargetPx4 = maxTargetPx; //

        final double sellTargetQty1 = currentQuantity_B * 0.15; //
        final double sellTargetQty2 = currentQuantity_B * 0.25; //
        final double sellTargetQty3 = currentQuantity_B * 0.35; //
        final double sellTargetQty4 = currentQuantity_B * 0.25; //

        // [F-3. 하락장 (x < 0) 매수]
        final double totalBuyAmount_B_Down =
            oneTimeInvestment * (1 - (x / kAvg)); //
        final double splitBuyAmount_B_Down =
            totalBuyAmount_B_Down * 0.25; //
        final double predKrMinRate_Down = x / kMin; //
        final double predKrMaxRate_Down = x / kMax; //
        final double maxBuyPx = previousClosePrice *
            (1 + (predKrMaxRate_Down / 100)); // Start
        final double minBuyPx = previousClosePrice *
            (1 + (predKrMinRate_Down / 100)); // End
        final double interval_Down = (maxBuyPx - minBuyPx) / 3; // 4등분용 (간격 3개)

        final double buyTargetPx1 = maxBuyPx; //
        final double buyTargetPx2 = maxBuyPx - (interval_Down * 1); //
        final double buyTargetPx3 = maxBuyPx - (interval_Down * 2); //
        final double buyTargetPx4 = minBuyPx; //

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
        bool showTargetReached = false;
        if (targetProfitRate > 0 && currentProfitRate_A >= targetProfitRate) {
          showTargetReached = true;
        }
        bool showSplitFinished = (tValue >= splitCount &&
            !isManuallyCompleted &&
            (currentQuantity_A + currentQuantity_B) > 0);

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
                // (★수정★) 5대 필수 입력 카드
                _buildInfoCard("필수 입력 (5)", [
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
                  TextField(
                    controller: _usMarketRateController, //
                    decoration: const InputDecoration(labelText: '미국장 등락율 (x%)'),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                  ),
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

                // (★수정★) 평가 손익 카드 (듀얼 지갑)
                _buildInfoCard("종합 평가 손익 (Unrealized)", [
                  _buildInfoRow(
                    '종합 평가 손익:',
                    '${totalProfitLoss.toStringAsFixed(0)} 원',
                    valueColor: totalProfitColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildInfoRow(
                    '종합 평가 수익률:',
                    '${totalProfitRate.toStringAsFixed(2)} %',
                    valueColor: totalProfitColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    'ㄴ 장기(A) 손익:',
                    '${currentProfitLoss_A.toStringAsFixed(0)} 원 (${currentProfitRate_A.toStringAsFixed(2)} %)',
                    valueColor: currentProfitColor_A,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildInfoRow(
                    'ㄴ 단기(B) 손익:',
                    '${currentProfitLoss_B.toStringAsFixed(0)} 원 (${currentProfitRate_B.toStringAsFixed(2)} %)',
                    valueColor: currentProfitColor_B,
                    textColor: textColor, // (★오류 수정 지점★)
                    subTextColor: subTextColor,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    '장기(A) 목표 수익률:',
                    '${targetProfitRate.toStringAsFixed(1)} %',
                    textColor: textColor,
                    subTextColor: subTextColor,
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

                if (showTargetReached && !showSplitFinished)
                  // ... (알림 메시지 - 내용 동일) ...
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

                // --- (★핵심★) Track B: 준영매수법 지침 (시나리오 분기) ---
                if (x > 0) ...[
                  // --- 1. 미국장 상승 시 (x > 0) ---
                  _buildInfoCard("📈 1순위: Track B 시초가 매수 (단기)", [
                    //
                    const Text('오늘 9시 정각, \'시초가\' 주문을 실행하세요.'), //
                    _buildInfoRow(
                      '앱 추천 금액:', //
                      '${recommendedBuyAmount_B.toStringAsFixed(0)} 원',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    TextField(
                      controller: _shortTermBuyAmountController, //
                      decoration: const InputDecoration(labelText: '단기 매수 금액 (원)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '▶ 9시 시초가에 ${finalBuyAmount_B.toStringAsFixed(0)}원 만큼 [단기] 매수 주문을 넣으세요.', //
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green[700]),
                    ),
                  ]),
                  _buildInfoCard("📈 2순위: Track B 분할 매도 (단기 청산)", [
                    //
                    const Text(
                        '시초가 주문 완료 후, 아래 4개의 보통지정가 매도 주문을 (당일 유효)로 거세요. (배분: 15/25/35/25%)'), //
                    _buildDirectiveRow(
                      '1차 (15%):', //
                      '${sellTargetPx1.toStringAsFixed(0)} 원 X ${sellTargetQty1.toStringAsFixed(4)} 주',
                      valueColor: Colors.blue.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      '2차 (25%):', //
                      '${sellTargetPx2.toStringAsFixed(0)} 원 X ${sellTargetQty2.toStringAsFixed(4)} 주',
                      valueColor: Colors.blue.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      '3차 (35%):', //
                      '${sellTargetPx3.toStringAsFixed(0)} 원 X ${sellTargetQty3.toStringAsFixed(4)} 주',
                      valueColor: Colors.blue.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      '4차 (25%):', //
                      '${sellTargetPx4.toStringAsFixed(0)} 원 X ${sellTargetQty4.toStringAsFixed(4)} 주',
                      valueColor: Colors.blue.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const Divider(height: 20),
                    Text(
                      "※ 미체결된 '단기' 물량은 장 마감 후 '장기(Track A)' 물량으로 자동 합산(롤오버)됩니다.", //
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ]),
                ] else if (x < 0) ...[
                  // --- 2. 미국장 하락 시 (x < 0) ---
                  _buildInfoCard("📉 2순위: Track B 4단계 분할 매수 (단기 물타기)", [
                    //
                    Text(
                        '오늘 장중에 아래 4개의 보통지정가 매수 주문을 (당일 유효)로 거세요. (총 매수 예산: ${totalBuyAmount_B_Down.toStringAsFixed(0)}원)'), //
                    _buildDirectiveRow(
                      '1차 (25%):', //
                      '${buyTargetPx1.toStringAsFixed(0)} 원에 ${splitBuyAmount_B_Down.toStringAsFixed(0)}원 만큼 매수',
                      valueColor: Colors.red.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      '2차 (25%):', //
                      '${buyTargetPx2.toStringAsFixed(0)} 원에 ${splitBuyAmount_B_Down.toStringAsFixed(0)}원 만큼 매수',
                      valueColor: Colors.red.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      '3차 (25%):', //
                      '${buyTargetPx3.toStringAsFixed(0)} 원에 ${splitBuyAmount_B_Down.toStringAsFixed(0)}원 만큼 매수',
                      valueColor: Colors.red.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _buildDirectiveRow(
                      '4차 (25%):', //
                      '${buyTargetPx4.toStringAsFixed(0)} 원에 ${splitBuyAmount_B_Down.toStringAsFixed(0)}원 만큼 매수',
                      valueColor: Colors.red.shade700,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ]),
                  _buildInfoCard("📉 Track B: 단기 청산", [
                    //
                    Text(
                        "오늘은 단기 청산이 없습니다. Track B에서 매수한 물량은 즉시 '장기(Track A)' 물량에 합산되어 장기 평단가를 낮춥니다.", //
                        style: TextStyle(color: subTextColor)),
                  ]),
                ] else ...[
                  // --- 3. 미국장 보합 시 (x == 0) ---
                  _buildInfoCard("📊 Track B: 단기 보너스", [
                    //
                    Text(
                        "오늘은 미국장이 보합(x=0)이므로 '단기 보너스' 매매 신호가 없습니다. Track A (무매 기본 전략)만 수행합니다.", //
                        style: TextStyle(color: subTextColor)),
                  ]),
                ],

                // --- (★핵심★) Track A: 무매 지침 (항상 표시) ---
                _buildInfoCard(
                    "🔴 Track A: 조건부지정가 매수(장기 누적) (Star = ${starValue.toStringAsFixed(2)}%)",
                    [
                      _buildDirectiveRow(
                        isFirstBuy_A ? '조건부(장기) 현재가:' : '조건부(장기) 평단:', //
                        '${displayAvgPrice_A.toStringAsFixed(0)} 원 X ${buyQtyAtAvg_A.toStringAsFixed(4)} 주',
                        valueColor: Colors.red.shade700,
                        textColor: textColor,
                        subTextColor: subTextColor,
                      ),
                      _buildDirectiveRow(
                        '조건부(장기) Star%:', //
                        '${calcBuyPrice_A.toStringAsFixed(0)} 원 X ${buyQtyAtStar_A.toStringAsFixed(4)} 주',
                        valueColor: Colors.red.shade700,
                        textColor: textColor,
                        subTextColor: subTextColor,
                      ),
                      const Divider(height: 20),
                      Text('+@ 폭락장(장기) (1주 고정)', // (★수정★) 1주 고정 명시
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textColor)),
                      _buildDirectiveRow(
                          'LOC (평단*98.07%):',
                          '${(displayAvgPrice_A * 0.98067).toStringAsFixed(0)} 원 X 1 주',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor),
                      _buildDirectiveRow(
                          'LOC (평단*95.27%):',
                          '${(displayAvgPrice_A * 0.95267).toStringAsFixed(0)} 원 X 1 주',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor),
                      _buildDirectiveRow(
                          'LOC (평단*92.67%):',
                          '${(displayAvgPrice_A * 0.92667).toStringAsFixed(0)} 원 X 1 주',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor),
                      _buildDirectiveRow(
                          'LOC (평단*90.27%):',
                          '${(displayAvgPrice_A * 0.90267).toStringAsFixed(0)} 원 X 1 주',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor),
                      _buildDirectiveRow(
                          'LOC (평단*88.13%):',
                          '${(displayAvgPrice_A * 0.88133).toStringAsFixed(0)} 원 X 1 주',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor),
                      _buildDirectiveRow(
                          'LOC (평단*86.13%):',
                          '${(displayAvgPrice_A * 0.86133).toStringAsFixed(0)} 원 X 1 주',
                          valueColor: Colors.red.shade700,
                          textColor: textColor,
                          subTextColor: subTextColor),
                    ]),
                _buildInfoCard("🔵 Track A: 지정가 매도 (장기 누적)", [
                  //
                  _buildDirectiveRow(
                    '조건부(장기) Star%:', //
                    '${sellPrice1_A.toStringAsFixed(0)} 원 X ${sellQty1_A.toStringAsFixed(4)} 주',
                    valueColor: Colors.blue.shade700,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildDirectiveRow(
                    'After(장기) $targetProfitRate%:', //
                    '${sellPrice2_A.toStringAsFixed(0)} 원 X ${sellQty2_A.toStringAsFixed(4)} 주',
                    valueColor: Colors.blue.shade700,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                ]),

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

                if ((showSplitFinished || showTargetReached) &&
                    !isManuallyCompleted &&
                    (currentQuantity_A + currentQuantity_B) > 0)
                  // ... (정산 완료 버튼 - 내용 동일) ...
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: OutlinedButton(
                      onPressed: _markAsCompleted,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                      ),
                      child: Text(showSplitFinished
                          ? '정산완료하기 (분할 종료)'
                          : '정산완료하기 (목표 달성)'),
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

  Widget _buildInfoRow(String title, String value,
      {Color? valueColor,
      required Color textColor,
      required Color subTextColor,
      Widget? trailing,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: subTextColor)),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: valueColor ?? textColor,
                  ),
                ),
                if (trailing != null) const SizedBox(width: 8),
                if (trailing != null) trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectiveRow(String title, String value,
      {Color? valueColor,
      required Color textColor,
      required Color subTextColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 4,
            child:
                Text(title, style: TextStyle(color: subTextColor, fontSize: 13)),
          ),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
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