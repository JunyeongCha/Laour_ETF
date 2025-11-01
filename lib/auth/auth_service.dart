// lib/auth/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/auth/secure_storage_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SecureStorageService _storageService = SecureStorageService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // (★핵심 수정★) 로그인 로직
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError('');

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // (★핵심 수정★)
      // 로그인 '성공' 시 _setLoading(false)를 호출하지 않습니다!
      // AuthWrapper가 화면을 전환할 것이므로 UI를 건드리지 않습니다.
      return true; // 성공

    } on FirebaseAuthException catch (e) {
      // (★핵심 수정★)
      // 로그인 '실패' 시에만 _setLoading(false)를 호출합니다.
      _setError('로그인 실패: ${e.message}');
      _setLoading(false);
      return false; // 실패
    }
  }

  // (★핵심 수정★) 회원가입 로직
  Future<bool> signUp(BuildContext context, String name, String email, String password) async {
    _setLoading(true);
    _setError('');

    try {
      // 1. Auth 가입
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Firestore 저장
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'uid': userCredential.user!.uid,
      });

      // 3. (★핵심 수정★) "아니요" 옵션 삭제 -> '무조건 저장'
      await _storageService.saveAccount(email, password);
      
      // 4. (★핵심 수정★)
      // 회원가입 '성공' 시 _setLoading(false)를 호출하지 않습니다!
      // SignupScreen이 스택을 리셋할 것입니다.
      return true; // 성공

    } on FirebaseAuthException catch (e) {
      // (★핵심 수정★)
      // 회원가입 '실패' 시에만 _setLoading(false)를 호출합니다.
      _setError('회원가입 실패: ${e.message}');
      _setLoading(false);
      return false; // 실패
    }
  }

  // (수정 없음)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // (★핵심 수정★)
  // 팝업 로직이 더 이상 필요 없으므로 함수를 '삭제'합니다.
  // Future<bool> _showSaveAccountDialog(...) { ... }
}