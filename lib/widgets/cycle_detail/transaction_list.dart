// lib/widgets/cycle_detail/transaction_list.dart (★수정 완료★)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionList extends StatelessWidget {
  final Stream<QuerySnapshot> transactionStream;
  
  // (★수정★) "준영매수법"인지 확인하는 플래그
  final bool isJunyeongMode; 

  // (★수정★) onDelete 콜백의 시그니처를 6개 인자(bool isShortTerm)로 변경
  final Function(String transactionId, String type, int quantity, DateTime date,
      double price, bool isShortTerm) onDelete; //

  const TransactionList({
    super.key,
    required this.transactionStream,
    required this.onDelete,
    this.isJunyeongMode = false, // (★신규★) 기본값은 false
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: transactionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('아직 거래 내역이 없습니다.'));
        }

        final transactions = snapshot.data!.docs;

        return ListView.builder(
          itemCount: transactions.length,
          shrinkWrap: true, // ScrollView 안에 있으므로
          physics: const NeverScrollableScrollPhysics(), // ScrollView 안에 있으므로
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;

            final DateTime date = (data['date'] as Timestamp).toDate();
            final String type = data['type'] == 'buy' ? '매수' : '매도';
            final Color typeColor =
                data['type'] == 'buy' ? Colors.red.shade700 : Colors.blue.shade700;
            final double price = (data['price'] as num).toDouble();
            final int quantity = (data['quantity'] as num).toInt();
            
            // (★신규★) isShortTerm 값 읽기
            final bool isShortTerm = (data['isShortTerm'] as bool?) ?? false;

            // (★신규★) "준영매수법"일 때만 태그 표시
            String title = '${DateFormat('yyyy-MM-dd').format(date)} - $type';
            if (isJunyeongMode) {
              title += isShortTerm ? ' (단기 B)' : ' (장기 A)';
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(
                  title, // (★수정★)
                  style:
                      TextStyle(color: typeColor, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${price.toStringAsFixed(0)}원 X $quantity주'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                  onPressed: () async {
                    final bool confirmDelete = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('거래 삭제'),
                            content: const Text('이 거래 내역을 삭제하시겠습니까?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('취소')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('삭제')),
                            ],
                          ),
                        ) ??
                        false;

                    if (confirmDelete) {
                      // (★수정★) 6개 인자(isShortTerm)를 모두 전달
                      onDelete(doc.id, data['type'], quantity, date, price,
                          isShortTerm);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}