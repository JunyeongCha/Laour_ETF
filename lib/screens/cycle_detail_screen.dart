// lib/screens/cycle_detail_screen.dart

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

  // (오류 수정) 불필요한 State 변수 삭제됨
  
  bool _isRecalculating = false; // 재계산 중 로딩 스피너

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

    // 컨트롤러 리스너 추가
    _currentPriceController.addListener(_updateRealTimeProfit);
    _starValueController.addListener(_updateRealTimeProfit);
  }
  
  // (오류 수정) 불필요한 변수 선언 삭제
  void _updateRealTimeProfit() {
    // setState()를 호출하여 build 메서드가 컨트롤러 값을 다시 읽도록 함
    setState(() {
      // build 메서드가 실시간 손익을 재계산합니다.
    });
  }

  // (★핵심★) 거래 추가/삭제 시 재계산 로직
  Future<void> _recalculateAggregates() async {
    setState(() { _isRecalculating = true; });

    try {
      final QuerySnapshot snapshot = await _transactionsRef.get();
      final allTrades = snapshot.docs;

      double totalPurchaseAmount = 0.0;
      double totalSellAmount = 0.0;
      int totalBuyQuantity = 0;
      int totalSellQuantity = 0;
      // (B-2) T-Value (고유 날짜) 계산용
      Set<String> uniqueDates = {}; 

      for (var doc in allTrades) {
        final data = doc.data() as Map<String, dynamic>;
        final String type = data['type'];
        final double price = (data['price'] as num).toDouble();
        final int quantity = (data['quantity'] as num).toInt();
        
        final DateTime date = (data['date'] as Timestamp).toDate();
        // (오류 수정) DateFormat이 정상적으로 작동
        uniqueDates.add(DateFormat('yyyy-MM-dd').format(date));

        if (type == 'buy') {
          totalPurchaseAmount += (price * quantity);
          totalBuyQuantity += quantity;
        } else if (type == 'sell') {
          totalSellAmount += (price * quantity);
          totalSellQuantity += quantity;
        }
      }

      // (B. 핵심 변수) 재계산
      final int currentQuantity = totalBuyQuantity - totalSellQuantity;
      final double avgPrice = (currentQuantity == 0)
          ? 0.0
          : (totalPurchaseAmount - totalSellAmount) / currentQuantity;
      // (B-2) T-Value (요청사항 반영)
      final int tValue = uniqueDates.length; 

      // (★핵심★) 메인 'cycle' 문서를 이 새 데이터로 '업데이트'
      await _cycleRef.update({
        'currentPurchaseAmount': totalPurchaseAmount,
        'currentQuantity': currentQuantity,
        'avgPrice': avgPrice,
        'T_value': tValue,
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

  // "간편 입력" 버튼 로직
  void _onAddNewTrade() async {
    final Map<String, dynamic>? newTrade = await TradeInputDialog.show(context);

    if (newTrade != null) {
      await _transactionsRef.add({
        'date': Timestamp.fromDate(newTrade['date']),
        'price': newTrade['price'],
        'quantity': newTrade['quantity'],
        'type': newTrade['type'],
      });
      await _recalculateAggregates(); // (★핵심★) 재계산
    }
  }

  // "X" 삭제 버튼 로직 (규칙 6)
  void _onDeleteTrade(String transactionId) async {
    await _transactionsRef.doc(transactionId).delete();
    await _recalculateAggregates(); // (★핵심★) 재계산
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
        final double oneTimeInvestment = totalSeed / splitCount;

        // (B. 핵심 상태 변수)
        final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
        final int currentQuantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
        final double currentPurchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
        final int tValue = (data['T_value'] as num?)?.toInt() ?? 0; // (T값)

        // (C. Star 값) (요청사항: 수동 입력)
        final double starValue = double.tryParse(_starValueController.text) ?? 0.0;

        // (D. 실시간 손익) (규칙 1.5)
        final double currentPrice = double.tryParse(_currentPriceController.text) ?? 0.0;
        double currentProfitRate = 0.0;
        double currentProfitLoss = 0.0;
        if (currentPrice > 0 && avgPrice > 0) {
          currentProfitRate = ((currentPrice / avgPrice) - 1) * 100;
          currentProfitLoss = (currentPrice - avgPrice) * currentQuantity;
        }

        // (E. 매수 지침) (규칙 2, 3, 5)
        final double calcBuyPrice = avgPrice * (1 + (starValue / 100)); // (요청사항 3)
        final double oneTimeSplitAmount = oneTimeInvestment / 2; // (요청사항 2: 1:1)
        final double buyQtyAtAvg = (avgPrice == 0) ? 0 : (oneTimeSplitAmount / avgPrice);
        final double buyQtyAtStar = (calcBuyPrice == 0) ? 0 : (oneTimeSplitAmount / calcBuyPrice);
        
        // (F. 매도 지침) (규칙 3, 4, 5)
        final double sellPrice1 = calcBuyPrice + 1; // (요청사항 3)
        final double sellQty1 = currentQuantity / 4.0;
        final double sellPrice2 = avgPrice * (1 + (targetProfitRate / 100)); // (요청사항 4)
        final double sellQty2 = currentQuantity * 3.0 / 4.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // (규칙 1.5) 실시간 현황
                _buildInfoCard("실시간 현황", [
                  TextField(
                    controller: _currentPriceController,
                    decoration: const InputDecoration(labelText: '현재 주가 입력 (원)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _starValueController,
                    decoration: const InputDecoration(labelText: '오늘의 Star 값 입력 (%)'), // (요청사항)
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('현재 수익률:', '${currentProfitRate.toStringAsFixed(2)} %'),
                  _buildInfoRow('현재 손익:', '${currentProfitLoss.toStringAsFixed(0)} 원'),
                ]),
                
                // (B. 핵심 상태 변수)
                _buildInfoCard("사이클 현황 (T=$tValue / $splitCount)", [
                  _buildInfoRow('평단가:', '${avgPrice.toStringAsFixed(0)} 원'),
                  _buildInfoRow('보유 수량:', '$currentQuantity 주'),
                  _buildInfoRow('총 매입 금액:', '${currentPurchaseAmount.toStringAsFixed(0)} 원'),
                  _buildInfoRow('1회 투자금:', '${oneTimeInvestment.toStringAsFixed(0)} 원'),
                ]),
                
                // (E. 매수 지침)
                _buildInfoCard("🔴 매수 지침 (Star = $starValue%)", [ // (규칙 5)
                  _buildDirectiveRow( // (요청사항 2: 1:1)
                    'LOC 평단:',
                    '${avgPrice.toStringAsFixed(0)} 원 X ${buyQtyAtAvg.toStringAsFixed(4)} 주'
                  ),
                  _buildDirectiveRow( // (요청사항 2: 1:1)
                    'LOC ${starValue}%:',
                    '${calcBuyPrice.toStringAsFixed(0)} 원 X ${buyQtyAtStar.toStringAsFixed(4)} 주'
                  ),
                  const Divider(height: 20),
                  const Text('+@ 폭락장 대비 추가 매수 (규칙 2)', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildDirectiveRow('LOC:', '${(avgPrice * 0.971).toStringAsFixed(0)} 원 X 1 주'), // (요청사항 2: 6줄)
                  _buildDirectiveRow('LOC:', '${(avgPrice * 0.929).toStringAsFixed(0)} 원 X 1 주'), // (요청사항 2: 6줄)
                  _buildDirectiveRow('LOC:', '${(avgPrice * 0.890).toStringAsFixed(0)} 원 X 1 주'), // (요청사항 2: 6줄)
                  _buildDirectiveRow('LOC:', '${(avgPrice * 0.854).toStringAsFixed(0)} 원 X 1 주'), // (요청사항 2: 6줄)
                  _buildDirectiveRow('LOC:', '${(avgPrice * 0.822).toStringAsFixed(0)} 원 X 1 주'), // (요청사항 2: 6줄)
                  _buildDirectiveRow('LOC:', '${(avgPrice * 0.792).toStringAsFixed(0)} 원 X 1 주'), // (요청사항 2: 6줄)
                ]),

                // (F. 매도 지침)
                _buildInfoCard("🔵 매도 지침 (목표 = $targetProfitRate%)", [ // (규칙 5)
                  _buildDirectiveRow( // (요청사항 3)
                    'LOC ${starValue}%:',
                    '${sellPrice1.toStringAsFixed(0)} 원 X ${sellQty1.toStringAsFixed(4)} 주'
                  ),
                  _buildDirectiveRow( // (요청사항 4)
                    'After $targetProfitRate%:',
                    '${sellPrice2.toStringAsFixed(0)} 원 X ${sellQty2.toStringAsFixed(4)} 주'
                  ),
                ]),
                
                // (규칙 6) "간편 입력" 버튼
                ElevatedButton(
                  onPressed: _onAddNewTrade,
                  child: const Text('간편 입력 (거래 추가)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),

                // 4-4. 거래 내역 리스트
                const Text('거래 내역', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TransactionList(
                  transactionStream: _transactionStream,
                  onDelete: _onDeleteTrade, // (규칙 6: 삭제)
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
  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // UI 헬퍼 위젯 3 (지침용)
  Widget _buildDirectiveRow(String title, String value) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}