// lib/widgets/cycle_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/screens/cycle_detail_screen.dart'; // 4단계 임시 화면

class CycleCard extends StatelessWidget {
  final QueryDocumentSnapshot cycleDoc;

  const CycleCard({super.key, required this.cycleDoc});

  // (★핵심★) 사이클 삭제 함수
  Future<void> _deleteCycle(BuildContext context) async {
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사이클 삭제'),
        content: const Text('이 사이클과 모든 거래 내역을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제')),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      try {
        // (★핵심★) Firestore에서 해당 문서 삭제 [cite: 158]
        // HomeScreen의 StreamBuilder가 이 변화를 감지하고 UI를 자동 새로고침합니다.
        await cycleDoc.reference.delete();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: ${e.toString()}'))
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = cycleDoc.data() as Map<String, dynamic>?;

    // (★주의★) 3/4단계에서 저장할 필드들입니다.
    final String name = data?['name'] ?? '이름 없음';
    final String nickname = data?['nickname'] ?? ''; // (닉네임 필드도 3단계에서 추가)
    final double avgPrice = (data?['avgPrice'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (data?['currentQuantity'] as num?)?.toInt() ?? 0;
    final double purchaseAmount = (data?['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
    final double totalSeed = (data?['totalSeed'] as num?)?.toDouble() ?? 1.0; // 0으로 나누기 방지
    
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (purchaseAmount / totalSeed) * 100;
    final bool isCompleted = (quantity == 0 && purchaseAmount > 0); // "규칙 1" [cite: 46]

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      // (★핵심★) 스와이프로 삭제 [cite: 158]
      child: Dismissible(
        key: Key(cycleDoc.id),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) {
          // 스와이프 즉시 삭제하지 않고, 확인 팝업을 띄웁니다.
          _deleteCycle(context);
        },
        confirmDismiss: (direction) async {
          // 스와이프 시 바로 삭제되지 않고, 팝업을 먼저 띄웁니다.
          final bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('사이클 삭제'),
              content: const Text('이 사이클과 모든 거래 내역을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제')),
              ],
            ),
          ) ?? false;
          
          if (confirm) {
             try {
                await cycleDoc.reference.delete();
                return true; // 삭제 성공
             } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: ${e.toString()}'))
                  );
                }
                return false; // 삭제 실패
             }
          }
          return false; // 삭제 취소
        },
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: InkWell(
          // (★핵심★) 카드 클릭 시 4단계 상세 화면으로 이동 [cite: 44]
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CycleDetailScreen(cycleId: cycleDoc.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이름 및 닉네임
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (nickname.isNotEmpty)
                  Text(nickname, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                
                // (★정산 완료 시★) [cite: 47]
                if (isCompleted)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '정산 완료',
                        style: TextStyle(fontSize: 16, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                      ),
                      // (TODO) 4단계 완료 후 'totalProfit' 등 필드를 가져와 여기에 표시
                      // Text('+12,000 원 (+10.5%)', style: TextStyle(color: Colors.green.shade700)),
                    ],
                  )
                // (★진행 중일 시★) 
                else
                  Column(
                    children: [
                      _buildInfoRow('평단가', '${avgPrice.toStringAsFixed(0)} 원'),
                      _buildInfoRow('보유 수량', '$quantity 주'),
                      _buildInfoRow('매입 금액', '${purchaseAmount.toStringAsFixed(0)} 원'),
                      const SizedBox(height: 8),
                      // 시드 소진율
                      LinearProgressIndicator(
                        value: seedUsagePercent / 100,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}