import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/live_coach_engine.dart';
import 'package:soft_tennis_scoring/services/live_coach_service.dart';

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

GameScore _game(int number, int team1, int team2, {String? winner}) => GameScore(
      matchId: 1,
      gameNumber: number,
      team1Score: team1,
      team2Score: team2,
      serviceTeam: 'team1',
      winner: winner,
    );

PointDetail _point({
  int gameNumber = 1,
  int pointNumber = 1,
  String serverTeam = 'team1',
  required String pointWinner,
  bool firstServeIn = true,
  String pointType = PointType.opponentError,
  String? shotType,
  String? courseType,
  String? errorType,
  String? actionPlayer,
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
      courseType: courseType,
      errorType: errorType,
      actionPlayer: actionPlayer,
      createdAt: DateTime(2026, 1, 1),
    );

LiveCoachInput _input({
  List<GameScore>? gameScores,
  required List<PointDetail> pointDetails,
  bool detailMode = true,
  String myTeam = 'team1',
}) =>
    LiveCoachInput(
      match: _match(),
      gameScores: gameScores ?? [_game(1, 0, 4, winner: 'team2')],
      pointDetails: pointDetails,
      myTeam: myTeam,
      detailMode: detailMode,
    );

/// 自分たちのミスによる失点をまとめて作る
List<PointDetail> _ownErrors({
  required int count,
  String? shotType,
  String? courseType,
  String? errorType,
  String? actionPlayer,
  int startAt = 1,
}) =>
    [
      for (var i = 0; i < count; i++)
        _point(
          pointNumber: startAt + i,
          serverTeam: 'team2',
          pointWinner: 'team2',
          pointType: PointType.opponentError,
          shotType: shotType,
          courseType: courseType,
          errorType: errorType,
          actionPlayer: actionPlayer,
        ),
    ];

/// 自分たちのウィナーをまとめて作る
List<PointDetail> _winners({
  required int count,
  String? shotType,
  String? courseType,
  String? actionPlayer,
  int startAt = 1,
}) =>
    [
      for (var i = 0; i < count; i++)
        _point(
          pointNumber: startAt + i,
          serverTeam: 'team1',
          pointWinner: 'team1',
          pointType: PointType.winner,
          shotType: shotType,
          courseType: courseType,
          actionPlayer: actionPlayer,
        ),
    ];

void main() {
  group('LiveCoachEngine 失点の傾向', () {
    test('球種とコースを続けて言う', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: _ownErrors(
          count: 5,
          shotType: ShotType.backhand,
          courseType: CourseType.straightRight,
        ),
      )).firstWhere((a) => a.key == 'conceding_pattern');

      expect(advice.template, contains('バックハンドで5失点。'));
      expect(advice.template, contains('右ストレート展開で失点しやすい。'));
      expect(advice.isGood, isFalse);
    });

    test('励ましや指示の言葉を含めない', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: _ownErrors(
          count: 5,
          shotType: ShotType.backhand,
          courseType: CourseType.cross,
        ),
      )).firstWhere((a) => a.key == 'conceding_pattern');

      for (final word in ['ましょう', '意識', '頑張', '耐え', '取り切']) {
        expect(advice.template, isNot(contains(word)));
      }
    });

    test('ひとりに偏っていれば選手名を添える', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          ..._ownErrors(
              count: 4, shotType: ShotType.backhand, actionPlayer: '佐藤'),
          ..._ownErrors(
              count: 1,
              shotType: ShotType.backhand,
              actionPlayer: '山田',
              startAt: 5),
        ],
      )).firstWhere((a) => a.key == 'conceding_pattern');

      expect(advice.template, startsWith('佐藤はバックハンドで5失点。'));
      expect(advice.facts['主に打った選手'], '佐藤');
    });

    test('ふたりで分かれていれば選手名は出さない', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          ..._ownErrors(
              count: 2, shotType: ShotType.backhand, actionPlayer: '佐藤'),
          ..._ownErrors(
              count: 2,
              shotType: ShotType.backhand,
              actionPlayer: '山田',
              startAt: 3),
        ],
      )).firstWhere((a) => a.key == 'conceding_pattern');

      expect(advice.template, startsWith('バックハンドで4失点。'));
      expect(advice.facts.containsKey('主に打った選手'), isFalse);
    });

    test('球種が未入力ならコースだけを言う', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: _ownErrors(count: 4, courseType: CourseType.reverseCross),
      )).firstWhere((a) => a.key == 'conceding_pattern');

      expect(advice.template, '逆クロス展開で失点しやすい。');
    });

    test('入力が少なければ何も言わない', () {
      final advices = LiveCoachEngine.evaluate(_input(
        pointDetails: _ownErrors(count: 3, shotType: ShotType.backhand),
      ));

      expect(advices.map((a) => a.key), isNot(contains('conceding_pattern')));
    });

    test('詳細モードでなければ球種もコースも見ない', () {
      final advices = LiveCoachEngine.evaluate(_input(
        pointDetails: _ownErrors(count: 8, shotType: ShotType.backhand),
        detailMode: false,
      ));

      expect(advices.map((a) => a.key), isNot(contains('conceding_pattern')));
    });
  });

  group('LiveCoachEngine 得点の傾向', () {
    test('得点側の傾向も同じ形で出す', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: _winners(
          count: 5,
          shotType: ShotType.smash,
          courseType: CourseType.cross,
        ),
      )).firstWhere((a) => a.key == 'scoring_pattern');

      expect(advice.template, 'スマッシュで5得点。クロス展開で得点しやすい。');
      expect(advice.isGood, isTrue);
    });

    test('失点の傾向のほうが先に出る', () {
      final advice = LiveCoachEngine.advise(_input(
        pointDetails: [
          ..._ownErrors(count: 5, shotType: ShotType.backhand),
          ..._winners(count: 5, shotType: ShotType.smash, startAt: 6),
        ],
      ));

      expect(advice?.key, 'conceding_pattern');
    });

    test('相手のミスによる得点は自分の得点パターンに数えない', () {
      final advices = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          for (var i = 1; i <= 6; i++)
            _point(
              pointNumber: i,
              pointWinner: 'team1',
              pointType: PointType.opponentError,
              shotType: ShotType.smash,
            ),
        ],
      ));

      expect(advices.map((a) => a.key), isNot(contains('scoring_pattern')));
    });

    test('自分がチーム2のときは自分側の得点を見る', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          for (var i = 1; i <= 5; i++)
            _point(
              pointNumber: i,
              pointWinner: 'team2',
              pointType: PointType.winner,
              shotType: ShotType.volley,
            ),
        ],
        myTeam: 'team2',
      )).firstWhere((a) => a.key == 'scoring_pattern');

      expect(advice.template, contains('ボレーで5得点。'));
    });
  });

  group('LiveCoachEngine ミスの種類と1stサーブ', () {
    test('ミスの内訳が偏っていれば本数で言う', () {
      final advice = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          ..._ownErrors(count: 5, errorType: ErrorType.net),
          ..._ownErrors(count: 2, errorType: ErrorType.out, startAt: 6),
        ],
      )).firstWhere((a) => a.key == 'error_type_ratio');

      expect(advice.template, 'ミス7本のうち5本がネット。');
    });

    test('1stサーブは低いときだけ本数で言う', () {
      final low = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          for (var i = 1; i <= 6; i++)
            _point(
              pointNumber: i,
              serverTeam: 'team1',
              pointWinner: i.isEven ? 'team1' : 'team2',
              firstServeIn: i <= 2,
            ),
        ],
        detailMode: false,
      )).firstWhere((a) => a.key == 'first_serve_rate');
      expect(low.template, '1stサーブは6本中2本（33%）。');

      final high = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          for (var i = 1; i <= 6; i++)
            _point(
              pointNumber: i,
              serverTeam: 'team1',
              pointWinner: i.isEven ? 'team1' : 'team2',
              firstServeIn: true,
            ),
        ],
        detailMode: false,
      )).map((a) => a.key);
      expect(high, isNot(contains('first_serve_rate')));
    });

    test('相手のサーブは自分の1stサーブに混ぜない', () {
      final keys = LiveCoachEngine.evaluate(_input(
        pointDetails: [
          for (var i = 1; i <= 8; i++)
            _point(
              pointNumber: i,
              serverTeam: 'team2',
              pointWinner: 'team2',
              firstServeIn: false,
            ),
        ],
        detailMode: false,
      )).map((a) => a.key);

      expect(keys, isNot(contains('first_serve_rate')));
    });
  });

  group('LiveCoachService.sanitize', () {
    test('前置きや箇条書きを落とす', () {
      expect(
        LiveCoachService.sanitize('- スマッシュで5得点。クロス展開で得点しやすい。'),
        'スマッシュで5得点。クロス展開で得点しやすい。',
      );
    });

    test('長すぎる出力は捨てる（定型文に戻すため）', () {
      expect(LiveCoachService.sanitize('あ' * 200), isNull);
    });

    test('日本語が含まれない出力は捨てる', () {
      expect(LiveCoachService.sanitize('Sure! Here is the summary:'), isNull);
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

    test('課金していれば定型文が返る（端末内LLMなしでも動く）', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': true});

      final update = await LiveCoachService.advise(_input(
        pointDetails: _ownErrors(count: 5, shotType: ShotType.backhand),
      ));

      expect(update.message, isNotNull);
      expect(update.message!.key, 'conceding_pattern');
      expect(update.message!.phrasedByAi, isFalse);
      expect(update.message!.isGood, isFalse);
    });

    test('課金していなければ何も返さない', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': false});

      final update = await LiveCoachService.advise(_input(
        pointDetails: _ownErrors(count: 5, shotType: ShotType.backhand),
      ));

      expect(update.message, isNull);
      expect(update.keepCurrent, isFalse);
    });

    test('同じ内容を続けて求めても、間隔が空くまでは出し直さない', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': true});
      final input =
          _input(pointDetails: _ownErrors(count: 5, shotType: ShotType.backhand));

      expect((await LiveCoachService.advise(input)).message, isNotNull);

      final second = await LiveCoachService.advise(input);
      expect(second.message, isNull);
      expect(second.keepCurrent, isTrue);
    });

    test('出すものがなくなったら表示を消す指示になる', () async {
      SharedPreferences.setMockInitialValues({'flutter.is_subscribed': true});

      final update = await LiveCoachService.advise(_input(
        pointDetails: _ownErrors(count: 2, shotType: ShotType.backhand),
      ));

      expect(update.message, isNull);
      expect(update.keepCurrent, isFalse);
    });
  });

  group('LiveCoachService.buildPrompt', () {
    test('選んだ事実と根拠だけを渡す', () {
      const advice = LiveAdvice(
        key: 'conceding_pattern',
        headline: 'バックハンド',
        template: 'バックハンドで5失点。',
        priority: 80,
        isGood: false,
        facts: {'球種': 'バックハンド', '失点': '5本'},
      );

      final prompt = LiveCoachService.buildPrompt(advice);
      expect(prompt, contains('バックハンドで5失点。'));
      expect(prompt, contains('- 球種: バックハンド'));
      expect(prompt, contains('対策や励ましは書かないでください'));
    });
  });
}
