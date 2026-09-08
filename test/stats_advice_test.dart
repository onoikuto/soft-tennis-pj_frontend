import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';
import 'package:soft_tennis_scoring/services/stats_advice.dart';

InsightInput _input({
  double deuceWinRate = 60,
  int deuceTotal = 0,
  double finalGameWinRate = 60,
  int finalGameTotal = 0,
  double firstServeInRate = 80,
  double serviceWinRate = 60,
  double receiveWinRate = 50,
  bool hasPointDetails = true,
  AdvancedPointStats? pointStats,
  List<OpponentRecord> opponents = const [],
  int totalMatches = 20,
  double winRate = 50,
}) =>
    InsightInput(
      totalMatches: totalMatches,
      winRate: winRate,
      recentResults: const [],
      serviceWinRate: serviceWinRate,
      receiveWinRate: receiveWinRate,
      deuceWinRate: deuceWinRate,
      deuceTotal: deuceTotal,
      finalGameWinRate: finalGameWinRate,
      finalGameTotal: finalGameTotal,
      hasPointDetails: hasPointDetails,
      firstServeInRate: firstServeInRate,
      pointStats: pointStats,
      opponents: opponents,
    );

void main() {
  group('StatsAdviceEngine メンタル面', () {
    test('デュースで勝てていなければ競り合いの課題として出す', () {
      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(deuceWinRate: 30, deuceTotal: 12),
      );

      final mental = advices
          .where((a) => a.category == StatsAdviceCategory.mental)
          .toList();
      expect(mental, isNotEmpty);
      expect(mental.first.fact, contains('デュースでの取得率が30%'));
      expect(mental.first.action, contains('3-3から始めるゲーム'));
    });

    test('回数が少なければ競り合いの判断はしない', () {
      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(deuceWinRate: 10, deuceTotal: 4),
      );

      expect(
        advices.where((a) => a.fact.contains('デュース')),
        isEmpty,
      );
    });

    test('ファイナルゲームで勝てていなければ出す', () {
      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(finalGameWinRate: 25, finalGameTotal: 8),
      );

      expect(
        advices.where((a) => a.fact.contains('ファイナルゲームの勝率が25%')),
        isNotEmpty,
      );
    });
  });

  group('StatsAdviceEngine 練習面', () {
    test('1stサーブが低ければ練習として出す', () {
      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(firstServeInRate: 45),
      );

      final practice = advices
          .where((a) => a.category == StatsAdviceCategory.practice)
          .toList();
      expect(practice.first.fact, contains('1stサーブの成功率が45%'));
    });

    test('分析+の記録がなければ1stサーブは見ない', () {
      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(firstServeInRate: 45, hasPointDetails: false),
      );

      expect(advices.where((a) => a.fact.contains('1stサーブ')), isEmpty);
    });
  });

  group('StatsAdviceEngine タブごとの違い', () {
    test('学校・クラブ単位では負け越している相手を出す', () {
      final opponent = OpponentRecord('B高校')
        ..wins = 1
        ..losses = 5;

      final club = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewClub,
        _input(opponents: [opponent]),
      );
      expect(club.where((a) => a.fact.contains('B高校に1勝5敗')), isNotEmpty);

      // ペア単位では相手別の話は出さない
      final pair = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(opponents: [opponent]),
      );
      expect(pair.where((a) => a.fact.contains('B高校')), isEmpty);
    });

    test('選手単位ではその選手のサーブ成績を出す', () {
      final stats = AdvancedPointStats();
      final stat = stats.serverStats.putIfAbsent(
          '山田', () => PlayerServeStat('山田'));
      stat.total = 30;
      stat.won = 10;

      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPlayer,
        _input(pointStats: stats),
      );

      expect(
        advices.where((a) => a.fact.contains('山田選手のサーブ時ポイント取得率が33%')),
        isNotEmpty,
      );
    });

    test('ペア単位ではミスの偏りを役割の問題として出す', () {
      final stats = AdvancedPointStats();
      stats.playerErrors['佐藤'] = 16;
      stats.playerErrors['山田'] = 6;

      final advices = StatsAdviceEngine.generate(
        StatsAdviceEngine.viewPair,
        _input(pointStats: stats),
      );

      final line = advices.firstWhere((a) => a.fact.contains('佐藤'));
      expect(line.category, StatsAdviceCategory.tactics);
      expect(line.action, contains('陣形と立ち位置'));
    });
  });

  test('材料がなければ何も出さない', () {
    expect(
      StatsAdviceEngine.generate(StatsAdviceEngine.viewPair, _input()),
      isEmpty,
    );
  });

  test('件数は上限で打ち切る', () {
    final advices = StatsAdviceEngine.generate(
      StatsAdviceEngine.viewPair,
      _input(
        deuceWinRate: 20,
        deuceTotal: 20,
        finalGameWinRate: 20,
        finalGameTotal: 10,
        firstServeInRate: 40,
        serviceWinRate: 30,
        receiveWinRate: 20,
      ),
      maxCount: 3,
    );

    expect(advices.length, 3);
  });
}
