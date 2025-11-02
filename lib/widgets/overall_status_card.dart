// lib/widgets/overall_status_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverallStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const OverallStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    double totalSeed = 0;
    double totalPurchaseAmount = 0;
    double totalOngoingProfit = 0.0; // (★핵심 추가★)

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      totalSeed += (data['totalSeed'] as num?)?.toDouble() ?? 0.0;
      totalPurchaseAmount += (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;

      // (★핵심 추가★) [요청 1-b] 진행중 총 손익 계산
      final int currentQuantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
      
      // "진행중인" 사이클일 경우 (보유 수량이 0보다 클 때)
      if (currentQuantity > 0) {
        final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
        
        // (★핵심★) 3단계에서 저장한 'currentPrice'를 사용
        // (4단계에서 수동 업데이트 시 이 값도 변경되어야 함 - 4단계 수정 필요)
        final double currentPrice = (data['currentPrice'] as num?)?.toDouble() ?? 0.0; 

        if (avgPrice > 0 && currentPrice > 0) {
          totalOngoingProfit += (currentPrice - avgPrice) * currentQuantity;
        }
      }
    }

    final int portfolioCount = cycleDocs.length;
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (totalPurchaseAmount / totalSeed) * 100;
    
    // (★핵심 추가★) 손익 색상
    final Color profitColor = totalOngoingProfit >= 0 ? Colors.green.shade700 : Colors.red;

    return Card(
      elevation: 2.0,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('전체 진행 상황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatusRow('전체 시드', '${totalSeed.toStringAsFixed(0)} 원'),
            _buildStatusRow('총 매입 금액', '${totalPurchaseAmount.toStringAsFixed(0)} 원'),
            
            // (★핵심 추가★) [요청 1-b]
            _buildStatusRow(
              '진행중 총 손익:', 
              '${totalOngoingProfit.toStringAsFixed(0)} 원',
              valueColor: profitColor
            ),
            
            _buildStatusRow('포트폴리오 수', '$portfolioCount 개'),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '전체 시드 소진율:',
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

  // (★핵심 수정★) 헬퍼 함수가 valueColor를 받도록 수정
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
              color: valueColor ?? Colors.black, // 기본값은 검은색
            ),
          ),
        ],
      ),
    );
  }
}