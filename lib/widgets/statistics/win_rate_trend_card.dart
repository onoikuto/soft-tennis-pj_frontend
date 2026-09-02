import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';

/// 勝率の推移カード
///
/// 直近10試合の勝敗と、月別勝率の推移を表示します。
class WinRateTrendCard extends StatelessWidget {
  /// 直近の勝敗（古い試合から順）
  final List<bool> recentResults;

  /// 月別勝率（古い月から順）
  final List<MonthlyWinRate> monthly;

  const WinRateTrendCard({
    super.key,
    required this.recentResults,
    required this.monthly,
  });

  @override
  Widget build(BuildContext context) {
    if (recentResults.isEmpty) return const SizedBox();

    final recentWins = recentResults.where((won) => won).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              color: Color(0xFFF7F7F7),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '勝率の推移',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'WIN RATE TREND',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 直近の勝敗
                Text(
                  '直近${recentResults.length}試合  $recentWins勝${recentResults.length - recentWins}敗',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var won in recentResults)
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: won ? const Color(0xFF1E293B) : const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          won ? '勝' : '負',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: won ? Colors.white : const Color(0xFF999999),
                          ),
                        ),
                      ),
                  ],
                ),
                if (monthly.length >= 2) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '月別勝率',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var month in monthly)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${month.rate.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: (month.rate / 100 * 60).clamp(2.0, 60.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${month.month.month}月',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF888888),
                                    ),
                                  ),
                                  Text(
                                    '${month.total}試合',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Color(0xFFAAAAAA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
