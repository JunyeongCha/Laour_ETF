import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompletedStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const CompletedStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    double totalRealizedProfit = 0.0;
    double totalPurchaseAmount = 0.0;
    double totalSellAmount = 0.0;
    int totalTValues = 0;

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      totalRealizedProfit += (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
      totalPurchaseAmount += (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
      totalSellAmount += (data['totalSellAmount'] as num?)?.toDouble() ?? 0.0;
      totalTValues += (data['T_value'] as num?)?.toInt() ?? 0;
    }

    final int portfolioCount = cycleDocs.length;
    
    final double avgProfitRate = (totalPurchaseAmount == 0) 
        ? 0.0 
        : (totalSellAmount / totalPurchaseAmount - 1) * 100;
        
    final double avgTValue = (portfolioCount == 0) ? 0.0 : (totalTValues / portfolioCount);

    // (★요청 2★) 색상 변경: 수익=빨강, 손해=파랑
    final Color profitColor = totalRealizedProfit >= 0 ? Colors.red : Colors.blue.shade700;

    return Card(
      elevation: 2.0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusRow(
              '총 실현 수익:', 
              '${totalRealizedProfit.toStringAsFixed(0)} 원',
              valueColor: profitColor
            ),
            _buildStatusRow(
              '평균 수익률:', 
              '${avgProfitRate.toStringAsFixed(2)} %',
              valueColor: profitColor
            ),
            _buildStatusRow(
              '평균 종료 분할수:', 
              avgTValue.toStringAsFixed(1),
            ),
            _buildStatusRow(
              '완료 포트폴리오 수:', 
              '$portfolioCount 개'
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
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
}