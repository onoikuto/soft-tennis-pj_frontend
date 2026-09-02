import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/ai_insight_service.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';

/// テスト用のスタッツを作る
///
/// [winRate] と [totalMatches] だけを差し替えられるようにしてある。
InsightInput buildInput({
  double winRate = 62.5,
  int totalMatches = 20,
}) {
  return InsightInput(
    totalMatches: totalMatches,
    winRate: winRate,
    recentResults: const [true, false, true, true, false],
    serviceWinRate: 55.5,
    receiveWinRate: 48.2,
    deuceWinRate: 50.0,
    deuceTotal: 12,
    finalGameWinRate: 60.0,
    finalGameTotal: 5,
    hasPointDetails: false,
    firstServeInRate: 63.3,
    pointStats: null,
    opponents: [OpponentRecord('山田・田中')..wins = 3],
  );
}

void main() {
  group('AiInsightService.statsHash', () {
    // このハッシュが安定しないと、スタッツが変わっていないのに毎回
    // 生成し直してしまい、1日の上限をすぐ使い切る。
    test('同じスタッツなら同じハッシュになる', () {
      expect(
        AiInsightService.statsHash(buildInput()),
        AiInsightService.statsHash(buildInput()),
      );
    });

    test('小数第2位以下の違いは無視される（丸めが効いている）', () {
      expect(
        AiInsightService.statsHash(buildInput(winRate: 62.5)),
        AiInsightService.statsHash(buildInput(winRate: 62.54)),
      );
    });

    test('試合を1つ記録するとハッシュが変わる', () {
      expect(
        AiInsightService.statsHash(buildInput(totalMatches: 20)),
        isNot(AiInsightService.statsHash(buildInput(totalMatches: 21))),
      );
    });

    test('勝率が1%以上変われば別のハッシュになる', () {
      expect(
        AiInsightService.statsHash(buildInput(winRate: 62.5)),
        isNot(AiInsightService.statsHash(buildInput(winRate: 63.5))),
      );
    });
  });
}
