// lib/widgets/cycle_detail/transaction_list.dart (★"롤오버 메시지" 추가★)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionList extends StatelessWidget {
  final Stream<QuerySnapshot> transactionStream;
  
  final bool isJunyeongMode; 

  final Function(String transactionId, String type, int quantity, DateTime date,
      double price, bool isShortTerm) onDelete; 

  const TransactionList({
    super.key,
    required this.transactionStream,
    required this.onDelete,
    this.isJunyeongMode = false, 
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
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), 
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;

            final DateTime date = (data['date'] as Timestamp).toDate();
            final String type = data['type'] == 'buy' ? '매수' : '매도';
            final Color typeColor =
                data['type'] == 'buy' ? Colors.red.shade700 : Colors.blue.shade700;
            final double price = (data['price'] as num).toDouble();
            final int quantity = (data['quantity'] as num).toInt();
            
            final bool isShortTerm = (data['isShortTerm'] as bool?) ?? false;
            
            // (★신규★) 롤오버 깃발(Tag) 읽기
            final bool wasRolledOver = (data['wasRolledOver'] as bool?) ?? false;

            String title = '${DateFormat('yyyy-MM-dd').format(date)} - $type';
            if (isJunyeongMode) {
              // (★수정★) 롤오버 깃발이 true이면, (장기 A) 태그 강제
              title += (isShortTerm && !wasRolledOver) ? ' (단기 B)' : ' (장기 A)';
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(
                  title, 
                  style:
                      TextStyle(color: typeColor, fontWeight: FontWeight.bold),
                ),
                
                // (★수정★) Subtitle을 Column으로 변경
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${price.toStringAsFixed(0)}원 X $quantity주'),
                    
                    // (★신규★) 롤오버 메시지 표시
                    if (wasRolledOver)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          "└ (단기 B -> 장기 A 롤오버됨)",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

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
                      // (★수정 없음★)
                      // 삭제 로직은 현재 상태(isShortTerm)를 기반으로 하므로
                      // 롤오버 여부와 관계없이 정확하게 동작합니다.
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