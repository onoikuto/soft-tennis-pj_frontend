import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';

/// 流れ・決定力カード
///
/// ゲームポイントの決定率、失点直後の切り替え力、
/// 連続失点の傾向を表示します。
class MomentumCard extends StatelessWidget {
  final AdvancedPointStats stats;

  const MomentumCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.overallPointTotal == 0) return const SizedBox();

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
                    '流れ・決定力',
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
                    'MOMENTUM',
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
              children: [
                _buildStatRow(
                  title: 'ゲームポイント決定率',
                  description: 'あと1本でゲーム取得の場面で取り切った割合',
                  value: '${stats.gamePointRate.toStringAsFixed(0)}%',
                  sample: '${stats.gamePointTotal}回中${stats.gamePointWon}回',
                ),
                const Divider(height: 24, color: Color(0xFFF0F0F0)),
                _buildStatRow(
                  title: '失点直後の取得率',
                  description: '失点した直後のポイントを取れた割合（全体: ${stats.overallPointRate.toStringAsFixed(0)}%）',
                  value: '${stats.afterLossRate.toStringAsFixed(0)}%',
                  sample: '${stats.afterLossTotal}本',
                ),
                const Divider(height: 24, color: Color(0xFFF0F0F0)),
                _buildStatRow(
                  title: '3連続以上の失点',
                  description: '1試合あたりの平均発生回数',
                  value: '${stats.lossStreak3PerMatch.toStringAsFixed(1)}回',
                  sample: '${stats.matchCount}試合で${stats.lossStreak3Count}回',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required String title,
    required String description,
    required String value,
    required String sample,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              sample,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
