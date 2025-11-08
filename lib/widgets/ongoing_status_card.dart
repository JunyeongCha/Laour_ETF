// lib/widgets/ongoing_status_card.dart (★수정 완료★)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:laour_etf/providers/theme_provider.dart';

class OngoingStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const OngoingStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;

    double totalSeed = 0;
    double totalPurchaseAmount = 0;
    double totalOngoingProfit = 0.0;

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      // (★핵심 수정★) 1. 사이클 타입 식별
      final String cycleType = data['type'] ?? 'mumae';

      // (★핵심 수정★) 2. 타입에 따라 분기
      totalSeed += (data['totalSeed'] as num?)?.toDouble() ?? 0.0;
      
      final double currentPrice = (data['currentPrice'] as num?)?.toDouble() ?? 0.0;

      if (cycleType == 'junyeong') {
        // "준영" 사이클: A/B 데이터 합산
        final double purchaseAmount_A = (data['currentPurchaseAmount_A'] as num?)?.toDouble() ?? 0.0;
        final double purchaseAmount_B = (data['currentPurchaseAmount_B'] as num?)?.toDouble() ?? 0.0;
        totalPurchaseAmount += purchaseAmount_A + purchaseAmount_B;
        
        // A지갑 평가 손익
        final double avgPrice_A = (data['avgPrice_A'] as num?)?.toDouble() ?? 0.0;
        final int quantity_A = (data['currentQuantity_A'] as num?)?.toInt() ?? 0;
        if (avgPrice_A > 0 && currentPrice > 0 && quantity_A > 0) {
          totalOngoingProfit += (currentPrice - avgPrice_A) * quantity_A;
        }
        
        // B지갑 평가 손익
        final double avgPrice_B = (data['avgPrice_B'] as num?)?.toDouble() ?? 0.0;
        final int quantity_B = (data['currentQuantity_B'] as num?)?.toInt() ?? 0;
        if (avgPrice_B > 0 && currentPrice > 0 && quantity_B > 0) {
          totalOngoingProfit += (currentPrice - avgPrice_B) * quantity_B;
        }

      } else {
        // "무매" 사이클: 기존 데이터 사용
        final double purchaseAmount = (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
        totalPurchaseAmount += purchaseAmount;

        final int currentQuantity = (data['currentQuantity'] as num?)?.toInt() ?? 0;
        if (currentQuantity > 0) {
          final double avgPrice = (data['avgPrice'] as num?)?.toDouble() ?? 0.0;
          if (avgPrice > 0 && currentPrice > 0) {
            totalOngoingProfit += (currentPrice - avgPrice) * currentQuantity;
          }
        }
      }
    }

    final int portfolioCount = cycleDocs.length;
    final double seedUsagePercent = (totalSeed == 0) ? 0 : (totalPurchaseAmount / totalSeed) * 100;
    
    final double totalOngoingProfitRate = (totalPurchaseAmount == 0) 
        ? 0.0 
        : (totalOngoingProfit / totalPurchaseAmount) * 100;
    
    final Color profitColor = totalOngoingProfit >= 0 ? Colors.red : Colors.blue.shade700;

    // --- (UI 수정) ---
    final Color cardBackgroundColor = isDarkMode ? Colors.grey[900]! : Colors.blue.shade50; 
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey.shade700;
    final Color borderColor = isDarkMode ? Colors.white.withOpacity(0.5) : Colors.transparent; 

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
            _buildStatusRow(
              '진행중 시드', 
              '${totalSeed.toStringAsFixed(0)} 원',
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '진행중 매입금액', 
              '${totalPurchaseAmount.toStringAsFixed(0)} 원',
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '진행중 총 손익:', 
              '${totalOngoingProfit.toStringAsFixed(0)} 원',
              valueColor: profitColor,
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '진행중 총 손익률:', 
              '${totalOngoingProfitRate.toStringAsFixed(2)} %',
              valueColor: profitColor,
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '진행중 포트폴리오 수', 
              '$portfolioCount 개',
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '진행중 시드 소진율:',
                  style: TextStyle(color: subTextColor),
                ),
                Text(
                  '${seedUsagePercent.toStringAsFixed(1)} %', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor)
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: seedUsagePercent / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, String value, {Color? valueColor, required Color textColor, required Color subTextColor}) {
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