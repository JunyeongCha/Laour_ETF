// lib/screens/cycle_detail_screen.dart

import 'package:flutter/material.dart';

class CycleDetailScreen extends StatelessWidget {
  // 4단계에서 cycleId를 받아올 것입니다.
  final String cycleId;
  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사이클 상세 (4단계)')),
      body: Center(child: Text('4단계에서 만들 화면입니다.\nCycle ID: $cycleId')),
    );
  }
}