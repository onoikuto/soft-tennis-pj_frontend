import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';

PointDetail _point(
  int game,
  int number,
  String winner, {
  String serverTeam = 'team1',
  String? serverPlayer,
  bool firstServeIn = true,
}) {
  return PointDetail(
    matchId: 1,
    gameNumber: game,
    pointNumber: number,
    serverTeam: serverTeam,
    serverPlayer: serverPlayer,
    firstServeIn: firstServeIn,
    pointWinner: winner,
    pointType: 'opponent_error',
    createdAt: DateTime(2026, 7, 1),
  );
}

MatchRecord _record(DateTime date, bool won, String opponent) {
  return MatchRecord(date: date, won: won, opponentLabel: opponent);
}

void main() {
  group('TrendStats', () {
    test('直近の勝敗は古い試合から順に返す', () {
      final records = [
        _record(DateTime(2026, 3, 1), true, 'A'),
        _record(DateTime(2026, 1, 1), false, 'B'),
        _record(DateTime(2026, 2, 1), true, 'A'),
      ];
      expect(TrendStats.recentResults(records), [false, true, true]);
    });

    test('月別勝率を古い月から集計する', () {
      final records = [
        _record(DateTime(2026, 1, 10), true, 'A'),
        _record(DateTime(2026, 1, 20), false, 'B'),
        _record(DateTime(2026, 2, 5), true, 'A'),
      ];
      final monthly = TrendStats.monthly(records);
      expect(monthly.length, 2);
      expect(monthly[0].month, DateTime(2026, 1));
      expect(monthly[0].wins, 1);
      expect(monthly[0].total, 2);
      expect(monthly[1].rate, 100.0);
    });

    test('対戦相手別成績を対戦数の多い順に集計する', () {
      final records = [
        _record(DateTime(2026, 1, 1), true, 'A'),
        _record(DateTime(2026, 1, 2), false, 'A'),
        _record(DateTime(2026, 1, 3), false, 'A'),
        _record(DateTime(2026, 1, 4), true, 'B'),
      ];
      final opponents = TrendStats.opponents(records);
      expect(opponents.first.label, 'A');
      expect(opponents.first.wins, 1);
      expect(opponents.first.losses, 2);
      expect(opponents.first.winRate, closeTo(33.3, 0.1));
    });
  });

  group('AdvancedPointStats', () {
    test('1st/2ndサーブ別・選手別のサーブ統計を集計する', () {
      final stats = AdvancedPointStats();
      stats.addMatch(
        myTeam: 'team1',
        gameCount: 7,
        gameScores: [],
        points: [
          // 山田のサーブ: 1st IN で取得
          _point(1, 1, 'team1', serverPlayer: '山田', firstServeIn: true),
          // 山田のサーブ: 2nd で失点
          _point(1, 2, 'team2', serverPlayer: '山田', firstServeIn: false),
          // 相手のサーブ（自チームのサーブ統計には含めない）
          _point(1, 3, 'team1', serverTeam: 'team2', serverPlayer: '佐藤'),
        ],
      );

      expect(stats.firstServePointTotal, 1);
      expect(stats.firstServePointWon, 1);
      expect(stats.secondServePointTotal, 1);
      expect(stats.secondServePointWon, 0);
      expect(stats.serverStats.length, 1);
      expect(stats.serverStats['山田']!.total, 2);
      expect(stats.serverStats['山田']!.won, 1);
      expect(stats.overallPointTotal, 3);
      expect(stats.overallPointWon, 2);
    });

    test('連続失点・失点直後・ゲームポイントを集計する', () {
      final stats = AdvancedPointStats();
      // 勝勝勝(3-0 ゲームポイント)→勝(4-0 で取り切り)
      // 次のゲーム: 失失失(3連続失点1回)→勝(失点直後の取得)
      stats.addMatch(
        myTeam: 'team1',
        gameCount: 7,
        gameScores: [],
        points: [
          _point(1, 1, 'team1'),
          _point(1, 2, 'team1'),
          _point(1, 3, 'team1'),
          _point(1, 4, 'team1'), // 3-0からのゲームポイントを取り切り
          _point(2, 1, 'team2'),
          _point(2, 2, 'team2'),
          _point(2, 3, 'team2'), // 3連続失点
          _point(2, 4, 'team1'), // 失点直後に取得
        ],
      );

      expect(stats.gamePointTotal, 1);
      expect(stats.gamePointWon, 1);
      expect(stats.lossStreak3Count, 1);
      // 失点直後のポイント: 2ゲーム目の2,3,4本目（1本目の後・2本目の後・3本目の後）
      expect(stats.afterLossTotal, 3);
      expect(stats.afterLossWon, 1);
    });

    test('4連続失点は1回としてカウントする', () {
      final stats = AdvancedPointStats();
      stats.addMatch(
        myTeam: 'team1',
        gameCount: 7,
        gameScores: [],
        points: [
          _point(1, 1, 'team2'),
          _point(1, 2, 'team2'),
          _point(1, 3, 'team2'),
          _point(1, 4, 'team2'),
        ],
      );
      expect(stats.lossStreak3Count, 1);
    });
  });

  group('InsightEngine', () {
    InsightInput baseInput({
      List<bool>? recentResults,
      double serviceWinRate = 50,
      double receiveWinRate = 50,
      int totalMatches = 10,
    }) {
      return InsightInput(
        totalMatches: totalMatches,
        winRate: 50,
        recentResults: recentResults ?? [],
        serviceWinRate: serviceWinRate,
        receiveWinRate: receiveWinRate,
        deuceWinRate: 50,
        deuceTotal: 0,
        finalGameWinRate: 50,
        finalGameTotal: 0,
        hasPointDetails: false,
        firstServeInRate: 0,
        pointStats: null,
        opponents: const [],
      );
    }

    test('直近5試合で4勝以上なら好調コメントが出る', () {
      final insights = InsightEngine.generate(
        baseInput(recentResults: [true, true, true, true, false, true]),
      );
      expect(insights.any((i) => i.text.contains('好調')), isTrue);
    });

    test('サーブとレシーブの取得率差が大きいと課題コメントが出る', () {
      final insights = InsightEngine.generate(
        baseInput(serviceWinRate: 70, receiveWinRate: 40),
      );
      expect(
        insights.any((i) => i.type == InsightType.warning && i.text.contains('レシーブ')),
        isTrue,
      );
    });

    test('データが少ない場合はフォールバックのコメントが出る', () {
      final insights = InsightEngine.generate(baseInput(totalMatches: 1));
      expect(insights, isNotEmpty);
      expect(insights.first.type, InsightType.info);
    });

    test('コメントは最大件数までに制限される', () {
      final insights = InsightEngine.generate(
        baseInput(
          recentResults: [false, false, false, false, false],
          serviceWinRate: 80,
          receiveWinRate: 30,
        ),
        maxComments: 2,
      );
      expect(insights.length, lessThanOrEqualTo(2));
    });
  });
}
