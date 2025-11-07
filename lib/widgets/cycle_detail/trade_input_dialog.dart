// lib/widgets/cycle_detail/trade_input_dialog.dart (수정)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TradeInputDialog extends StatefulWidget {
  // (★수정★)
  // '준영매수법' 상세 화면에서 호출할 경우,
  // 'isJunyeongMode' 플래그를 true로 전달받습니다.
  final bool isJunyeongMode;

  const TradeInputDialog({super.key, this.isJunyeongMode = false});

  // static 함수로 팝업을 띄우고 결과를 반환
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    bool isJunyeongMode = false, // (★신규★)
  }) async {
    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => TradeInputDialog(
        isJunyeongMode: isJunyeongMode, // (★신규★)
      ),
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

  // (★신규★) '준영매수법' 전용 상태 변수
  // PDF(v3.0)  요구사항: 장기/단기 구분
  // 기본값은 'long' (Track A)
  String _trackType = 'long'; // 'long' (Track A) 또는 'short' (Track B)

  @override
  void initState() {
    super.initState();
    // '무매'(isJunyeongMode == false)일 때는 '장기'만 사용
    if (!widget.isJunyeongMode) {
      _trackType = 'long';
    }
  }

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
        // (★신규★) PDF(v3.0) [cite: 138] 요구사항: 플래그 반환
        // 'short' (Track B)이면 true, 'long' (Track A)이면 false
        'isShortTerm': _trackType == 'short',
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 16),

              // 매수/매도 선택
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'buy', label: Text('매수'), icon: Icon(Icons.add)),
                  ButtonSegment(
                      value: 'sell',
                      label: Text('매도'),
                      icon: Icon(Icons.remove)),
                ],
                selected: {_tradeType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _tradeType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // (★신규★) '준영매수법'일 때만 장기/단기 선택기 표시
              if (widget.isJunyeongMode) ...[
                const Text('어느 지갑에 반영할까요? ',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'long',
                        label: Text('장기 (Track A)'),
                        icon: Icon(Icons.all_inclusive)),
                    ButtonSegment(
                        value: 'short',
                        label: Text('단기 (Track B)'),
                        icon: Icon(Icons.fast_forward)),
                  ],
                  selected: {_trackType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _trackType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: '체결가 (원)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '가격을 입력하세요.';
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
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