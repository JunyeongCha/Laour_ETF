import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 'DateFormat'을 사용하기 위한 import
import 'package:laour_etf/widgets/cycle_detail/trade_input_dialog.dart';
import 'package:laour_etf/widgets/cycle_detail/transaction_list.dart';

class CycleDetailScreen extends StatefulWidget {
  final String cycleId;
  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  State<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends State<CycleDetailScreen> {
  // 1. Firestore 참조
  late final DocumentReference _cycleRef;
  late final CollectionReference _transactionsRef;
  late final Stream<DocumentSnapshot> _cycleStream;
  late final Stream<QuerySnapshot> _transactionStream;

  // 2. 실시간 입력을 위한 컨트롤러
  final _currentPriceController = TextEditingController();
  final _starValueController = TextEditingController();
  
  bool _isRecalculating = false; // 재계산 중 로딩 스피너
  double _savedPrice = 0.0; // (★요청 3★) 물타기 비교용

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
    _transactionStream = _transactionsRef.orderBy('date', descending: true).snapshots();

    // 컨트롤러 리스너는 setState만 호출
    _currentPriceController.addListener(_updateRealTimeProfit);
    _starValueController.addListener(_updateRealTimeProfit);

    // 화면 첫 로드 시 1회만 컨트롤러 값을 초기화
    _cycleStream.first.then((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final double price = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;
        _currentPriceController.text = price.toString();
        _starValueController.text = (data['starValue'] as num?)?.toString() ?? '0.0';
        _savedPrice = price; // (★요청 3★) 저장된 가격 보관
      }
    });
  }
  
  void _updateRealTimeProfit() {
    if (mounted) {
      setState(() {
        // build 메서드가 실시간 손익을 재계산합니다.
      });
    }
  }

  // (★수정★) 거래 추가/삭제 시 재계산 로직 (2-Pass)
  Future<void> _recalculateAggregates() async {
    if (mounted) {
      setState(() { _isRecalculating = true; });
    }

    try {
      final QuerySnapshot snapshot = await _transactionsRef.get();
      final allTrades = snapshot.docs;

      // --- [Pass 1] 평단가(Avg. Purchase Price) 계산 ---
      double totalBuyCost = 0.0;
      int totalBuyQuantity = 0;
      Set<String> uniqueDates = {}; 

      for (var doc in allTrades) {
        final data = doc.data() as Map<String, dynamic>;
        
        final DateTime date = (data['date'] as Timestamp).toDate();
        uniqueDates.add(DateFormat('yyyy-MM-dd').format(date));
        
        if (data['type'] == 'buy') {
          totalBuyCost += (data['price'] as num).toDouble() * (data['quantity'] as num).toInt();
          totalBuyQuantity += (data['quantity'] as num).toInt();
        }
      }

      final double avgPrice = (totalBuyQuantity == 0) ? 0.0 : (totalBuyCost / totalBuyQuantity);

      // --- [Pass 2] 실현 손익 및 현재 수량 계산 ---
      double totalSellAmount = 0.0;
      int totalSellQuantity = 0;
      double totalRealizedProfit = 0.0;

      for (var doc in allTrades) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['type'] == 'sell') {
          final double price = (data['price'] as num).toDouble();
          final int quantity = (data['quantity'] as num).toInt();
          
          totalSellAmount += price * quantity;
          totalSellQuantity += quantity;
          totalRealizedProfit += (price - avgPrice) * quantity;
        }
      }

      // --- [Final] 최종 집계 ---
      final int currentQuantity = totalBuyQuantity - totalSellQuantity;
      final int tValue = uniqueDates.length; 

      // (★요청 1★) 만약 계산 결과가 음수면, 로직을 중단 (데이터 꼬임 방지)
      // (이 코드는 _onDeleteTrade의 pre-check가 실패했을 때의 최후의 방어선입니다)
      if (currentQuantity < 0) {
        throw Exception("계산 결과 보유 수량이 음수입니다. 데이터를 확인하세요.");
      }

      await _cycleRef.update({
        'currentPurchaseAmount': totalBuyCost, 
        'avgPrice': avgPrice,                   
        'currentQuantity': currentQuantity,
        'T_value': tValue,
        'totalSellAmount': totalSellAmount,     
        'realizedProfit': totalRealizedProfit,  
      });

    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('재계산 실패: ${e.toString()}'))
         );
       }
    } finally {
      if (mounted) {
        setState(() { _isRecalculating = false; });
      }
    }
  }

  // "간편 입력" 버튼 로직 (★요청 1★: 현재가 자동 반영)
  void _onAddNewTrade(int currentQuantity) async {
    final Map<String, dynamic>? newTrade = await TradeInputDialog.show(context);

    if (newTrade != null) {
      // (★요청 1★) 음수 보유량 방지
      if (newTrade['type'] == 'sell' && (newTrade['quantity'] as int) > currentQuantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('보유 주식수보다 많이 매도할 수 없습니다.')),
          );
        }
        return; 
      }
      
      final double newPrice = newTrade['price'];
      
      await _transactionsRef.add({
        'date': Timestamp.fromDate(newTrade['date']),
        'price': newPrice,
        'quantity': newTrade['quantity'],
        'type': newTrade['type'],
      });
      
      if (mounted) {
        _currentPriceController.text = newPrice.toString();
        _savedPrice = newPrice; // (★요청 3★) 물타기 기준 가격도 업데이트
      }
      
      await _cycleRef.update({'currentPrice': newPrice});

      await _recalculateAggregates(); 
    }
  }

  // "X" 삭제 버튼 로직 (★요청 1★: 버그 수정)
  void _onDeleteTrade(String transactionId, String type, int quantity, int currentQuantity) async {
    
    // (★요청 1★) 매수 기록 삭제 시 음수 보유량 방지 (수정된 로직)
    // "현재 수량"이 "삭제할 매수 수량"보다 적으면, 삭제 후 음수가 됨
    if (type == 'buy' && currentQuantity < quantity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매수 내역 삭제 시 보유주식수가 음수가 됩니다. (먼저 매도 내역을 삭제하세요)')),
        );
      }
      return; // 삭제 중단
    }
    
    await _transactionsRef.doc(transactionId).delete();
    await _recalculateAggregates(); // 재계산
  }
  
  // 현재가/Star 값 Firestore에 저장
  Future<void> _saveCurrentData() async {
     try {
        final double price = double.tryParse(_currentPriceController.text) ?? 0.0;
        final double star = double.tryParse(_starValueController.text) ?? 0.0;
        
        await _cycleRef.update({
          'currentPrice': price,
          'starValue': star,
        });
        
        if (mounted) {
          _savedPrice = price; // (★요청 3★) 저장 시 물타기 기준 가격 업데이트
          FocusManager.instance.primaryFocus?.unfocus(); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('현재가/Star 값이 저장되었습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('저장 실패: ${e.toString()}'))
             );
          }
      }
  }

  // (★요청 4★) 수동 정산 완료
  Future<void> _markAsCompleted() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('수동 정산 완료'),
            content: const Text('분할 매수가 완료되었습니다. 이 사이클을 "정산 완료"로 처리하시겠습니까? (손익과 관계없이 완료 처리됩니다.)'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('완료')),
            ],
          ),
        ) ?? false;
  
    if (confirm) {
      try {
        await _cycleRef.update({'isManuallyCompleted': true});
        if (mounted) Navigator.pop(context); // Go back to home
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('정산 완료 처리 실패: ${e.toString()}'))
          );
        }
      }
    }
  }


  @override
  void dispose() {
    _currentPriceController.removeListener(_updateRealTimeProfit);
    _starValueController.removeListener(_updateRealTimeProfit);
    _currentPriceController.dispose();
    _starValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _cycleStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isRecalculating) {
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
        final double totalSeed = (data['totalSeed'] as num?)?.toDouble() ?? 0.0;
        final int splitCount = (data['splitCount'] as num?)?.toInt() ?? 1;
        final double targetProfitRate = (data['targetProfitRate'] as num?)?.toDouble() ?? 0.0;
        final double oneTimeInvestment = (splitCount == 0) ? 0 : (totalSeed / splitCount);

        // (B. 핵심 상태 변수)
        final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0; 
        final int currentQuantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
        final double currentPurchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0; 
        final int tValue = (data['T_value'] as num?)?.toInt() ?? 0;
        final double realizedProfit = (data['realizedProfit'] as num?)?.toDouble() ?? 0.0; 
        final bool isManuallyCompleted = (data['isManuallyCompleted'] as bool?) ?? false;

        // (C. 컨트롤러 실시간 값)
        final double starValue = double.tryParse(_starValueController.text) ?? 0.0;
        final double currentPrice = double.tryParse(_currentPriceController.text) ?? 0.0;
        
        // (★요청 4★) 최초 매수 로직
        final bool isFirstBuy = (avgPrice == 0 && currentQuantity == 0);
        final double displayAvgPrice = isFirstBuy ? currentPrice : avgPrice;

        // (D. 평가 손익/Unrealized)
        double currentProfitRate = 0.0;
        double currentProfitLoss = 0.0;
        Color currentProfitColor = Colors.grey; 
        
        if (currentPrice > 0 && avgPrice > 0 && currentQuantity > 0) {
          currentProfitRate = ((currentPrice / avgPrice) - 1) * 100;
          currentProfitLoss = (currentPrice - avgPrice) * currentQuantity;
          currentProfitColor = currentProfitLoss >= 0 ? Colors.red : Colors.blue.shade700;
        }

        // (E. 매수 지침)
        final double calcBuyPrice = displayAvgPrice * (1 + (starValue / 100)); 
        final double oneTimeSplitAmount = oneTimeInvestment / 2;
        final double buyQtyAtAvg = (displayAvgPrice == 0) ? 0 : (oneTimeSplitAmount / displayAvgPrice);
        final double buyQtyAtStar = (calcBuyPrice == 0) ? 0 : (oneTimeSplitAmount / calcBuyPrice);
        
        // (F. 매도 지침)
        final double sellPrice1 = calcBuyPrice + 1;
        final double sellQty1 = currentQuantity / 4.0;
        final double sellPrice2 = displayAvgPrice * (1 + (targetProfitRate / 100));
        final double sellQty2 = currentQuantity * 3.0 / 4.0;
        
        // (★요청 3★) "물타기" 텍스트 로직
        bool showBuyTheDip = false;
        if (_savedPrice > 0 && currentPrice > 0 && currentQuantity > 0) {
          if (currentPrice <= (_savedPrice * 0.90)) {
            showBuyTheDip = true;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard("평가 손익 (Unrealized)", [
                  TextField(
                    controller: _currentPriceController,
                    decoration: const InputDecoration(labelText: '현재 주가 입력 (원)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _starValueController,
                    decoration: const InputDecoration(labelText: '오늘의 Star 값 입력 (%)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('현재가 / Star 값 저장'),
                      onPressed: _saveCurrentData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('현재 수익률:', '${currentProfitRate.toStringAsFixed(2)} %', valueColor: currentProfitColor),
                  _buildInfoRow('현재 손익:', '${currentProfitLoss.toStringAsFixed(0)} 원', valueColor: currentProfitColor),
                ]),
                
                // (★요청 3★) "물타기" 텍스트
                if (showBuyTheDip)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '물타기 드가자!!! 주워담아!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                
                // (★요청 3★) T-Value -> "진행 분할수"
                _buildInfoCard("사이클 현황 (진행 $tValue / $splitCount 분할)", [
                  _buildInfoRow(
                    '평단가:', 
                    isFirstBuy ? '- (최초 매수 대기)' : '${avgPrice.toStringAsFixed(0)} 원'
                  ),
                  _buildInfoRow('보유 수량:', '$currentQuantity 주'),
                  _buildInfoRow('총 매수 금액:', '${currentPurchaseAmount.toStringAsFixed(0)} 원'),
                  _buildInfoRow(
                    '실현 손익 (Realized):', 
                    '${realizedProfit.toStringAsFixed(0)} 원',
                    valueColor: realizedProfit >= 0 ? Colors.red : Colors.blue.shade700,
                  ),
                  const Divider(height: 16),
                  _buildInfoRow('1회 투자금:', '${oneTimeInvestment.toStringAsFixed(0)} 원'),
                ]),
                
                // (E. 매수 지침)
                _buildInfoCard("🔴 매수 지침 (Star = $starValue%)", [
                  _buildDirectiveRow(
                    isFirstBuy ? 'LOC 현재가:' : 'LOC 평단:',
                    '${displayAvgPrice.toStringAsFixed(0)} 원 X ${buyQtyAtAvg.toStringAsFixed(4)} 주',
                    valueColor: Colors.red.shade700,
                  ),
                  _buildDirectiveRow(
                    'LOC ${starValue}%:',
                    '${calcBuyPrice.toStringAsFixed(0)} 원 X ${buyQtyAtStar.toStringAsFixed(4)} 주',
                    valueColor: Colors.red.shade700,
                  ),
                  const Divider(height: 20),
                  const Text('+@ 폭락장 대비 추가 매수 (규칙 2)', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildDirectiveRow('LOC:', '${(displayAvgPrice * 0.971).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700),
                  _buildDirectiveRow('LOC:', '${(displayAvgPrice * 0.929).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700),
                  _buildDirectiveRow('LOC:', '${(displayAvgPrice * 0.890).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700),
                  _buildDirectiveRow('LOC:', '${(displayAvgPrice * 0.854).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700),
                  _buildDirectiveRow('LOC:', '${(displayAvgPrice * 0.822).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700),
                  _buildDirectiveRow('LOC:', '${(displayAvgPrice * 0.792).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700),
                ]),

                // (F. 매도 지침)
                _buildInfoCard("🔵 매도 지침 (목표 = $targetProfitRate%)", [
                  _buildDirectiveRow( 
                    'LOC ${starValue}%:',
                    '${sellPrice1.toStringAsFixed(0)} 원 X ${sellQty1.toStringAsFixed(4)} 주',
                    valueColor: Colors.blue.shade700,
                  ),
                  _buildDirectiveRow(
                    'After $targetProfitRate%:',
                    '${sellPrice2.toStringAsFixed(0)} 원 X ${sellQty2.toStringAsFixed(4)} 주',
                    valueColor: Colors.blue.shade700,
                  ),
                ]),
                
                ElevatedButton(
                  onPressed: () => _onAddNewTrade(currentQuantity),
                  child: const Text('간편 입력 (거래 추가)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('거래 내역', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TransactionList(
                  transactionStream: _transactionStream,
                  onDelete: (transactionId, type, quantity) => _onDeleteTrade(
                    transactionId, 
                    type, 
                    quantity, 
                    currentQuantity
                  ),
                ),

                // (★요청 4★) "정산완료하기" 버튼
                // (T-Value가 분할수보다 크거나 같고, 수동 완료되지 않았으며, 수량이 0보다 클 때)
                if (tValue >= splitCount && !isManuallyCompleted && currentQuantity > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: OutlinedButton(
                      onPressed: _markAsCompleted,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                      ),
                      child: const Text('정산완료하기 (분할 종료)'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // UI 헬퍼 위젯 1
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
  
  // UI 헬퍼 위젯 2
  Widget _buildInfoRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // UI 헬퍼 위젯 3 (지침용)
  Widget _buildDirectiveRow(String title, String value, {Color? valueColor}) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}