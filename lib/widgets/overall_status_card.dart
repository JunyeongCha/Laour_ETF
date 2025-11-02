// lib/widgets/overall_status_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverallStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const OverallStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    // (★주의★)
    // 3단계에서 사이클을 생성할 때, Firestore에 'totalSeed'와 'currentPurchaseAmount'가
    // 숫자로 저장되어 있어야 이 코드가 작동합니다.
    double totalSeed = 0;
    double totalPurchaseAmount = 0;

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;

      // data가 null이 아니고, 'totalSeed' 필드가 존재하며, 숫자인지 확인
      totalSeed += (data?['totalSeed'] as num?)?.toDouble() ?? 0.0;
      // 'currentPurchaseAmount'도 동일하게 확인
      totalPurchaseAmount += (data?['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
    }

    final int portfolioCount = cycleDocs.length;
    // 0으로 나누기 방지
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (totalPurchaseAmount / totalSeed) * 100;

    return Card(
      elevation: 2.0,
      color: Colors.blue.shade50, // 이미지(Image 6)와 유사한 하늘색 배경
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('전체 진행 상황', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatusRow('전체 시드', '${totalSeed.toStringAsFixed(0)} 원'),
            _buildStatusRow('총 매입 금액', '${totalPurchaseAmount.toStringAsFixed(0)} 원'),
            _buildStatusRow('포트폴리오 수', '$portfolioCount 개'),
            const SizedBox(height: 12),
            // 전체 시드 소진율
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: seedUsagePercent / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${seedUsagePercent.toStringAsFixed(1)} %', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 간단한 Row 위젯 생성 헬퍼
  Widget _buildStatusRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}