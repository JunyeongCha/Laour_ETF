// // lib/screens/target_setting_screen.dart (신규 파일)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 숫자만 입력받기 위해

class TargetSettingScreen extends StatefulWidget {
  const TargetSettingScreen({super.key});

  @override
  State<TargetSettingScreen> createState() => _TargetSettingScreenState();
}

class _TargetSettingScreenState extends State<TargetSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  bool _isLoading = true;
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentTarget();
  }

  // 1. 현재 유저의 ID를 가져오고, 저장된 목표 금액이 있으면 불러옴
  Future<void> _loadCurrentTarget() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
          
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        final double currentTarget = (data['targetProfit'] as num?)?.toDouble() ?? 0.0;
        _targetController.text = currentTarget.toStringAsFixed(0);
      }
    }
    setState(() { _isLoading = false; });
  }
  
  // 2. 새 목표 금액 저장
  Future<void> _saveTarget() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid.isEmpty) return;
    
    setState(() { _isLoading = true; });

    try {
      final double newTarget = double.tryParse(_targetController.text) ?? 0.0;
      
      // 'users' 문서에 'targetProfit' 필드를 생성/업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set(
            { 'targetProfit': newTarget },
            SetOptions(merge: true), // 기존 name, email 필드는 유지
          );
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목표 금액이 저장되었습니다.')),
        );
        Navigator.pop(context); // 마이페이지로 복귀
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${e.toString()}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('목표 금액 설정'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _targetController,
                      decoration: const InputDecoration(
                        labelText: '목표 누적 수익 금액 (원)',
                        helperText: '앱 전체에서 달성하고 싶은 총 수익 목표입니다.',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '금액을 입력하세요.';
                        }
                        if (double.tryParse(value) == null) {
                          return '유효한 숫자를 입력하세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveTarget,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('저장하기'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}