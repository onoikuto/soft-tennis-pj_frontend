import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';

/// サーブ詳細分析カード
///
/// 1stサーブ時と2ndサーブ時の得点率の比較、
/// 選手別のサーブ時得点率を表示します。
class ServeDetailCard extends StatelessWidget {
  final AdvancedPointStats stats;

  const ServeDetailCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.firstServePointTotal + stats.secondServePointTotal == 0) {
      return const SizedBox();
    }

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
                    'サーブ詳細分析',
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
                    'SERVE ANALYSIS',
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
                const Text(
                  'サーブ時の得点率（1st / 2nd）',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRateBar(
                  label: '1stサーブ時',
                  rate: stats.firstServePointRate,
                  sample: stats.firstServePointTotal,
                  color: const Color(0xFF1E293B),
                ),
                const SizedBox(height: 10),
                _buildRateBar(
                  label: '2ndサーブ時',
                  rate: stats.secondServePointRate,
                  sample: stats.secondServePointTotal,
                  color: const Color(0xFF64748B),
                ),
                if (stats.serverStatsList.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '選手別サーブ時得点率',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var server in stats.serverStatsList) ...[
                    _buildRateBar(
                      label: server.player,
                      rate: server.rate,
                      sample: server.total,
                      color: const Color(0xFF1E293B),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateBar({
    required String label,
    required double rate,
    required int sample,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${rate.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($sample本)',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: const Color(0xFFF0F0F0),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (rate / 100).clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}
