import 'package:flutter/material.dart';

import 'package:soft_tennis_scoring/services/live_coach_service.dart';

/// 試合中アドバイスの表示カード
///
/// スコア入力ボタンのすぐ上に置きます。試合中は下半分しか見ていないためです。
/// 邪魔なときに消せるよう、×で閉じられるようにしています。
class LiveAdviceCard extends StatelessWidget {
  final LiveCoachMessage message;

  /// ×を押したとき
  final VoidCallback onDismiss;

  const LiveAdviceCard({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // 得点の傾向か失点の傾向かで、ひと目で分かるように色を変える
    final accent =
        message.isGood ? const Color(0xFF2E7D32) : const Color(0xFFB3261E);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            message.isGood
                ? Icons.trending_up
                : Icons.report_problem_outlined,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.headline,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    if (message.phrasedByAi) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
