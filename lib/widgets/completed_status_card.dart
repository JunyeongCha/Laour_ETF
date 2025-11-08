// lib/widgets/completed_status_card.dart (★수정 완료★)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/providers/theme_provider.dart';

class CompletedStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const CompletedStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;

    double totalRealizedProfit = 0.0;
    double totalPurchaseAmount = 0.0;
    double totalSellAmount = 0.0;
    int totalTValues = 0;

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      // (★핵심 수정★) 1. 사이클 타입 식별
      final String cycleType = data['type'] ?? 'mumae';

      // (★핵심 수정★) 2. 타입에 따라 분기
      if (cycleType == 'junyeong') {
        // "준영" 사이클: A/B 데이터 합산
        totalRealizedProfit +=
            ((data['realizedProfit_A'] as num?)?.toDouble() ?? 0.0) +
                ((data['realizedProfit_B'] as num?)?.toDouble() ?? 0.0);
        totalPurchaseAmount +=
            ((data['currentPurchaseAmount_A'] as num?)?.toDouble() ?? 0.0) +
                ((data['currentPurchaseAmount_B'] as num?)?.toDouble() ?? 0.0);
        totalSellAmount +=
            ((data['totalSellAmount_A'] as num?)?.toDouble() ?? 0.0) +
                ((data['totalSellAmount_B'] as num?)?.toDouble() ?? 0.0);
      } else {
        // "무매" 사이클: 기존 데이터 사용
        totalRealizedProfit +=
            (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
        totalPurchaseAmount +=
            (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
        totalSellAmount +=
            (data['totalSellAmount'] as num?)?.toDouble() ?? 0.0;
      }
      
      totalTValues += (data['T_value'] as num?)?.toInt() ?? 0;
    }

    final int portfolioCount = cycleDocs.length;

    // (★수정★) '총 실현 수익' 기반 수익률 계산으로 변경
    final double avgProfitRate = (totalPurchaseAmount == 0)
        ? 0.0
        : (totalRealizedProfit / totalPurchaseAmount) * 100;

    final double avgTValue =
        (portfolioCount == 0) ? 0.0 : (totalTValues / portfolioCount);

    final Color profitColor =
        totalRealizedProfit >= 0 ? Colors.red : Colors.blue.shade700;

    // --- (UI 수정) ---
    final Color cardBackgroundColor =
        isDarkMode ? Colors.grey[900]! : Colors.grey.shade100;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor =
        isDarkMode ? Colors.white70 : Colors.grey.shade700;
    final Color borderColor =
        isDarkMode ? Colors.white.withOpacity(0.5) : Colors.transparent;

    return Card(
      color: cardBackgroundColor,
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isDarkMode ? 1.0 : 0.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusRow('총 실현 수익:', '${totalRealizedProfit.toStringAsFixed(0)} 원',
                valueColor: profitColor,
                textColor: textColor,
                subTextColor: subTextColor),
            _buildStatusRow('평균 수익률:', '${avgProfitRate.toStringAsFixed(2)} %',
                valueColor: profitColor,
                textColor: textColor,
                subTextColor: subTextColor),
            _buildStatusRow('평균 종료 분할수:', avgTValue.toStringAsFixed(1),
                textColor: textColor, subTextColor: subTextColor),
            _buildStatusRow('완료 포트폴리오 수:', '$portfolioCount 개',
                textColor: textColor, subTextColor: subTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, String value,
      {Color? valueColor,
      required Color textColor,
      required Color subTextColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: subTextColor)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: valueColor ?? textColor,
            ),
          ),
        ],
      ),
    );
  }
}