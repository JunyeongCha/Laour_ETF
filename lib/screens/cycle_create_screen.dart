// lib/screens/cycle_create_screen.dart

import 'package:flutter/material.dart';

class CycleCreateScreen extends StatelessWidget {
  const CycleCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 사이클 생성 (3단계)')),
      body: const Center(child: Text('3단계에서 만들 화면입니다.')),
    );
  }
}