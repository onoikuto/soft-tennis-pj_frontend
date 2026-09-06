import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/live_coach_engine.dart';
import 'package:soft_tennis_scoring/services/live_coach_service.dart';

/// 7ゲームマッチの試合を作る
Match _match() => Match(
      id: 1,
      tournamentName: 'テスト大会',
      team1Player1: '山田',
      team1Player2: '佐藤',
      team1Club: 'A高校',
      team2Player1: '鈴木',
      team2Player2: '高橋',
      team2Club: 'B高校',
      gameCount: 7,
      firstServe: 'team1',
      createdAt: DateTime(2026, 1, 1),
    );

GameScore _game(
  int number,
  int team1,
  int team2, {
  String? winner,
  String serviceTeam = 'team1',
}) =>
    GameScore(
      matchId: 1,
      gameNumber: number,
      team1Score: team1,
      team2Score: team2,
      serviceTeam: serviceTeam,
      winner: winner,
    );

PointDetail _point({
  required int gameNumber,
  required int pointNumber,
  required String serverTeam,
  required String pointWinner,
  bool firstServeIn = true,
  String pointType = PointType.opponentError,
}) =>
    PointDetail(
      matchId: 1,
      gameNumber: gameNumber,
      pointNumber: pointNumber,
      serverTeam: serverTeam,
      firstServeIn: firstServeIn,
      pointWinner: pointWinner,
      pointType: pointType,
      createdAt: DateTime(2026, 1, 1),
    );

LiveCoachInput _input({
  required List<GameScore> gameScores,
  required List<PointDetail> pointDetails,
  bool detailMode = false,
  String myTeam = 'team1',
}) =>
    LiveCoachInput(
      match: _match(),
      gameScores: gameScores,
      pointDetails: pointDetails,
      myTeam: myTeam,
      detailMode: detailMode,
    );

