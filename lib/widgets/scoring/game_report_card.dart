import 'package:flutter/material.dart';

import 'package:soft_tennis_scoring/services/live_coach_service.dart';
import 'package:soft_tennis_scoring/widgets/common/pair_report_view.dart';

/// ゲームが終わるたびに出す振り返りのカード
///
/// スコア入力ボタンのすぐ上に置きます。試合中は下半分しか見ていないためです。
/// 邪魔なときに消せるよう、×で閉じられるようにしています。
class GameReportCard extends StatelessWidget {
  final GameReportMessage message;

  /// ×を押したとき
  final VoidCallback onDismiss;

  const GameReportCard({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ここまでの傾向',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child:
                      Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          PairReportView(
            report: message.report,
            phrasedByAi: message.phrasedByAi,
          ),
        ],
      ),
    );
  }
}
