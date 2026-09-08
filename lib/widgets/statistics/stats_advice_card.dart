import 'package:flutter/material.dart';

import 'package:soft_tennis_scoring/services/stats_advice.dart';

/// 統計画面に出すAIアドバイスのカード
///
/// 見ているタブ（ペア単位／学校・クラブ単位／選手単位）ごとに中身が変わります。
class StatsAdviceCard extends StatelessWidget {
  final List<StatsAdviceLine> lines;

  /// 端末内LLMで言い回しを整えたか（AIバッジの出し分け）
  final bool phrasedByAi;

  const StatsAdviceCard({
    super.key,
    required this.lines,
    this.phrasedByAi = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'アドバイス',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              if (phrasedByAi) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
          const SizedBox(height: 12),
          if (lines.isEmpty)
            const Text(
              '試合数がまだ少ないため、出せるアドバイスがありません。'
              '分析+で記録すると精度が上がります。',
              style:
                  TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF888888)),
            )
          else
            for (final line in lines) _row(line),
        ],
      ),
    );
  }

  Widget _row(StatsAdviceLine line) {
    final color = switch (line.category) {
      StatsAdviceCategory.practice => const Color(0xFF1565C0),
      StatsAdviceCategory.mental => const Color(0xFF6A1B9A),
      StatsAdviceCategory.tactics => const Color(0xFF2E7D32),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statsAdviceCategoryLabel(line.category),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            line.text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