void main() {
  group('LiveCoachEngine', () {
    test('序盤で材料がなければ何も言わない', () {
      final input = _input(
        gameScores: [_game(1, 1, 1)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
          _point(
              gameNumber: 1,
              pointNumber: 2,
              serverTeam: 'team1',
              pointWinner: 'team2'),
        ],
      );

      expect(LiveCoachEngine.advise(input), isNull);
    });

    test('3本連続で失点すると流れを切る助言が最優先で出る', () {
      final input = _input(
        gameScores: [_game(1, 0, 3)],
        pointDetails: [
          for (var i = 1; i <= 3; i++)
            _point(
                gameNumber: 1,
                pointNumber: i,
                serverTeam: 'team1',
                pointWinner: 'team2'),
        ],
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'loss_streak');
      expect(advice?.facts['連続失点'], '3本');
    });

    test('1stサーブが半分も入っていなければ指摘する', () {
      final input = _input(
        gameScores: [_game(1, 2, 2)],
        pointDetails: [
          // 自分のサーブ4本のうち入ったのは1本。失点は連続させない。
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team2',
              firstServeIn: false),
          _point(
              gameNumber: 1,
              pointNumber: 2,
              serverTeam: 'team1',
              pointWinner: 'team1',
              firstServeIn: false),
          _point(
              gameNumber: 1,
              pointNumber: 3,
              serverTeam: 'team1',
              pointWinner: 'team2',
              firstServeIn: false),
          _point(
              gameNumber: 1,
              pointNumber: 4,
              serverTeam: 'team1',
              pointWinner: 'team1',
              firstServeIn: true),
        ],
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'first_serve_low');
      expect(advice?.facts['1stサーブ成功率'], '25%');
    });

    test('サーブ本数が3本以下なら成功率では判断しない', () {
      final input = _input(
        gameScores: [_game(1, 1, 2)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team2',
              firstServeIn: false),
          _point(
              gameNumber: 1,
              pointNumber: 2,
              serverTeam: 'team1',
              pointWinner: 'team1',
              firstServeIn: false),
          _point(
              gameNumber: 1,
              pointNumber: 3,
              serverTeam: 'team1',
              pointWinner: 'team2',
              firstServeIn: false),
        ],
      );

      final keys = LiveCoachEngine.evaluate(input).map((a) => a.key);
      expect(keys, isNot(contains('first_serve_low')));
    });

    test('相手のサーブは自分の1stサーブ成功率に混ぜない', () {
      final input = _input(
        gameScores: [_game(1, 2, 2)],
        pointDetails: [
          for (var i = 1; i <= 4; i++)
            _point(
                gameNumber: 1,
                pointNumber: i,
                serverTeam: 'team2',
                pointWinner: i.isEven ? 'team1' : 'team2',
                firstServeIn: false),
        ],
      );

      final keys = LiveCoachEngine.evaluate(input).map((a) => a.key);
      expect(keys, isNot(contains('first_serve_low')));
    });

    test('詳細モードでないときはミスの内訳を見ない', () {
      // 詳細モードOFFでは pointType に既定値が入るだけなので、
      // 「失点はすべて自分たちのミス」と誤って判定してはいけない。
      final points = [
        for (var i = 1; i <= 12; i++)
          _point(
              gameNumber: 1 + (i ~/ 4),
              pointNumber: i,
              serverTeam: i.isEven ? 'team1' : 'team2',
              pointWinner: 'team2'),
      ];

      final off = _input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 3)],
        pointDetails: points,
      );
      expect(
        LiveCoachEngine.evaluate(off).map((a) => a.key),
        isNot(contains('own_error_high')),
      );

      final on = _input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 3)],
        pointDetails: points,
        detailMode: true,
      );
      expect(
        LiveCoachEngine.evaluate(on).map((a) => a.key),
        contains('own_error_high'),
      );
    });

    test('ファイナルゲームは連続失点の次に優先される', () {
      final input = _input(
        gameScores: [
          _game(1, 4, 0, winner: 'team1'),
          _game(2, 0, 4, winner: 'team2'),
          _game(3, 4, 0, winner: 'team1'),
          _game(4, 0, 4, winner: 'team2'),
          _game(5, 4, 0, winner: 'team1'),
          _game(6, 0, 4, winner: 'team2'),
          _game(7, 3, 2),
        ],
        pointDetails: [
          _point(
              gameNumber: 7,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
        ],
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'final_game');
      expect(advice?.facts['ポイント'], '3-2');
    });

    test('相手のゲームポイントは自分のゲームポイントより優先される', () {
      final input = _input(
        gameScores: [_game(1, 1, 3)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
          _point(
              gameNumber: 1,
              pointNumber: 2,
              serverTeam: 'team1',
              pointWinner: 'team2'),
        ],
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'facing_game_point');
    });

    test('自分がチーム2のときは自分側の視点で判定する', () {
      final input = _input(
        gameScores: [_game(1, 3, 1)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team2',
              pointWinner: 'team2'),
          _point(
              gameNumber: 1,
              pointNumber: 2,
              serverTeam: 'team2',
              pointWinner: 'team1'),
        ],
        myTeam: 'team2',
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'facing_game_point');
      expect(advice?.facts['ポイント'], '1-3');
    });

    test('デュースは3-3以上の同点で出る', () {
      final input = _input(
        gameScores: [_game(1, 4, 4)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
        ],
      );

      expect(LiveCoachEngine.advise(input)?.key, 'deuce');
    });
  });

  group('LiveCoachService.sanitize', () {
    test('前置きや箇条書きを落として1文にする', () {
      expect(
        LiveCoachService.sanitize('- 1stサーブを確実に入れていきましょう。'),
        '1stサーブを確実に入れていきましょう。',
      );
    });

    test('長すぎる出力は捨てる（定型文に戻すため）', () {
      expect(LiveCoachService.sanitize('あ' * 200), isNull);
    });

    test('日本語が含まれない出力は捨てる', () {
      expect(LiveCoachService.sanitize('Sure! Here is the advice:'), isNull);
    });

    test('空やnullはnullのまま', () {
      expect(LiveCoachService.sanitize(null), isNull);
      expect(LiveCoachService.sanitize('   \n  '), isNull);
    });
  });

  group('LiveCoachService.advise', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      LiveCoachService.resetForTest();
    });

    test('課金していれば定型文の助言が返る（端末内LLMなしでも動く）', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': true});

      final input = _input(
        gameScores: [_game(1, 0, 3)],
        pointDetails: [
          for (var i = 1; i <= 3; i++)
            _point(
                gameNumber: 1,
                pointNumber: i,
                serverTeam: 'team1',
                pointWinner: 'team2'),
        ],
      );

      final update = await LiveCoachService.advise(input);
      expect(update.message, isNotNull);
      expect(update.message!.key, 'loss_streak');
      expect(update.message!.phrasedByAi, isFalse);
      expect(update.message!.text, contains('3本連続で失点'));
    });

    test('課金していなければ何も返さない', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': false});

      final input = _input(
        gameScores: [_game(1, 0, 3)],
        pointDetails: [
          for (var i = 1; i <= 3; i++)
            _point(
                gameNumber: 1,
                pointNumber: i,
                serverTeam: 'team1',
                pointWinner: 'team2'),
        ],
      );

      final update = await LiveCoachService.advise(input);
      expect(update.message, isNull);
      expect(update.keepCurrent, isFalse);
    });

    test('同じ助言を続けて求めても、間隔が空くまでは出し直さない', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': true});

      final input = _input(
        gameScores: [_game(1, 0, 3)],
        pointDetails: [
          for (var i = 1; i <= 3; i++)
            _point(
                gameNumber: 1,
                pointNumber: i,
                serverTeam: 'team1',
                pointWinner: 'team2'),
        ],
      );

      expect((await LiveCoachService.advise(input)).message, isNotNull);

      final second = await LiveCoachService.advise(input);
      expect(second.message, isNull);
      // 表示は消さずに残す
      expect(second.keepCurrent, isTrue);
    });

    test('出す助言がなくなったら表示を消す指示になる', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': true});

      final input = _input(
        gameScores: [_game(1, 1, 1)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
          _point(
              gameNumber: 1,
              pointNumber: 2,
              serverTeam: 'team1',
              pointWinner: 'team2'),
        ],
      );

      final update = await LiveCoachService.advise(input);
      expect(update.message, isNull);
      expect(update.keepCurrent, isFalse);
    });
  });

  group('LiveCoachService.buildPrompt', () {
    test('選んだ助言と根拠だけを渡す', () {
      const advice = LiveAdvice(
        key: 'first_serve_low',
        headline: '1stを入れる',
        template: '1stサーブの確率が25%です。',
        priority: 80,
        facts: {'1stサーブ成功率': '25%'},
      );

      final prompt = LiveCoachService.buildPrompt(advice);
      expect(prompt, contains('1stサーブの確率が25%です。'));
      expect(prompt, contains('- 1stサーブ成功率: 25%'));
    });
  });
}
