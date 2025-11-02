// lib/widgets/cycle_list_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/widgets/cycle_card.dart';

class CycleListView extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const CycleListView({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    // (★핵심★) "규칙 1" 적용
    // 1. '진행 중'과 '정산 완료' 리스트를 분리
    // 4단계에서 cycle 문서에 'currentQuantity' (보유 수량)와
    // 'totalPurchaseAmount' (총 매입 금액)이 숫자로 저장되어야 합니다.
    
    final List<QueryDocumentSnapshot> ongoingCycles = [];
    final List<QueryDocumentSnapshot> completedCycles = [];

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final int quantity = (data?['currentQuantity'] as num?)?.toInt() ?? 0;
      final double purchaseAmount = (data?['totalPurchaseAmount'] as num?)?.toDouble() ?? 0.0;

      // "보유하다가 0이 되었을때" = 보유량 0 + '하지만 매입 이력은 있을 때'
      if (quantity == 0 && purchaseAmount > 0) {
        completedCycles.add(doc);
      } else {
        // 보유량이 0이고 매입 이력도 0인 (방금 생성한) 사이클,
        // 또는 보유량이 1 이상인 사이클
        ongoingCycles.add(doc);
      }
    }

    // 2. 두 리스트를 합침 (진행 중 -> 완료 순)
    final List<QueryDocumentSnapshot> sortedCycles = [
      ...ongoingCycles,
      ...completedCycles,
    ];

    return ListView.builder(
      itemCount: sortedCycles.length,
      itemBuilder: (context, index) {
        final cycleDoc = sortedCycles[index];
        // 3. CycleCard 위젯으로 개별 항목 표시
        return CycleCard(cycleDoc: cycleDoc);
      },
    );
  }
}