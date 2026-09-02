import 'package:flutter/material.dart';

/// データインサイトカード
///
/// ゲーム別勝率・勝率・サーブ/レシーブ取得率からインサイト文を生成して表示します。
class DataInsightsCard extends StatelessWidget {
  final Map<int, double> gameWinRates;
  final double winRate;
  final double serviceWinRate;
  final double receiveWinRate;

  const DataInsightsCard({
    super.key,
    required this.gameWinRates,
    required this.winRate,
    required this.serviceWinRate,
    required this.receiveWinRate,
  });

  @override
  Widget build(BuildContext context) {
    // 最も低いゲーム勝率を探す
    int? lowestGame;
    double? lowestRate;
    if (gameWinRates.isNotEmpty) {
      gameWinRates.forEach((gameNum, rate) {
        if (lowestRate == null || rate < lowestRate!) {
          lowestRate = rate;
          lowestGame = gameNum;
        }
      });
    }

    String insightText = '';
    if (lowestGame != null && lowestRate != null && lowestRate! < 50) {
      insightText = 'Game $lowestGameの立ち上がりにデータ上の課題が見られます。';
    } else if (winRate >= 60) {
      insightText = '安定した勝率を誇ります。';
    } else {
      insightText = 'さらなる改善の余地があります。';
    }

    String adviceText = '';
    if (serviceWinRate > receiveWinRate + 10) {
      adviceText =
          'サーブ時の取得率が非常に高い（${serviceWinRate.toStringAsFixed(0)}%）ため、サービスゲームを確実にキープする戦術を維持しましょう。一方でレシーブ時は相手のセカンドサーブをより積極的に攻めることで、全体の勝率をさらに高められます。';
    } else if (receiveWinRate > serviceWinRate + 10) {
      adviceText =
          'レシーブ時の取得率が高い（${receiveWinRate.toStringAsFixed(0)}%）ため、レシーブゲームを積極的に狙う戦術が有効です。サーブ時はより確実にポイントを取ることを意識しましょう。';
    } else {
      adviceText =
          'サーブとレシーブのバランスが取れています。両方の取得率をさらに向上させることで、より安定した成績を残せます。';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: const BorderSide(color: Color(0xFF1E293B), width: 4),
          top: const BorderSide(color: Color(0xFFEEEEEE)),
          right: const BorderSide(color: Color(0xFFEEEEEE)),
          bottom: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
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
          Row(
            children: [
              const Icon(
                Icons.analytics,
                size: 14,
                color: Color(0xFF1E293B),
              ),
              const SizedBox(width: 6),
              const Text(
                'DATA INSIGHTS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insightText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),
          const Text(
            'SERVICE & RECEIVE ADVICE:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            adviceText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
