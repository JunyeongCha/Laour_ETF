import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/screens/cycle_completed_screen.dart';
import 'package:laour_etf/screens/cycle_detail_screen.dart';

class CycleCard extends StatelessWidget {
  final QueryDocumentSnapshot cycleDoc;

  const CycleCard({super.key, required this.cycleDoc});

  // 삭제 로직
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
    final double purchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0; // "총 매수 금액"
    final double totalSeed = (data['totalSeed'] as num?)?.toDouble() ?? 1.0;
    
    final double realizedProfit = (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
    final double currentPrice = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;
    
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (purchaseAmount / totalSeed) * 100;
    
    // (★요청 4★) 수동 완료 플래그
    final bool isManuallyCompleted = (data['isManuallyCompleted'] as bool?) ?? false;
    final bool isCompleted = isManuallyCompleted || (quantity == 0 && purchaseAmount > 0); 

    // (★수정★) 정산 완료 시 수익/수익률 계산
    double finalProfitAmount = 0.0;
    double finalProfitRate = 0.0;
    
    if (isCompleted) {
      finalProfitAmount = realizedProfit; 
      finalProfitRate = (purchaseAmount == 0) ? 0.0 : (finalProfitAmount / purchaseAmount) * 100;
    }
    // (★요청 2★) 색상 변경: 수익=빨강, 손해=파랑
    final Color finalProfitColor = finalProfitAmount >= 0 ? Colors.red : Colors.blue.shade700;


    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Dismissible(
        key: Key(cycleDoc.id),
        direction: DismissDirection.endToStart,
        // 스와이프 시 팝업 로직
        confirmDismiss: (direction) async {
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
                
                if (isCompleted)
                  // "정산 완료" 시 UI
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '정산 완료',
                        style: TextStyle(fontSize: 16, color: finalProfitColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        '총 매수 금액:', 
                        '${purchaseAmount.toStringAsFixed(0)} 원',
                      ),
                      _buildInfoRow(
                        '최종 실현 수익:',
                        '${finalProfitAmount.toStringAsFixed(0)} 원', 
                        valueColor: finalProfitColor
                      ),
                      _buildInfoRow(
                        '최종 수익률:', 
                        '${finalProfitRate.toStringAsFixed(2)} %', 
                        valueColor: finalProfitColor
                      ),
                    ],
                  )
                else
                  // "진행 중" 시 UI
                  Column(
                    children: [
                      Builder( 
                        builder: (context) {
                          double currentProfitLoss = 0.0;
                          double currentProfitRate = 0.0;
                          
                          // (★요청 2★) 색상 변경: 수익=빨강, 손해=파랑
                          Color currentProfitColor = Colors.grey;
                          
                          if (avgPrice > 0 && currentPrice > 0 && quantity > 0) {
                            currentProfitLoss = (currentPrice - avgPrice) * quantity;
                            currentProfitRate = ((currentPrice / avgPrice) - 1) * 100;
                            currentProfitColor = currentProfitLoss >= 0 ? Colors.red : Colors.blue.shade700;
                          }

                          return Column(
                            children: [
                              _buildInfoRow('평단가:', '${avgPrice.toStringAsFixed(0)} 원'),
                              _buildInfoRow('보유 수량:', '$quantity 주'),
                              _buildInfoRow(
                                '현재 평가손익:', 
                                '${currentProfitLoss.toStringAsFixed(0)} 원',
                                valueColor: currentProfitColor,
                              ),
                              _buildInfoRow(
                                '현재 수익률:', 
                                '${currentProfitRate.toStringAsFixed(2)} %',
                                valueColor: currentProfitColor,
                              ),
                            ],
                          );
                        },
                      ),
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

  // UI 헬퍼
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