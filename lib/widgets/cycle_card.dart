// lib/widgets/cycle_card.dart (★수정 완료★)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:laour_etf/screens/cycle_completed_screen.dart';
import 'package:laour_etf/screens/cycle_detail_screen.dart';
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
            content: const Text(
                '이 사이클과 모든 거래 내역을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('삭제')),
            ],
          ),
        ) ??
        false;

    if (confirmDelete) {
      try {
        await cycleDoc.reference.delete();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('삭제 실패: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor =
        isDarkMode ? Colors.white70 : Colors.grey.shade600;

    final data = cycleDoc.data() as Map<String, dynamic>;

    // (★핵심 수정★) 1. 사이클 타입 식별
    final String cycleType = data['type'] ?? 'mumae';

    // (★핵심 수정★) 2. 타입에 따른 데이터 분기 처리
    final String name = data['name'] ?? '이름 없음';
    final String nickname = data['nickname'] ?? '';
    final double totalSeed = (data['totalSeed'] as num?)?.toDouble() ?? 1.0;
    final double targetProfitRate =
        (data['targetProfitRate'] as num?)?.toDouble() ?? 0.0;
    final double currentPrice =
        (data['currentPrice'] as num?)?.toDouble() ?? 0.0;

    // 표시할 변수 초기화
    double displayAvgPrice = 0.0;
    int displayQuantity = 0;
    double displayPurchaseAmount = 0.0;
    double displayRealizedProfit = 0.0;
    bool isManuallyCompleted = (data['isManuallyCompleted'] as bool?) ?? false;

    if (cycleType == 'junyeong') {
      // "준영" 사이클: A/B 데이터 합산 또는 A 데이터 사용
      displayAvgPrice =
          (data['avgPrice_A'] as num?)?.toDouble() ?? 0.0; // 장기(A) 평단가를 대표로 표시
      displayQuantity = ((data['currentQuantity_A'] as num?)?.toInt() ?? 0) +
          ((data['currentQuantity_B'] as num?)?.toInt() ?? 0); // A+B 수량 합산
      displayPurchaseAmount =
          ((data['currentPurchaseAmount_A'] as num?)?.toDouble() ?? 0.0) +
              ((data['currentPurchaseAmount_B'] as num?)?.toDouble() ??
                  0.0); // A+B 매수금액 합산
      displayRealizedProfit =
          ((data['realizedProfit_A'] as num?)?.toDouble() ?? 0.0) +
              ((data['realizedProfit_B'] as num?)?.toDouble() ??
                  0.0); // A+B 실현손익 합산
    } else {
      // "무매" 사이클: 기존 데이터 사용
      displayAvgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
      displayQuantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
      displayPurchaseAmount =
          (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
      displayRealizedProfit =
          (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
    }

    // (★수정★) home_screen과 동일한 정산 완료 로직
    final bool isCompleted =
        isManuallyCompleted || (displayQuantity == 0 && displayPurchaseAmount > 0);

    double finalProfitAmount = 0.0;
    double finalProfitRate = 0.0;

    if (isCompleted) {
      finalProfitAmount = displayRealizedProfit;
      finalProfitRate = (displayPurchaseAmount == 0)
          ? 0.0
          : (finalProfitAmount / displayPurchaseAmount) * 100;
    }
    final Color finalProfitColor =
        finalProfitAmount >= 0 ? Colors.red : Colors.blue.shade700;

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
                  content: const Text(
                      '이 사이클과 모든 거래 내역을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('취소')),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('삭제')),
                  ],
                ),
              ) ??
              false;

          if (confirm) {
            try {
              await cycleDoc.reference.delete();
              return true;
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: ${e.toString()}')));
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
              // 정산 완료 시: (★수정★) cycleData에 data(모든 필드)를 전달
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CycleCompletedScreen(cycleData: data),
                ),
              );
            } else {
              // 진행 중일 시: type에 따라 분기
              if (cycleType == 'junyeong') {
                // "준영" 사이클
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        JunyeongDetailScreen(cycleId: cycleDoc.id),
                  ),
                );
              } else {
                // "무매" 사이클 (기존)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CycleDetailScreen(cycleId: cycleDoc.id),
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
                Row(
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
                    // 타입 배지
                    if (cycleType == 'junyeong')
                      Chip(
                        label: const Text('준영'),
                        backgroundColor: Colors.blue.shade100,
                        labelStyle: TextStyle(
                            color: Colors.blue.shade900, fontSize: 10),
                        padding: const EdgeInsets.all(0),
                      )
                    else
                      Chip(
                        label: const Text('무매'),
                        backgroundColor: Colors.grey.shade200,
                        labelStyle:
                            TextStyle(color: Colors.grey.shade800, fontSize: 10),
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
                  // "정산 완료" 시 UI (★수정★)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '정산 완료',
                        style: TextStyle(
                            fontSize: 16,
                            color: finalProfitColor,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        '총 매수 금액:',
                        '${displayPurchaseAmount.toStringAsFixed(0)} 원', // (★수정★)
                        textColor: textColor,
                        subTextColor: subTextColor,
                      ),
                      _buildInfoRow(
                          '최종 실현 수익:',
                          '${finalProfitAmount.toStringAsFixed(0)} 원', // (★수정★)
                          valueColor: finalProfitColor,
                          textColor: textColor,
                          subTextColor: subTextColor),
                      _buildInfoRow(
                          '최종 수익률:',
                          '${finalProfitRate.toStringAsFixed(2)} %', // (★수정★)
                          valueColor: finalProfitColor,
                          textColor: textColor,
                          subTextColor: subTextColor),
                    ],
                  )
                else
                  // "진행 중" 시 UI (★수정★)
                  Column(
                    children: [
                      Builder(
                        builder: (context) {
                          double currentProfitLoss = 0.0;
                          double currentProfitRate = 0.0;
                          Color currentProfitColor = Colors.grey;

                          // (★핵심 수정★) "준영"일 경우 A/B 평가 손익 합산
                          if (cycleType == 'junyeong') {
                            // A지갑 평가 손익
                            final double avgPrice_A =
                                (data['avgPrice_A'] as num?)?.toDouble() ?? 0.0;
                            final int quantity_A =
                                (data['currentQuantity_A'] as num?)?.toInt() ?? 0;
                            if (avgPrice_A > 0 &&
                                currentPrice > 0 &&
                                quantity_A > 0) {
                              currentProfitLoss +=
                                  (currentPrice - avgPrice_A) * quantity_A;
                            }
                            // B지갑 평가 손익
                            final double avgPrice_B =
                                (data['avgPrice_B'] as num?)?.toDouble() ?? 0.0;
                            final int quantity_B =
                                (data['currentQuantity_B'] as num?)?.toInt() ?? 0;
                            if (avgPrice_B > 0 &&
                                currentPrice > 0 &&
                                quantity_B > 0) {
                              currentProfitLoss +=
                                  (currentPrice - avgPrice_B) * quantity_B;
                            }
                          } else {
                            // "무매"일 경우 기존 로직
                            if (displayAvgPrice > 0 &&
                                currentPrice > 0 &&
                                displayQuantity > 0) {
                              currentProfitLoss =
                                  (currentPrice - displayAvgPrice) * displayQuantity;
                            }
                          }

                          currentProfitRate = (displayPurchaseAmount == 0)
                              ? 0.0
                              : (currentProfitLoss / displayPurchaseAmount) * 100;
                          currentProfitColor = currentProfitLoss >= 0
                              ? Colors.red
                              : Colors.blue.shade700;
                          
                          // (★수정★) "준영"은 Track A 수익률로 달성률 계산
                          double achievementRateBase = 0.0;
                          if (cycleType == 'junyeong') {
                            final double avgPrice_A = (data['avgPrice_A'] as num?)?.toDouble() ?? 0.0;
                            if (avgPrice_A > 0 && currentPrice > 0) {
                              achievementRateBase = ((currentPrice / avgPrice_A) - 1) * 100;
                            }
                          } else {
                            achievementRateBase = currentProfitRate;
                          }

                          double achievementRate = (targetProfitRate == 0 ||
                                  achievementRateBase < 0)
                              ? 0
                              : (achievementRateBase / targetProfitRate);
                          achievementRate = achievementRate.clamp(0.0, 1.0);

                          return Column(
                            children: [
                              _buildInfoRow(
                                '평단가:',
                                (cycleType == 'junyeong' && displayAvgPrice == 0)
                                    ? '(Track A: -)' // 준영 A 평단가
                                    : '${displayAvgPrice.toStringAsFixed(0)} 원',
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                              _buildInfoRow(
                                '보유 수량:',
                                '$displayQuantity 주', // (★수정★)
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                              _buildInfoRow(
                                  '현재 평가손익:',
                                  '${currentProfitLoss.toStringAsFixed(0)} 원', // (★수정★)
                                  valueColor: currentProfitColor,
                                  textColor: textColor,
                                  subTextColor: subTextColor),
                              _buildInfoRow(
                                  '현재 수익률:',
                                  '${currentProfitRate.toStringAsFixed(2)} %', // (★수정★)
                                  valueColor: currentProfitColor,
                                  textColor: textColor,
                                  subTextColor: subTextColor),
                              const Divider(height: 16),
                              _buildInfoRow(
                                  '목표 수익률:',
                                  (cycleType == 'junyeong')
                                      ? '$targetProfitRate % (Track A)'
                                      : '$targetProfitRate %',
                                  textColor: textColor,
                                  subTextColor: subTextColor),
                              _buildInfoRow(
                                  '달성률:',
                                  '${(achievementRate * 100).toStringAsFixed(1)} %',
                                  textColor: textColor,
                                  subTextColor: subTextColor),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 4, 0, 4),
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

  Widget _buildInfoRow(String title, String value,
      {Color? valueColor,
      required Color textColor,
      required Color subTextColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: subTextColor)),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? textColor,
            )),
      ],
    );
  }
}