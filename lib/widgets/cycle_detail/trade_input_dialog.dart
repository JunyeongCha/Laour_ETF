// lib/widgets/cycle_detail/trade_input_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 포맷을 위해 pubspec.yaml에 'intl' 추가 필요

class TradeInputDialog extends StatefulWidget {
  // 생성자가 아니라, static 함수로 팝업을 띄우고 결과를 반환하게 합니다.
  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => TradeInputDialog(),
    );
  }

  @override
  _TradeInputDialogState createState() => _TradeInputDialogState();
}

class _TradeInputDialogState extends State<TradeInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _tradeType = 'buy'; // 'buy' 또는 'sell'

  // 날짜 선택기
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // 폼 제출
  void _submit() {
    if (_formKey.currentState!.validate()) {
      final double price = double.tryParse(_priceController.text) ?? 0.0;
      final int quantity = int.tryParse(_quantityController.text) ?? 0;

      // 맵 형태로 결과 반환
      Navigator.of(context).pop({
        'date': _selectedDate,
        'price': price,
        'quantity': quantity,
        'type': _tradeType,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('거래 내역 입력'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 날짜 선택기
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('날짜: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(context),
                  ),
                ],
              ),
              // 매수/매도 선택
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'buy', label: Text('매수'), icon: Icon(Icons.add)),
                  ButtonSegment(value: 'sell', label: Text('매도'), icon: Icon(Icons.remove)),
                ],
                selected: {_tradeType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _tradeType = newSelection.first;
                  });
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: '체결가 (원)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '가격을 입력하세요.';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '유효한 가격을 입력하세요.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: '수량 (주)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '수량을 입력하세요.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '유효한 수량을 입력하세요.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}