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

  // 꼬여버린 로딩/에러 상태를 강제로 초기화합니다.
  void clearState() {
    _isLoading = false;
    _errorMessage = '';
    notifyListeners();
  }

  // (★핵심 수정★) 
  // 로그인 성공 시에도 _setLoading(false)를 호출하도록 수정
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError('');

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // (★핵심 버그 수정★)
      // 로그인 성공 시 로딩 상태를 'false'로 되돌립니다.
      // 이것이 없으면 isLoading이 true로 고정되어 무한루프(Stuck) 발생
      _setLoading(false); 
      return true;
      
    } on FirebaseAuthException catch (e) {
      _setError('로그인 실패: ${e.message}');
      _setLoading(false);
      return false;
    }
  }

  // 회원가입 로직 (이전 단계에서 수정 완료됨)
  Future<bool> signUp(BuildContext context, String name, String email, String password) async {
    _setLoading(true);
    _setError('');

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'uid': userCredential.user!.uid,
      });

      // 회원가입 시에는 "무조건 저장"
      await _storageService.saveAccount(email, password);
      
      // 회원가입 성공 시 로딩 상태 'false'로 변경
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      _setError('회원가입 실패: ${e.message}');
      _setLoading(false);
      return false;
    }
  }

  // 로그아웃 (변경 없음)
  Future<void> signOut() async {
    await _auth.signOut();
  }
}