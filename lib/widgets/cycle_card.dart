import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/screens/cycle_completed_screen.dart';
import 'package:laour_etf/screens/cycle_detail_screen.dart';
// (★신규★) 준영매수법 상세 화면 임포트
import 'package:laour_etf/screens/junyeong_detail_screen.dart';
import 'package:provider/provider.dart'; 
import 'package:laour_etf/providers/theme_provider.dart'; 

class CycleCard extends StatelessWidget {
  final QueryDocumentSnapshot cycleDoc;

  const CycleCard({super.key, required this.cycleDoc});

  // (주석) 삭제 로직은 기존과 동일하므로 생략 (파일에는 포함됨)
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
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey.shade600;

    final data = cycleDoc.data() as Map<String, dynamic>;

    final String name = data['name'] ?? '이름 없음';
    final String nickname = data['nickname'] ?? '';
    final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
    final double purchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0; 
    final double totalSeed = (data['totalSeed'] as num?)?.toDouble() ?? 1.0;
    
    final double targetProfitRate = (data['targetProfitRate'] as num?)?.toDouble() ?? 0.0;
    
    final double realizedProfit = (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
    final double currentPrice = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;
    
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (purchaseAmount / totalSeed) * 100;
    
    final bool isManuallyCompleted = (data['isManuallyCompleted'] as bool?) ?? false;
    final bool isCompleted = isManuallyCompleted || (quantity == 0 && purchaseAmount > 0); 
    
    // (★신규★) 사이클 타입 식별 (기존 데이터는 'mumae'로 간주)
    final String cycleType = data['type'] ?? 'mumae';

    double finalProfitAmount = 0.0;
    double finalProfitRate = 0.0;
    
    if (isCompleted) {
      finalProfitAmount = realizedProfit; 
      finalProfitRate = (purchaseAmount == 0) ? 0.0 : (finalProfitAmount / purchaseAmount) * 100;
    }
    final Color finalProfitColor = finalProfitAmount >= 0 ? Colors.red : Colors.blue.shade700;


    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Dismissible(
        key: Key(cycleDoc.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          // (주석) 삭제 확인 로직 (기존과 동일)
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
            // (★수정★) 'onTap' 분기 로직
            if (isCompleted) {
              // 정산 완료 시: (기존과 동일)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CycleCompletedScreen(cycleData: data),
                ),
              );
            } else {
              // 진행 중일 시: (★신규★) type에 따라 분기
              if (cycleType == 'junyeong') {
                // "준영" 사이클
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JunyeongDetailScreen(cycleId: cycleDoc.id),
                  ),
                );
              } else {
                // "무매" 사이클 (기존)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CycleDetailScreen(cycleId: cycleDoc.id),
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row( // (★신규★) 이름 옆에 타입 배지 표시
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: textColor, 
                      ),
                    ),
                    // (★신규★) 타입 배지
                    if (cycleType == 'junyeong')
                      Chip(
                        label: const Text('준영'),
                        backgroundColor: Colors.blue.shade100,
                        labelStyle: TextStyle(color: Colors.blue.shade900, fontSize: 10),
                        padding: const EdgeInsets.all(0),
                      )
                    else 
                      Chip(
                        label: const Text('무매'),
                        backgroundColor: Colors.grey.shade200,
                        labelStyle: TextStyle(color: Colors.grey.shade800, fontSize: 10),
                        padding: const EdgeInsets.all(0),
                      )
                  ],
                ),
                if (nickname.isNotEmpty)
                  Text(
                    nickname, 
                    style: TextStyle(color: subTextColor), 
                  ),
                const SizedBox(height: 12),
                
                if (isCompleted)
                  // "정산 완료" 시 UI (기존과 동일)
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
                        textColor: textColor, 
                        subTextColor: subTextColor, 
                      ),
                      _buildInfoRow(
                        '최종 실현 수익:',
                        '${finalProfitAmount.toStringAsFixed(0)} 원', 
                        valueColor: finalProfitColor,
                        textColor: textColor, 
                        subTextColor: subTextColor
                      ),
                      _buildInfoRow(
                        '최종 수익률:', 
                        '${finalProfitRate.toStringAsFixed(2)} %', 
                        valueColor: finalProfitColor,
                        textColor: textColor, 
                        subTextColor: subTextColor
                      ),
                    ],
                  )
                else
                  // "진행 중" 시 UI (기존과 동일)
                  Column(
                    children: [
                      Builder( 
                        builder: (context) {
                          double currentProfitLoss = 0.0;
                          double currentProfitRate = 0.0;
                          Color currentProfitColor = Colors.grey;
                          
                          if (avgPrice > 0 && currentPrice > 0 && quantity > 0) {
                            currentProfitLoss = (currentPrice - avgPrice) * quantity;
                            currentProfitRate = ((currentPrice / avgPrice) - 1) * 100;
                            currentProfitColor = currentProfitLoss >= 0 ? Colors.red : Colors.blue.shade700;
                          }
                          
                          double achievementRate = (targetProfitRate == 0 || currentProfitRate < 0) 
                              ? 0 
                              : (currentProfitRate / targetProfitRate);
                          achievementRate = achievementRate.clamp(0.0, 1.0); 

                          return Column(
                            children: [
                              _buildInfoRow(
                                '평단가:', 
                                '${avgPrice.toStringAsFixed(0)} 원',
                                textColor: textColor, 
                                subTextColor: subTextColor, 
                              ),
                              _buildInfoRow(
                                '보유 수량:', 
                                '$quantity 주',
                                textColor: textColor, 
                                subTextColor: subTextColor, 
                              ),
                              _buildInfoRow(
                                '현재 평가손익:', 
                                '${currentProfitLoss.toStringAsFixed(0)} 원',
                                valueColor: currentProfitColor,
                                textColor: textColor, 
                                subTextColor: subTextColor
                              ),
                              _buildInfoRow(
                                '현재 수익률:', 
                                '${currentProfitRate.toStringAsFixed(2)} %',
                                valueColor: currentProfitColor,
                                textColor: textColor, 
                                subTextColor: subTextColor
                              ),
                              
                              const Divider(height: 16),
                              _buildInfoRow(
                                '목표 수익률:', 
                                '${targetProfitRate.toStringAsFixed(1)} %',
                                textColor: textColor, 
                                subTextColor: subTextColor
                              ),
                              _buildInfoRow(
                                '달성률:',
                                '${(achievementRate * 100).toStringAsFixed(1)} %',
                                textColor: textColor, 
                                subTextColor: subTextColor
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 4, 0, 4), 
                                child: LinearProgressIndicator(
                                  value: achievementRate,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                  backgroundColor: Colors.grey.shade300,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          );
                        },
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

  Widget _buildInfoRow(String title, String value, {Color? valueColor, required Color textColor, required Color subTextColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: subTextColor)),
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? textColor,
          )
        ),
      ],
    );
  }
}