import 'package:flutter/material.dart';

/// 通算試合数と勝率のカード
class TotalStatsCard extends StatelessWidget {
  final int totalMatches;
  final double winRate;

  const TotalStatsCard({
    super.key,
    required this.totalMatches,
    required this.winRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'TOTAL MATCHES',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$totalMatches',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '通算試合数',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: const Color(0xFFEEEEEE),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'WIN RATE',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${winRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '勝率',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
