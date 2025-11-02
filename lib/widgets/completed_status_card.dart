import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // (★신규★)
import 'package:laour_etf/providers/theme_provider.dart'; // (★신규★)

class CompletedStatusCard extends StatelessWidget {
  final List<QueryDocumentSnapshot> cycleDocs;

  const CompletedStatusCard({super.key, required this.cycleDocs});

  @override
  Widget build(BuildContext context) {
    // (★신규★) 현재 테마 모드를 가져옴
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDarkMode = themeProvider.isDarkMode;
    
    // --- (★복구★) 5-2의 원본 계산 로직 시작 ---
    double totalRealizedProfit = 0.0;
    double totalPurchaseAmount = 0.0;
    double totalSellAmount = 0.0;
    int totalTValues = 0;

    for (var doc in cycleDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      totalRealizedProfit += (data['realizedProfit'] as num?)?.toDouble() ?? 0.0;
      totalPurchaseAmount += (data['currentPurchaseAmount'] as num?)?.toDouble() ?? 0.0;
      totalSellAmount += (data['totalSellAmount'] as num?)?.toDouble() ?? 0.0;
      totalTValues += (data['T_value'] as num?)?.toInt() ?? 0;
    }

    final int portfolioCount = cycleDocs.length;
    
    final double avgProfitRate = (totalPurchaseAmount == 0) 
        ? 0.0 
        : (totalSellAmount / totalPurchaseAmount - 1) * 100;
        
    final double avgTValue = (portfolioCount == 0) ? 0.0 : (totalTValues / portfolioCount);

    final Color profitColor = totalRealizedProfit >= 0 ? Colors.red : Colors.blue.shade700;
    // --- (★복구★) 5-2의 원본 계산 로직 끝 ---

    // (★신규★) 다크 모드에 따른 배경 및 글씨 색상 조정
    final Color cardBackgroundColor = isDarkMode ? Colors.grey[900]! : Colors.grey.shade100; // 원본 회색
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey.shade700; // 원본 회색
    final Color borderColor = isDarkMode ? Colors.white.withOpacity(0.5) : Colors.transparent; // 테두리 색상

    return Card(
      color: cardBackgroundColor, // (★수정★)
      elevation: 2.0,
      // (★신규★) 테두리 추가
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isDarkMode ? 1.0 : 0.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // (★복구★) 5-2의 원본 UI 항목들
            _buildStatusRow(
              '총 실현 수익:', 
              '${totalRealizedProfit.toStringAsFixed(0)} 원',
              valueColor: profitColor,
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '평균 수익률:', 
              '${avgProfitRate.toStringAsFixed(2)} %',
              valueColor: profitColor,
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '평균 종료 분할수:', 
              avgTValue.toStringAsFixed(1),
              textColor: textColor, 
              subTextColor: subTextColor
            ),
            _buildStatusRow(
              '완료 포트폴리오 수:', 
              '$portfolioCount 개',
              textColor: textColor, 
              subTextColor: subTextColor
            ),
          ],
        ),
      ),
    );
  }

  // (★수정★) 헬퍼 함수가 다크모드 텍스트 색상을 받도록 수정
  Widget _buildStatusRow(String title, String value, {Color? valueColor, required Color textColor, required Color subTextColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: subTextColor)), // (★수정★)
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
              color: valueColor ?? textColor, // (★수정★)
            ),
          ),
        ],
      ),
    );
  }
}