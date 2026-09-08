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
  String? shotType,
  String? errorType,
}) =>
    PointDetail(
      matchId: 1,
      gameNumber: gameNumber,
      pointNumber: pointNumber,
      serverTeam: serverTeam,
      firstServeIn: firstServeIn,
      pointWinner: pointWinner,
      pointType: pointType,
      shotType: shotType,
      errorType: errorType,
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

    test('3-3で終わったら「次がファイナル」を出す', () {
      final input = _input(
        gameScores: [
          _game(1, 4, 0, winner: 'team1'),
          _game(2, 0, 4, winner: 'team2'),
          _game(3, 4, 0, winner: 'team1'),
          _game(4, 0, 4, winner: 'team2'),
          _game(5, 4, 0, winner: 'team1'),
          _game(6, 0, 4, winner: 'team2'),
        ],
        pointDetails: [
          _point(
              gameNumber: 6,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
        ],
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'before_final_game');
      expect(advice?.facts['ゲームカウント'], '3-3');
    });

    test('連続失点は次がファイナルより優先される', () {
      final input = _input(
        gameScores: [
          _game(1, 4, 0, winner: 'team1'),
          _game(2, 0, 4, winner: 'team2'),
          _game(3, 4, 0, winner: 'team1'),
          _game(4, 0, 4, winner: 'team2'),
          _game(5, 4, 0, winner: 'team1'),
          _game(6, 0, 4, winner: 'team2'),
        ],
        pointDetails: [
          for (var i = 1; i <= 4; i++)
            _point(
                gameNumber: 6,
                pointNumber: i,
                serverTeam: 'team2',
                pointWinner: 'team2'),
        ],
      );

      expect(LiveCoachEngine.advise(input)?.key, 'loss_streak');
    });

    test('あとがない側の助言は、あと1ゲームで勝てる助言より優先される', () {
      final input = _input(
        gameScores: [
          _game(1, 0, 4, winner: 'team2'),
          _game(2, 0, 4, winner: 'team2'),
          _game(3, 0, 4, winner: 'team2'),
        ],
        pointDetails: [
          _point(
              gameNumber: 3,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
        ],
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'facing_match_game');
      expect(advice?.facts['ゲームカウント'], '0-3');
    });

    test('あと1ゲームで勝てるときは取り切る助言を出す', () {
      final input = _input(
        gameScores: [
          _game(1, 4, 0, winner: 'team1'),
          _game(2, 4, 0, winner: 'team1'),
          _game(3, 4, 0, winner: 'team1'),
        ],
        pointDetails: [
          _point(
              gameNumber: 3,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
        ],
      );

      expect(LiveCoachEngine.advise(input)?.key, 'game_to_win');
    });

    test('自分がチーム2のときはゲームカウントも自分側の視点で数える', () {
      final input = _input(
        gameScores: [
          _game(1, 4, 0, winner: 'team1'),
          _game(2, 4, 0, winner: 'team1'),
        ],
        pointDetails: [
          _point(
              gameNumber: 2,
              pointNumber: 1,
              serverTeam: 'team2',
              pointWinner: 'team1'),
        ],
        myTeam: 'team2',
      );

      final advice = LiveCoachEngine.advise(input);
      expect(advice?.key, 'behind');
      expect(advice?.facts['ゲームカウント'], '0-2');
    });

    test('1ゲームも終わっていなければゲームカウントの助言は出さない', () {
      final input = _input(
        gameScores: [_game(1, 3, 3)],
        pointDetails: [
          _point(
              gameNumber: 1,
              pointNumber: 1,
              serverTeam: 'team1',
              pointWinner: 'team1'),
        ],
      );

      expect(LiveCoachEngine.advise(input), isNull);
    });
  });

  group('LiveCoachEngine 球種・ミスの種類', () {
    /// 自分たちのミスによる失点を作る
    List<PointDetail> ownErrors({
      required int count,
      String? shotType,
      String? errorType,
      int startAt = 1,
    }) =>
        [
          for (var i = 0; i < count; i++)
            _point(
              gameNumber: 1 + ((startAt + i) ~/ 4),
              pointNumber: startAt + i,
              serverTeam: 'team2',
              pointWinner: 'team2',
              pointType: PointType.opponentError,
              shotType: shotType,
              errorType: errorType,
            ),
        ];

    test('特定の球種にミスが偏っていれば指摘する', () {
      final points = [
        ...ownErrors(count: 5, shotType: ShotType.backhand, errorType: ErrorType.net),
        ...ownErrors(
            count: 4,
            shotType: ShotType.forehand,
            errorType: ErrorType.out,
            startAt: 6),
      ];

      final advices = LiveCoachEngine.evaluate(_input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 4, winner: 'team2')],
        pointDetails: points,
        detailMode: true,
      ));

      final shot = advices.firstWhere((a) => a.key == 'error_shot_concentrated');
      expect(shot.facts['崩れている球種'], 'バックハンド');
      expect(shot.facts['その球種でのミス'], '5本');
      expect(shot.facts['入力済みのミス'], '9本');
    });

    test('球種が未入力のぶんは母数に数えない', () {
      // 入力済みはバックハンド3本だけ。8本に届かないので出さない。
      final points = [
        ...ownErrors(count: 3, shotType: ShotType.backhand),
        ...ownErrors(count: 9, startAt: 4),
      ];

      final keys = LiveCoachEngine.evaluate(_input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 4, winner: 'team2')],
        pointDetails: points,
        detailMode: true,
      )).map((a) => a.key);

      expect(keys, isNot(contains('error_shot_concentrated')));
    });

    test('ネットが多いときとアウトが多いときで直し方を変える', () {
      final net = LiveCoachEngine.evaluate(_input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 4, winner: 'team2')],
        pointDetails: ownErrors(count: 8, errorType: ErrorType.net),
        detailMode: true,
      )).firstWhere((a) => a.key == 'error_type_concentrated');
      expect(net.template, contains('軌道を少し上げて'));

      final out = LiveCoachEngine.evaluate(_input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 4, winner: 'team2')],
        pointDetails: ownErrors(count: 8, errorType: ErrorType.out),
        detailMode: true,
      )).firstWhere((a) => a.key == 'error_type_concentrated');
      expect(out.template, contains('回転をかけて'));
    });

    test('決まっている球種は強みとして出す', () {
      final points = [
        for (var i = 1; i <= 5; i++)
          _point(
            gameNumber: 1,
            pointNumber: i,
            serverTeam: 'team1',
            pointWinner: 'team1',
            pointType: PointType.winner,
            shotType: ShotType.smash,
          ),
      ];

      final advice = LiveCoachEngine.evaluate(_input(
        gameScores: [_game(1, 4, 0, winner: 'team1')],
        pointDetails: points,
        detailMode: true,
      )).firstWhere((a) => a.key == 'winner_shot_strength');

      expect(advice.facts['決まっている球種'], 'スマッシュ');
      expect(advice.template, contains('スマッシュで5本決まっています'));
    });

    test('詳細モードでなければ球種は見ない', () {
      final keys = LiveCoachEngine.evaluate(_input(
        gameScores: [_game(1, 0, 4, winner: 'team2'), _game(2, 0, 4, winner: 'team2')],
        pointDetails: ownErrors(count: 10, shotType: ShotType.backhand),
      )).map((a) => a.key);

      expect(keys, isNot(contains('error_shot_concentrated')));
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
