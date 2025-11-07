
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
    _transactionStream = _transactionsRef.orderBy('date', descending: true).snapshots();

    _currentPriceController.addListener(_updateRealTimeProfit);
    _starValueController.addListener(_updateRealTimeProfit);

    _cycleStream.first.then((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final double price = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;
        _currentPriceController.text = price.toString();
        // (★수정★) 4번: starValue는 3배수 값
        _starValueController.text = (data['starValue'] as num?)?.toString() ?? '0.0';
        _savedPrice = price; 
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

      if (currentQuantity < 0) {
        throw Exception("계산 결과 보유 수량이 음수입니다.");
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
       rethrow; 
    } finally {
      if (mounted) {
        setState(() { _isRecalculating = false; });
      }
    }
  }

  // "간편 입력" 버튼 로직
  void _onAddNewTrade() async {
    final DocumentSnapshot currentDoc = await _cycleRef.get();
    final int currentQuantity = (currentDoc.data() as Map<String, dynamic>)['currentQuantity'] ?? 0;

    final Map<String, dynamic>? newTrade = await TradeInputDialog.show(context);

    if (newTrade != null) {
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
        _savedPrice = newPrice; 
      }
      
      await _cycleRef.update({'currentPrice': newPrice});

      await _recalculateAggregates(); 
    }
  }

  // "X" 삭제 버튼 로직
  void _onDeleteTrade(String transactionId, String type, int quantity, DateTime date, double price) async {
    
    final DocumentSnapshot currentDoc = await _cycleRef.get();
    final int currentQuantity = (currentDoc.data() as Map<String, dynamic>)['currentQuantity'] ?? 0;
    
    if (type == 'buy' && currentQuantity < quantity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매수 내역 삭제 시 보유주식수가 음수가 됩니다. (먼저 매도 내역을 삭제하세요)')),
        );
      }
      return; 
    }
    
    try {
      await _transactionsRef.doc(transactionId).delete();
      await _recalculateAggregates();

    } catch (e) {
      if (e.toString().contains("보유 수량이 음수")) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오류: 보유 수량이 음수가 됩니다. 삭제를 취소합니다.')),
          );
        }
        
        await _transactionsRef.doc(transactionId).set({ 
            'date': Timestamp.fromDate(date),
            'price': price,
            'quantity': quantity,
            'type': type,
        });
        
        await _recalculateAggregates();
      
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제/계산 중 알 수 없는 오류: ${e.toString()}'))
          );
        }
      }
    }
  }
  
  // 현재가/Star 값 Firestore에 저장
  Future<void> _saveCurrentData() async {
     try {
        final double price = double.tryParse(_currentPriceController.text) ?? 0.0;
        final double star = double.tryParse(_starValueController.text) ?? 0.0;
        
        await _cycleRef.update({
          'currentPrice': price,
          'starValue': star, // (★수정★) 4번: 3배수 값이 저장됨
        });
        
        if (mounted) {
          _savedPrice = price; 
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

  // (★수정★) 1번, 3번: 이름/닉네임/총 시드 수정 다이얼로그
  Future<void> _showEditInfoDialog(String currentName, String currentNickname, double currentSeed) async {
    _nameEditController.text = currentName;
    _nicknameEditController.text = currentNickname;
    _totalSeedEditController.text = currentSeed.toStringAsFixed(0); // (★신규★) 3번

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('사이클 정보 수정'),
          content: SingleChildScrollView( // 스크롤 가능하게
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameEditController,
                  decoration: const InputDecoration(labelText: '이름 (예: TIGER 나스닥100)'),
                ),
                TextField(
                  controller: _nicknameEditController,
                  decoration: const InputDecoration(labelText: '닉네임 (선택)'),
                ),
                // (★신규★) 3번: 총 시드 수정
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
                final double newSeed = double.tryParse(_totalSeedEditController.text) ?? 0.0;

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
                  // (★신규★) 3번: totalSeed 업데이트
                  await _cycleRef.update({
                    'name': newName,
                    'nickname': newNickname,
                    'totalSeed': newSeed,
                  });
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('수정 실패: ${e.toString()}'))
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 수동 정산 완료
  Future<void> _markAsCompleted() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('수동 정산 완료'),
            content: const Text('이 사이클을 "정산 완료"로 처리하시겠습니까?'),
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
    _nameEditController.dispose(); 
    _nicknameEditController.dispose(); 
    _totalSeedEditController.dispose(); // (★신규★) 3번
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (★신규★) 2번: 다크모드 텍스트 색상 처리를 위해
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey.shade700;
    
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
        final String nickname = data['nickname'] ?? ''; 
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
        // (★수정★) 4번: 3배수 Star 값
        final double starValue_3x = double.tryParse(_starValueController.text) ?? 0.0;
        final double currentPrice = double.tryParse(_currentPriceController.text) ?? 0.0;
        
        // (★신규★) 4번: 실제 계산에 사용할 2배수 Star 값
        final double starValue = (starValue_3x * 2) / 3.0;

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
        
        bool showBuyTheDip = false;
        if (_savedPrice > 0 && currentPrice > 0 && currentQuantity > 0) {
          if (currentPrice <= (_savedPrice * 0.90)) {
            showBuyTheDip = true;
          }
        }
        
        bool showTargetReached = false;
        if (targetProfitRate > 0 && currentProfitRate >= targetProfitRate) {
          showTargetReached = true;
        }
        
        bool showSplitFinished = (tValue >= splitCount && !isManuallyCompleted && currentQuantity > 0);
        
        // (★신규★) 목표 달성률 계산
        double achievementRate = (targetProfitRate == 0 || currentProfitRate < 0) 
            ? 0 
            : (currentProfitRate / targetProfitRate);
        achievementRate = achievementRate.clamp(0.0, 1.0); // 0% ~ 100%

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name),
                if (nickname.isNotEmpty)
                  Text(
                    nickname,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '이름/닉네임/시드 수정', // (★수정★) 3번
                onPressed: () {
                  // (★수정★) 3번
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
                _buildInfoCard("평가 손익 (Unrealized)", [
                  TextField(
                    controller: _currentPriceController,
                    decoration: const InputDecoration(labelText: '현재 주가 입력 (원)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _starValueController,
                    // (★수정★) 4번: 라벨 변경
                    decoration: const InputDecoration(labelText: '오늘의 3배수 Star 값 (%)'),
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
                  _buildInfoRow(
                    '현재 수익률:', 
                    '${currentProfitRate.toStringAsFixed(2)} %', 
                    valueColor: currentProfitColor,
                    textColor: textColor, // (★수정★) 2번
                    subTextColor: subTextColor, // (★수정★) 2번
                  ),
                  _buildInfoRow(
                    '현재 손익:', 
                    '${currentProfitLoss.toStringAsFixed(0)} 원', 
                    valueColor: currentProfitColor,
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  
                  // (★신규★) 목표 수익률 및 달성률
                  const Divider(height: 16),
                  _buildInfoRow(
                    '목표 수익률:', 
                    '${targetProfitRate.toStringAsFixed(1)} %',
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('달성률:', style: TextStyle(color: subTextColor)),
                            Text(
                              '${(achievementRate * 100).toStringAsFixed(1)} %',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
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
                
                if (showTargetReached && !showSplitFinished)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        Text(
                          '목표 수익률 달성! 마무리 하셔도 됩니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red, // 붉은색
                          ),
                        ),
                        Text(
                          '혹시 모르니 현재주가를 확인해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700, // 파란색
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildInfoCard("사이클 현황 (진행 $tValue / $splitCount 분할)", [
                  _buildInfoRow(
                    '총 시드:', 
                    '${totalSeed.toStringAsFixed(0)} 원',
                    textColor: textColor, // (★수정★) 2번
                    subTextColor: subTextColor, // (★수정★) 2번
                    // (★신규★) 3번: 수정 기능
                    trailing: Icon(Icons.edit, size: 16, color: subTextColor),
                    onTap: () => _showEditInfoDialog(name, nickname, totalSeed),
                  ),
                  _buildInfoRow(
                    '평단가:', 
                    isFirstBuy ? '- (최초 매수 대기)' : '${avgPrice.toStringAsFixed(0)} 원',
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  _buildInfoRow(
                    '보유 수량:', 
                    '$currentQuantity 주',
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  _buildInfoRow(
                    '총 매수 금액:', 
                    '${currentPurchaseAmount.toStringAsFixed(0)} 원',
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  _buildInfoRow(
                    '실현 손익 (Realized):', 
                    '${realizedProfit.toStringAsFixed(0)} 원',
                    valueColor: realizedProfit >= 0 ? Colors.red : Colors.blue.shade700,
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(
                    '1회 투자금:', 
                    '${oneTimeInvestment.toStringAsFixed(0)} 원',
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                ]),
                
                // (★수정★) 4번: 3배수 Star 값으로 라벨 변경
                _buildInfoCard("🔴 매수 지침 (2배수 Star = ${starValue.toStringAsFixed(2)}%)", [
                  _buildDirectiveRow(
                    isFirstBuy ? 'LOC 현재가:' : 'LOC 평단:',
                    '${displayAvgPrice.toStringAsFixed(0)} 원 X ${buyQtyAtAvg.toStringAsFixed(4)} 주',
                    valueColor: Colors.red.shade700,
                    textColor: textColor, // (★수정★) 2번
                    subTextColor: subTextColor, // (★수정★) 2번
                  ),
                  _buildDirectiveRow(
                    // (★수정★) 2번: 라벨을 2배수 Star 값으로 단순화
                    'LOC ${starValue.toStringAsFixed(2)}%:',
                    '${calcBuyPrice.toStringAsFixed(0)} 원 X ${buyQtyAtStar.toStringAsFixed(4)} 주',
                    valueColor: Colors.red.shade700,
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                  const Divider(height: 20),
                  Text(
                    '+@ 폭락장 대비 추가 매수 (2배수 기준)', // (★수정★) 4번 
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor) // (★수정★) 2번
                  ),
                  // (★수정★) 4번: 퍼센트 및 배율 변경
                  _buildDirectiveRow('LOC (평단*98.07%):', '${(displayAvgPrice * 0.98067).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700, textColor: textColor, subTextColor: subTextColor),
                  _buildDirectiveRow('LOC (평단*95.27%):', '${(displayAvgPrice * 0.95267).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700, textColor: textColor, subTextColor: subTextColor),
                  _buildDirectiveRow('LOC (평단*92.67%):', '${(displayAvgPrice * 0.92667).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700, textColor: textColor, subTextColor: subTextColor),
                  _buildDirectiveRow('LOC (평단*90.27%):', '${(displayAvgPrice * 0.90267).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700, textColor: textColor, subTextColor: subTextColor),
                  _buildDirectiveRow('LOC (평단*88.13%):', '${(displayAvgPrice * 0.88133).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700, textColor: textColor, subTextColor: subTextColor),
                  _buildDirectiveRow('LOC (평단*86.13%):', '${(displayAvgPrice * 0.86133).toStringAsFixed(0)} 원 X 1 주', valueColor: Colors.red.shade700, textColor: textColor, subTextColor: subTextColor),
                ]),

                _buildInfoCard("🔵 매도 지침 (목표 = $targetProfitRate%)", [
                  _buildDirectiveRow( 
                    // (★수정★) 2번: 라벨을 2배수 Star 값으로 단순화
                    'LOC ${starValue.toStringAsFixed(2)}%:',
                    '${sellPrice1.toStringAsFixed(0)} 원 X ${sellQty1.toStringAsFixed(4)} 주',
                    valueColor: Colors.blue.shade700,
                    textColor: textColor, 
                    subTextColor: subTextColor, 
                  ),
                  _buildDirectiveRow(
                    'After $targetProfitRate%:',
                    '${sellPrice2.toStringAsFixed(0)} 원 X ${sellQty2.toStringAsFixed(4)} 주',
                    valueColor: Colors.blue.shade700,
                    textColor: textColor, 
                    subTextColor: subTextColor
                  ),
                ]),
                
                ElevatedButton(
                  onPressed: _onAddNewTrade,
                  child: const Text('간편 입력 (거래 추가)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),

                Text('거래 내역', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)), 
                TransactionList(
                  transactionStream: _transactionStream,
                  isJunyeongMode: false, // (★수정★) "무매" 모드임을 명시
                  
                  // (★수정★) 6번째 isShortTerm 인자를 받도록 수정
                  onDelete: (String transactionId, String type, int quantity, DateTime date, double price, bool isShortTerm) {
                    
                    // "무매"에서는 isShortTerm 인자를 무시하고 
                    // 기존 _onDeleteTrade (5개 인자)를 호출합니다.
                    _onDeleteTrade(
                      transactionId, 
                      type, 
                      quantity,
                      date,     
                      price     
                    );
                  },
                ),

                if ((showSplitFinished || showTargetReached) && !isManuallyCompleted && currentQuantity > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: OutlinedButton(
                      onPressed: _markAsCompleted,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade700),
                      ),
                      child: Text(showSplitFinished ? '정산완료하기 (분할 종료)' : '정산완료하기 (목표 달성)'),
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
            Text(
              title, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color, 
              )
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
  
  // (★수정★) 2번, 3번: 헬퍼 함수가 다크모드 색상 및 onTap/trailing을 받도록 수정
  Widget _buildInfoRow(String title, String value, {Color? valueColor, required Color textColor, required Color subTextColor, Widget? trailing, VoidCallback? onTap}) {
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

  // (★수정★) 2번: 헬퍼 함수가 다크모드 색상을 받도록 수정
  Widget _buildDirectiveRow(String title, String value, {Color? valueColor, required Color textColor, required Color subTextColor}) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: subTextColor)), 
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? textColor, 
            ),
          ),
        ],
      ),
    );
  }
}