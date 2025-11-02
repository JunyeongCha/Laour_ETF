// lib/screens/cycle_completed_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CycleCompletedScreen extends StatelessWidget {
  // CycleCard에서 전달받을 사이클 문서 데이터
  final Map<String, dynamic> cycleData;

  const CycleCompletedScreen({super.key, required this.cycleData});

  @override
  Widget build(BuildContext context) {
    // 1. 데이터 추출
    final String name = cycleData['name'] ?? '이름 없음';
    final int tValue = (cycleData['T_value'] as num?)?.toInt() ?? 0;
    final double totalPurchaseAmount = (cycleData['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
    
    // 2. (★핵심★) Step A에서 저장한 'totalSellAmount' 필드를 가져옴
    final double totalSellAmount = (cycleData['totalSellAmount'] as num?)?.toDouble() ?? 0.0;

    // 3. (★핵심★) [요청 2] 최종 수익/수익률 계산
    final double finalProfitAmount = totalSellAmount - totalPurchaseAmount;
    final double finalProfitRate = (totalPurchaseAmount == 0)
        ? 0.0
        : (finalProfitAmount / totalPurchaseAmount) * 100;
        
    final Color profitColor = finalProfitAmount >= 0 ? Colors.green.shade700 : Colors.red;

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
                const Text(
                  '🎉 정산 완료 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildResultRow(
                  '총 매수금액:', 
                  '${totalPurchaseAmount.toStringAsFixed(0)} 원'
                ),
                _buildResultRow(
                  '총 매도금액:', 
                  '${totalSellAmount.toStringAsFixed(0)} 원'
                ),
                _buildResultRow(
                  '완료 T-Value:', 
                  '$tValue'
                ),
                const Divider(height: 32),
                _buildResultRow(
                  '최종 수익 금액:',
                  '${finalProfitAmount.toStringAsFixed(0)} 원',
                  valueColor: profitColor,
                ),
                _buildResultRow(
                  '최종 수익률:',
                  '${finalProfitRate.toStringAsFixed(2)} %',
                  valueColor: profitColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI 헬퍼
  Widget _buildResultRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black, // 기본값은 검은색
            ),
          ),
        ],
      ),
    );
  }
}