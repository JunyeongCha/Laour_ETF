// lib/widgets/cycle_detail/transaction_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionList extends StatelessWidget {
  // (★핵심★)
  // 메인 문서 스트림이 아니라, '하위 컬렉션'인 transactions의 스트림을 받습니다.
  final Stream<QuerySnapshot> transactionStream;
  
  // (★핵심★)
  // 삭제 버튼을 눌렀을 때, 4-5의 '핵심 계산' 로직을 재실행할 함수를 받습니다.
  final Function(String transactionId) onDelete;

  const TransactionList({
    super.key, 
    required this.transactionStream,
    required this.onDelete,
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
            final Color typeColor = data['type'] == 'buy' ? Colors.red : Colors.blue;
            final double price = (data['price'] as num).toDouble();
            final int quantity = (data['quantity'] as num).toInt();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(
                  '${DateFormat('yyyy-MM-dd').format(date)} - $type',
                  style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${price.toStringAsFixed(0)}원 X $quantity주'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                  // (★핵심★) 규칙 6: 삭제 버튼 
                  onPressed: () async {
                    // (규칙 6) 삭제 확인 팝업
                    final bool confirmDelete = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('거래 삭제'),
                        content: const Text('이 거래 내역을 삭제하시겠습니까?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제')),
                        ],
                      ),
                    ) ?? false;

                    if (confirmDelete) {
                      // 4-5의 _onTradeDeleted 함수를 호출
                      onDelete(doc.id); 
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