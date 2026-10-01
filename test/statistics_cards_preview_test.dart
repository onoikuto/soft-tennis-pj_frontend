// 統計カードの見た目確認用（ゴールデン画像を生成するだけの一時テスト）
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';
import 'package:soft_tennis_scoring/widgets/statistics/analysis_comment_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/momentum_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/opponent_records_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/serve_detail_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/win_rate_trend_card.dart';

void main() {
  testWidgets('統計カードのプレビュー画像を生成', (tester) async {
    final fontData = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
        .readAsBytesSync();
    final fontLoader = FontLoader('JPFont')
      ..addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    // サンプルデータ
    final stats = AdvancedPointStats()
      ..matchCount = 8
      ..firstServePointTotal = 120
      ..firstServePointWon = 78
      ..secondServePointTotal = 60
      ..secondServePointWon = 24
      ..overallPointTotal = 400
      ..overallPointWon = 210
      ..afterLossTotal = 150
      ..afterLossWon = 63
      ..lossStreak3Count = 14
      ..gamePointTotal = 40
      ..gamePointWon = 22;
    stats.serverStats['山田'] = PlayerServeStat('山田')
      ..total = 90
      ..won = 58;
    stats.serverStats['田中'] = PlayerServeStat('田中')
      ..total = 90
      ..won = 40;

    final opponents = [
      OpponentRecord('長崎・熊本 (大阪スポーツ少年団)')
        ..wins = 1
        ..losses = 3,
      OpponentRecord('青木・広瀬 (北中学)')
        ..wins = 3
        ..losses = 0,
    ];

    final insights = InsightEngine.generate(InsightInput(
      totalMatches: 12,
      winRate: 58,
      recentResults: [true, false, false, false, false, true],
      serviceWinRate: 68,
      receiveWinRate: 41,
      serviceTotal: 44,
      receiveTotal: 41,
      deuceWinRate: 35,
      deuceTotal: 10,
      finalGameWinRate: 50,
      finalGameTotal: 4,
      hasPointDetails: true,
      firstServeInRate: 55,
      pointStats: stats,
      opponents: opponents,
    ));

    await tester.binding.setSurfaceSize(const Size(390, 2100));
    tester.view.physicalSize = const Size(1170, 6300);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'JPFont'),
        home: Scaffold(
          backgroundColor: const Color(0xFFFDFCFB),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                WinRateTrendCard(
                  recentResults: const [
                    true, true, false, true, false, false, true, true, false, true,
                  ],
                  monthly: [
                    MonthlyWinRate(month: DateTime(2026, 3), wins: 2, total: 4),
                    MonthlyWinRate(month: DateTime(2026, 4), wins: 3, total: 5),
                    MonthlyWinRate(month: DateTime(2026, 5), wins: 1, total: 3),
                    MonthlyWinRate(month: DateTime(2026, 6), wins: 4, total: 5),
                  ],
                ),
                const SizedBox(height: 16),
                OpponentRecordsCard(opponents: opponents),
                const SizedBox(height: 16),
                ServeDetailCard(stats: stats),
                const SizedBox(height: 16),
                MomentumCard(stats: stats),
                const SizedBox(height: 16),
                AnalysisCommentCard(insights: insights),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(SingleChildScrollView),
      matchesGoldenFile('goldens/statistics_cards_preview.png'),
    );
  });
}
