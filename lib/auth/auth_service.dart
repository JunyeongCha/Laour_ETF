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

  // (★핵심 추가★) "다른 계정으로 로그인" 버그 해결용
  // 꼬여버린 로딩/에러 상태를 강제로 초기화합니다.
  void clearState() {
    _isLoading = false;
    _errorMessage = '';
    notifyListeners();
  }

  // (수정 없음) 로그인 로직
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError('');

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // 로그인 성공 시 _setLoading(false) 호출 안 함
      return true;
    } on FirebaseAuthException catch (e) {
      // 로그인 실패 시에만 _setLoading(false) 호출
      _setError('로그인 실패: ${e.message}');
      _setLoading(false);
      return false;
    }
  }

  // (수정 없음) 회원가입 로직
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

      // 3. '무조건 저장'
      await _storageService.saveAccount(email, password);
      
      // 회원가입 성공 시 _setLoading(false) 호출 안 함
      return true;

    } on FirebaseAuthException catch (e) {
      // 회원가입 실패 시에만 _setLoading(false) 호출
      _setError('회원가입 실패: ${e.message}');
      _setLoading(false);
      return false;
    }
  }

  // (수정 없음) 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }
}