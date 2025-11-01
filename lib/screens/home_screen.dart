// lib/screens/home_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laour_etf/auth/auth_service.dart'; // (★추가★)
import 'package:provider/provider.dart'; // (★추가★)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  // (★수정★) 팝업 로직 완전 제거, 이름만 불러오기
  void _loadUserName() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not found");

      final DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists && mounted) {
        setState(() {
          _userName = userData.get('name');
        });
      } else {
        // Firestore에 문서가 없으면 임시 이름
        setState(() {
          _userName = user.email?.split('@').first ?? "사용자";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = "사용자 (로드 실패)";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈 화면'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // (★수정★) 템플릿처럼 AuthService를 통해 로그아웃
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: _userName == null
            ? const CircularProgressIndicator()
            : Text(
                '$_userName님 안녕하세요!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
      ),
    );
  }
}