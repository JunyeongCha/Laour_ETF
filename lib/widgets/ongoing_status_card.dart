import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OngoingStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const OngoingStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    double totalSeed = 0;
    double totalPurchaseAmount = 0;
    double totalOngoingProfit = 0.0;

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      totalSeed += (data['totalSeed'] as num?)?.toDouble() ?? 0.0;
      totalPurchaseAmount += (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;

      final int currentQuantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
      if (currentQuantity > 0) {
        final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
        final double currentPrice = (data['currentPrice'] as num?)?.toDouble() ?? 0.0; 

        if (avgPrice > 0 && currentPrice > 0) {
          totalOngoingProfit += (currentPrice - avgPrice) * currentQuantity;
        }
      }
    }

    final int portfolioCount = cycleDocs.length;
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (totalPurchaseAmount / totalSeed) * 100;
    
    final double totalOngoingProfitRate = (totalPurchaseAmount == 0) 
        ? 0.0 
        : (totalOngoingProfit / totalPurchaseAmount) * 100;
    
    // (★요청 2★) 색상 변경: 수익=빨강, 손해=파랑
    final Color profitColor = totalOngoingProfit >= 0 ? Colors.red : Colors.blue.shade700;

    return Card(
      elevation: 2.0,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusRow('진행중 시드', '${totalSeed.toStringAsFixed(0)} 원'),
            _buildStatusRow('진행중 매입금액', '${totalPurchaseAmount.toStringAsFixed(0)} 원'),
            _buildStatusRow(
              '진행중 총 손익:', 
              '${totalOngoingProfit.toStringAsFixed(0)} 원',
              valueColor: profitColor
            ),
            _buildStatusRow(
              '진행중 총 손익률:', 
              '${totalOngoingProfitRate.toStringAsFixed(2)} %',
              valueColor: profitColor
            ),
            _buildStatusRow('진행중 포트폴리오 수', '$portfolioCount 개'),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '진행중 시드 소진율:',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                Text(
                  '${seedUsagePercent.toStringAsFixed(1)} %', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: seedUsagePercent / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
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