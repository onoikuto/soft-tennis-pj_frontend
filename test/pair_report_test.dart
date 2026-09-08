import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/pair_report.dart';

PointDetail _point({
  required int pointNumber,
  required String pointWinner,
  required String pointType,
  String? shotType,
  String? courseType,
  String? actionPlayer,
}) =>
    PointDetail(
      matchId: 1,
      gameNumber: 1,
      pointNumber: pointNumber,
      serverTeam: 'team1',
      firstServeIn: true,
      pointWinner: pointWinner,
      pointType: pointType,
      shotType: shotType,
      courseType: courseType,
      actionPlayer: actionPlayer,
      createdAt: DateTime(2026, 1, 1),
    );

AdvancedPointStats _stats(List<PointDetail> points) => AdvancedPointStats()
  ..addMatch(
    myTeam: 'team1',
    points: points,
    gameScores: [
      GameScore(matchId: 1, gameNumber: 1, team1Score: 4, team2Score: 2)
    ],
    gameCount: 7,
  );

void main() {
  group('PairReport', () {
    test('選手ごとにGoodとBadを組み立てる', () {
      final points = [
        for (var i = 1; i <= 3; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team1',
            pointType: PointType.winner,
            shotType: ShotType.smash,
            courseType: CourseType.cross,
            actionPlayer: '山田',
          ),
        for (var i = 4; i <= 6; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            courseType: CourseType.straightRight,
            actionPlayer: '佐藤',
          ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      expect(report.players.first.name, '山田');
      expect(report.players.first.good, 'スマッシュで3得点。クロス展開で得点しやすい。');
      expect(report.players.first.bad, isNull);

      expect(report.players[1].name, '佐藤');
      expect(report.players[1].bad, 'バックハンドで3失点。右ストレート展開で失点しやすい。');
      expect(report.players[1].good, isNull);
    });

    test('一言は得点と失点の比較を出す（Good/Bad行にない情報）', () {
      final points = [
        for (var i = 1; i <= 5; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            actionPlayer: '佐藤',
          ),
        for (var i = 6; i <= 8; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team1',
            pointType: PointType.winner,
            shotType: ShotType.smash,
            actionPlayer: '山田',
          ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      expect(report.summary,
          'ウィナー3本・ミス5本。ミスのほうが多く、その中心は佐藤のバックハンド（5本）。');
    });

    test('差が小さければどちらが多いとは言わない', () {
      final points = [
        for (var i = 1; i <= 4; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            actionPlayer: '佐藤',
          ),
        for (var i = 5; i <= 8; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team1',
            pointType: PointType.winner,
            shotType: ShotType.smash,
            actionPlayer: '山田',
          ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      expect(report.summary, 'ウィナー4本・ミス4本。');
    });

    test('1本しかないものを「中心」と言わない', () {
      // 5種類バラバラのウィナー。最多でも1本なので中心とは言えない。
      const shots = [
        ShotType.forehand,
        ShotType.backhand,
        ShotType.volley,
        ShotType.smash,
        ShotType.lob,
      ];
      final points = [
        for (var i = 0; i < shots.length; i++)
          _point(
            pointNumber: i + 1,
            pointWinner: 'team1',
            pointType: PointType.winner,
            shotType: shots[i],
            actionPlayer: '山田',
          ),
        _point(
          pointNumber: 6,
          pointWinner: 'team2',
          pointType: PointType.opponentError,
          shotType: ShotType.backhand,
          actionPlayer: '佐藤',
        ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      expect(report.summary, 'ウィナー5本・ミス1本。取れているほうが多い。');
      expect(report.summary, isNot(contains('1本）')));
    });

    test('本数が少ないうちは一言を出さない', () {
      final points = [
        for (var i = 1; i <= 3; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            actionPlayer: '佐藤',
          ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      expect(report.summary, isNull);
      // Bad行のほうは出る
      expect(report.players[1].bad, isNotNull);
    });

    test('励ましや指示の言葉は入れない', () {
      final points = [
        for (var i = 1; i <= 5; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            actionPlayer: '佐藤',
          ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      for (final word in ['ましょう', '意識', '頑張', '耐え']) {
        expect(report.summary, isNot(contains(word)));
        expect(report.players[1].bad, isNot(contains(word)));
      }
    });

    test('本数が少なければ何も言わない', () {
      final points = [
        for (var i = 1; i <= 2; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            actionPlayer: '佐藤',
          ),
      ];

      final report =
          PairReport.build(_stats(points), playerNames: ['山田', '佐藤']);

      expect(report.hasContent, isFalse);
    });

    test('選手名を渡さなければ記録から本数の多い順に2人を使う', () {
      final points = [
        for (var i = 1; i <= 4; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team2',
            pointType: PointType.opponentError,
            shotType: ShotType.backhand,
            actionPlayer: '佐藤',
          ),
        for (var i = 5; i <= 7; i++)
          _point(
            pointNumber: i,
            pointWinner: 'team1',
            pointType: PointType.winner,
            shotType: ShotType.smash,
            actionPlayer: '山田',
          ),
      ];

      final report = PairReport.build(_stats(points));

      expect(report.players.map((p) => p.name), ['佐藤', '山田']);
    });
  });
}
