// // lib/screens/name_change_screen.dart (신규 파일)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NameChangeScreen extends StatefulWidget {
  const NameChangeScreen({super.key});

  @override
  State<NameChangeScreen> createState() => _NameChangeScreenState();
}

class _NameChangeScreenState extends State<NameChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = true;
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  // 1. 현재 유저의 ID를 가져오고, 저장된 이름을 불러옴
  Future<void> _loadCurrentName() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
          
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
      }
    }
    setState(() { _isLoading = false; });
  }
  
  // 2. 새 이름 저장
  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid.isEmpty) return;
    
    setState(() { _isLoading = true; });

    try {
      final String newName = _nameController.text.trim();
      
      // 'users' 문서에 'name' 필드를 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .set(
            { 'name': newName },
            SetOptions(merge: true), // 기존 email, targetProfit 필드는 유지
          );
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름이 변경되었습니다.')),
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
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이름 변경'),
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '새 이름',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이름을 입력하세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveName,
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