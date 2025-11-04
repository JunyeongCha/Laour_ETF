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
      
      // (★핵심 버그 수정★) 회원가입 성공 시 로딩 상태 'false'로 변경
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      _setError('회원가입 실패: ${e.message}');
      _setLoading(false);
      return false;
    }
  }

  // (★신규★) 비밀번호 변경 함수
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _setLoading(true);
    _setError('');

    try {
      final User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw FirebaseAuthException(code: 'no-user', message: '로그인된 사용자가 없습니다.');
      }
      
      final String email = user.email!;
      
      // 1. 재인증 (현재 비밀번호 확인)
      AuthCredential credential = EmailAuthProvider.credential(
        email: email, 
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      
      // 2. Firebase Auth 비밀번호 변경
      await user.updatePassword(newPassword);
      
      // 3. (★핵심★) 계정선택창(SecureStorage)에도 새 비밀번호 반영
      await _storageService.saveAccount(email, newPassword);
      
      _setLoading(false);
      return true;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _setError('현재 비밀번호가 일치하지 않습니다.');
      } else {
        _setError('비밀번호 변경 실패: ${e.message}');
      }
      _setLoading(false);
      return false;
    }
  }

  // 로그아웃 (변경 없음)
  Future<void> signOut() async {
    await _auth.signOut();
  }
}