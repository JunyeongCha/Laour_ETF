import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/widgets/cycle_card.dart';

class CycleListView extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const CycleListView({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    
    // (★요청 2★)
    // 홈 스크린의 ListView 내부에 있으므로, 
    // shrinkWrap과 physics를 설정해야 합니다.
    return ListView.builder(
      itemCount: cycleDocs.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final cycleDoc = cycleDocs[index];
        return CycleCard(cycleDoc: cycleDoc);
      },
    );
  }
}