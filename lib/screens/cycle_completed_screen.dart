import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // (★신규★)
import 'package:laour_etf/providers/theme_provider.dart'; // (★신규★)

class CycleCompletedScreen extends StatelessWidget {
  // CycleCard에서 전달받을 사이클 문서 데이터
  final Map<String, dynamic> cycleData;

  const CycleCompletedScreen({super.key, required this.cycleData});

  @override
  Widget build(BuildContext context) {
    // (★신규★) 2번: 다크모드 텍스트 색상 처리를 위해
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey.shade700;

    // 1. 데이터 추출
    final String name = cycleData['name'] ?? '이름 없음';
    final int tValue = (cycleData['T_value'] as num?)?.toInt() ?? 0;
    
    final double totalPurchaseAmount = (cycleData['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
    final double totalSellAmount = (cycleData['totalSellAmount'] as num?)?.toDouble() ?? 0.0;
    final double finalProfitAmount = (cycleData['realizedProfit'] as num?)?.toDouble() ?? 0.0; 

    // 3. 최종 수익/수익률 계산
    final double finalProfitRate = (totalPurchaseAmount == 0)
        ? 0.0
        : (finalProfitAmount / totalPurchaseAmount) * 100;
        
    final Color profitColor = finalProfitAmount >= 0 ? Colors.red : Colors.blue.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text('$name (정산 완료)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 카드 크기를 내용물에 맞춤
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text( // (★수정★) 2번
                  '🎉 정산 완료 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: textColor, // (★수정★)
                  ),
                ),
                const SizedBox(height: 24),
                _buildResultRow(
                  '총 매수금액:', 
                  '${totalPurchaseAmount.toStringAsFixed(0)} 원',
                  textColor: textColor, // (★수정★) 2번
                  subTextColor: subTextColor, // (★수정★) 2번
                ),
                _buildResultRow(
                  '총 매도금액:', 
                  '${totalSellAmount.toStringAsFixed(0)} 원',
                  textColor: textColor, 
                  subTextColor: subTextColor
                ),
                _buildResultRow(
                  '종료 분할수:', 
                  '$tValue',
                  textColor: textColor, 
                  subTextColor: subTextColor
                ),
                const Divider(height: 32),
                _buildResultRow(
                  '최종 실현 수익:', 
                  '${finalProfitAmount.toStringAsFixed(0)} 원',
                  valueColor: profitColor,
                  textColor: textColor, 
                  subTextColor: subTextColor
                ),
                _buildResultRow(
                  '최종 수익률:',
                  '${finalProfitRate.toStringAsFixed(2)} %',
                  valueColor: profitColor,
                  textColor: textColor, 
                  subTextColor: subTextColor
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (★수정★) 2번: 헬퍼 함수가 다크모드 색상을 받도록 수정
  Widget _buildResultRow(String title, String value, {Color? valueColor, required Color textColor, required Color subTextColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: subTextColor)),
          Text(
            value,
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: valueColor ?? textColor,
            ),
          ),
        ],
      ),
    );
  }
}