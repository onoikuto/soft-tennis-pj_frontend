import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';

/// 分析コメントカード
///
/// 統計データからルールベースで生成した講評（強み・課題・アドバイス）を表示します。
class AnalysisCommentCard extends StatelessWidget {
  final List<Insight> insights;

  const AnalysisCommentCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox();

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
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '分析コメント',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  'ANALYSIS',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < insights.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildInsightRow(insights[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(Insight insight) {
    final (icon, iconColor, bgColor) = switch (insight.type) {
      InsightType.good => (
          Icons.thumb_up_alt_outlined,
          const Color(0xFF2E7D32),
          const Color(0xFFF1F8F2),
        ),
      InsightType.warning => (
          Icons.flag_outlined,
          const Color(0xFFE65100),
          const Color(0xFFFFF8F0),
        ),
      InsightType.info => (
          Icons.lightbulb_outline,
          const Color(0xFF64748B),
          const Color(0xFFF7F8FA),
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight.text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
