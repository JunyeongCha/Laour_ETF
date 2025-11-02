// lib/widgets/cycle_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/screens/cycle_completed_screen.dart'; // (★핵심 추가★)
import 'package:laour_etf/screens/cycle_detail_screen.dart';

class CycleCard extends StatelessWidget {
  final QueryDocumentSnapshot cycleDoc;

  const CycleCard({super.key, required this.cycleDoc});

  Future<void> _deleteCycle(BuildContext context) async {
    // ... (이전과 동일) ...
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
    final data = cycleDoc.data() as Map<String, dynamic>;

    final String name = data['name'] ?? '이름 없음';
    final String nickname = data['nickname'] ?? '';
    final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
    final double purchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
    final double totalSeed = (data['totalSeed'] as num?)?.toDouble() ?? 1.0;
    
    // (★핵심★) Step A에서 저장한 'totalSellAmount' 필드를 가져옴
    final double totalSellAmount = (data['totalSellAmount'] as num?)?.toDouble() ?? 0.0;
    
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (purchaseAmount / totalSeed) * 100;
    final bool isCompleted = (quantity == 0 && purchaseAmount > 0); // "규칙 1"

    // (★핵심★) [요청 3] 정산 완료 시 수익/수익률 계산
    double finalProfitAmount = 0.0;
    double finalProfitRate = 0.0;
    if (isCompleted) {
      finalProfitAmount = totalSellAmount - purchaseAmount;
      finalProfitRate = (purchaseAmount == 0) ? 0.0 : (finalProfitAmount / purchaseAmount) * 100;
    }
    final Color profitColor = finalProfitAmount >= 0 ? Colors.green.shade700 : Colors.red;


    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Dismissible(
        key: Key(cycleDoc.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          // (스와이프 시 팝업 로직 - 이전과 동일)
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
                return true;
             } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: ${e.toString()}'))
                  );
                }
                return false;
             }
          }
          return false;
        },
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: InkWell(
          // (★핵심 수정★) [요청 2]
          onTap: () {
            if (isCompleted) {
              // 1. 정산 완료 시 -> "정산 완료 페이지"로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CycleCompletedScreen(cycleData: data),
                ),
              );
            } else {
              // 2. 진행 중일 시 -> "상세 페이지"로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CycleDetailScreen(cycleId: cycleDoc.id),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (nickname.isNotEmpty)
                  Text(nickname, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                
                // (★핵심 수정★) [요청 3]
                if (isCompleted)
                  // "정산 완료" 시 UI
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '정산 완료',
                        style: TextStyle(fontSize: 16, color: profitColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        '최종 수익:', 
                        '${finalProfitAmount.toStringAsFixed(0)} 원', 
                        valueColor: profitColor
                      ),
                      _buildInfoRow(
                        '최종 수익률:', 
                        '${finalProfitRate.toStringAsFixed(2)} %', 
                        valueColor: profitColor
                      ),
                    ],
                  )
                else
                  // "진행 중" 시 UI (이전과 동일)
                  Column(
                    children: [
                      _buildInfoRow('평단가:', '${avgPrice.toStringAsFixed(0)} 원'),
                      _buildInfoRow('보유 수량:', '$quantity 주'),
                      _buildInfoRow('매입 금액:', '${purchaseAmount.toStringAsFixed(0)} 원'),
                      const SizedBox(height: 8),
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

  Widget _buildInfoRow(String title, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600)),
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black
          )
        ),
      ],
    );
  }
}