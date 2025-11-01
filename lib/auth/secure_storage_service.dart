// lib/auth/secure_storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();
  final String _keyAccounts = 'laour_accounts';

  Future<Map<String, String>> _readAllAccounts() async {
    try {
      final String? accountsJson = await _storage.read(key: _keyAccounts);
      if (accountsJson != null && accountsJson.isNotEmpty) {
        final Map<String, dynamic> decodedMap = jsonDecode(accountsJson);
        return decodedMap.map((key, value) => MapEntry(key, value.toString()));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<void> saveAccount(String email, String password) async {
    final Map<String, String> accounts = await _readAllAccounts();
    accounts[email] = password;
    final String accountsJson = jsonEncode(accounts);
    await _storage.write(key: _keyAccounts, value: accountsJson);
  }

  Future<String?> readPassword(String email) async {
    final Map<String, String> accounts = await _readAllAccounts();
    return accounts[email];
  }

  Future<List<String>> readAllAccountEmails() async {
    final Map<String, String> accounts = await _readAllAccounts();
    return accounts.keys.toList();
  }

  // (★핵심★) 삭제 함수
  Future<void> deleteAccount(String email) async {
    final Map<String, String> accounts = await _readAllAccounts();
    accounts.remove(email); // 맵에서 해당 이메일 제거
    final String accountsJson = jsonEncode(accounts);
    await _storage.write(key: _keyAccounts, value: accountsJson); // 덮어쓰기
  }
}