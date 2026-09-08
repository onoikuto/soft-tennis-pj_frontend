import 'package:flutter/material.dart';

import 'package:soft_tennis_scoring/services/pair_report.dart';

/// ペア2人分のまとめを描画する
///
/// 統計画面（累計）と試合終了直後（その1試合）の両方で使います。
/// 同じ数字が違う見た目で出ると読み手が混乱するため、描画も1か所にします。
class PairReportView extends StatelessWidget {
  final PairReport report;

  /// 端末内LLMで言い回しを整えたか（AIバッジの出し分け）
  final bool phrasedByAi;

  const PairReportView({
    super.key,
    required this.report,
    this.phrasedByAi = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!report.hasContent) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '分析+で球種と展開を記録すると、選手ごとの傾向が出せます。',
          style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF888888)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final player in report.players)
          if (player.hasContent) ...[
            _sectionTitle(player.name),
            if (player.good != null)
              _line('Good', player.good!, const Color(0xFF2E7D32)),
            if (player.bad != null)
              _line('Bad', player.bad!, const Color(0xFFB3261E)),
            const SizedBox(height: 12),
          ],
        if (report.opponent?.hasContent ?? false) ...[
          _sectionTitle('相手ペア'),
          if (report.opponent!.weakness != null)
            _line('弱点', report.opponent!.weakness!, const Color(0xFF2E7D32)),
          if (report.opponent!.strength != null)
            _line('警戒', report.opponent!.strength!, const Color(0xFFB3261E)),
          const SizedBox(height: 12),
        ],
        if (report.summary != null) ...[
          Row(
            children: [
              _sectionTitle('一言アドバイス'),
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
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              report.summary!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '【$text】',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _line(String label, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
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
