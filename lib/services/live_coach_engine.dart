import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/utils/game_rules.dart';

/// 試合中のアドバイス1件
///
/// [template] は「そのまま画面に出せる文章」です。端末内LLMが使えるときは
/// [facts] を渡して言い回しだけ作り直しますが、失敗しても [template] が
/// 出るので、利用者には何も起きません。
class LiveAdvice {
  /// 助言の種類を表すキー（テストとログで使う）
  final String key;

  /// 見出し（10文字程度。試合中はここだけ見れば分かるようにする）
  final String headline;

  /// 定型文（LLMが使えないときはこれをそのまま表示する）
  final String template;

  /// 表示優先度（大きいほど先）
  final int priority;

  /// LLMに渡す根拠となる数値
  ///
  /// **ここに入れた値だけ**をLLMに渡します。数値の判断はルール側で終わって
  /// いるので、LLMには言い回しを整えてもらうだけです。
  final Map<String, String> facts;

  const LiveAdvice({
    required this.key,
    required this.headline,
    required this.template,
    required this.priority,
    this.facts = const {},
  });
}

/// 試合中アドバイスの入力データ
class LiveCoachInput {
  final Match match;

  /// 保存済みのゲームスコア（進行中のゲームを含む）
  final List<GameScore> gameScores;

  /// この試合のポイント詳細（古い順）
  final List<PointDetail> pointDetails;

  /// 自分側のチーム（'team1' / 'team2'）
  final String myTeam;

  /// 詳細入力モードで記録されているか
  ///
  /// 詳細モードがOFFのとき [PointDetail.pointType] は既定値の
  /// `opponent_error` が入るだけで、実際の内容ではありません。
  /// ミスやウィナーを見る判定は、このフラグが立っているときだけ行います。
  final bool detailMode;

  const LiveCoachInput({
    required this.match,
    required this.gameScores,
    required this.pointDetails,
    required this.myTeam,
    required this.detailMode,
  });

  String get opponentTeam => myTeam == 'team1' ? 'team2' : 'team1';
}

/// 試合の進行中に、いま出すべき助言をルールで選ぶエンジン
///
/// LLMは使いません。**何を言うかはここで決め切ります。** 小さなモデルに
/// 数値の判断まで任せると、根拠のない助言が出てしまうためです。
/// LLMの役割は、ここで選んだ助言の言い回しを整えることだけです。
///
/// サンプル数が少ない指標では助言を出しません（1本外しただけで
/// 「サーブが不調です」と言われても困るため）。
class LiveCoachEngine {
  LiveCoachEngine._(); // インスタンス化を防ぐ

  /// いま出すべき助言を1件返す（何もないときはnull）
  static LiveAdvice? advise(LiveCoachInput input) {
    final all = evaluate(input);
    return all.isEmpty ? null : all.first;
  }

  /// 当てはまる助言を優先度順にすべて返す（テスト用）
  static List<LiveAdvice> evaluate(LiveCoachInput input) {
    final advices = <LiveAdvice>[];

    _addStreakAdvice(input, advices);
    _addServeAdvice(input, advices);
    _addPointTypeAdvice(input, advices);
    _addSituationAdvice(input, advices);

    advices.sort((a, b) => b.priority.compareTo(a.priority));
    return advices;
  }

  // ============================================================================
  // 個別のルール
  // ============================================================================

  /// 連続失点への助言
  ///
  /// 試合中に一番効くのは「流れが相手に行っていることに気づかせる」ことなので、
  /// 最優先で出します。
  static void _addStreakAdvice(LiveCoachInput input, List<LiveAdvice> out) {
    final streak = _currentLossStreak(input);
    if (streak < 3) return;

    out.add(LiveAdvice(
      key: 'loss_streak',
      headline: '流れを切る',
      template: '$streak本連続で失点しています。一度呼吸を整えて、'
          '次の1本は確実に返すことだけを考えましょう。',
      priority: 100,
      facts: {'連続失点': '$streak本'},
    ));
  }

  /// 1stサーブの成功率への助言
  static void _addServeAdvice(LiveCoachInput input, List<LiveAdvice> out) {
    final serves = input.pointDetails
        .where((p) => p.serverTeam == input.myTeam)
        .toList();
    // 4本未満では、たまたま外しただけと区別できない
    if (serves.length < 4) return;

    final inCount = serves.where((p) => p.firstServeIn).length;
    final rate = inCount / serves.length;
    final percent = (rate * 100).round();

    if (rate < 0.5) {
      out.add(LiveAdvice(
        key: 'first_serve_low',
        headline: '1stを入れる',
        template: '1stサーブの確率が$percent%です。'
            'スピードを少し落として、入れることを優先しましょう。',
        priority: 80,
        facts: {'1stサーブ成功率': '$percent%', '本数': '${serves.length}本'},
      ));
      return;
    }

    // サーブは入っているのにポイントが取れていない場合
    final serveWon = serves.where((p) => p.pointWinner == input.myTeam).length;
    final serveWinRate = serveWon / serves.length;
    if (serves.length >= 6 && serveWinRate < 0.4) {
      out.add(LiveAdvice(
        key: 'serve_game_weak',
        headline: 'サーブ後を作る',
        template: 'サーブ側で取れているのが${(serveWinRate * 100).round()}%です。'
            'サーブのあとの1本目をどこに集めるか、ペアで決めてから入りましょう。',
        priority: 60,
        facts: {
          'サーブ側ポイント取得率': '${(serveWinRate * 100).round()}%',
          '本数': '${serves.length}本',
        },
      ));
    }
  }

  /// ウィナー・ミスの内訳への助言
  ///
  /// 詳細入力モードでないと中身が入らないため、そのときだけ見ます。
  static void _addPointTypeAdvice(LiveCoachInput input, List<LiveAdvice> out) {
    if (!input.detailMode) return;

    final lost = input.pointDetails
        .where((p) => p.pointWinner == input.opponentTeam)
        .toList();
    // 10本未満だと内訳の偏りが読めない
    if (lost.length < 10) return;

    // 相手から見た「相手のミス」＝こちらのミスによる失点
    final ownErrors =
        lost.where((p) => p.pointType == PointType.opponentError).length;
    final rate = ownErrors / lost.length;
    if (rate >= 0.6) {
      out.add(LiveAdvice(
        key: 'own_error_high',
        headline: 'ミスを減らす',
        template: '失点の${(rate * 100).round()}%が自分たちのミスです。'
            '無理に決めにいかず、1本多く返すことを意識しましょう。',
        priority: 70,
        facts: {
          '自分たちのミスによる失点': '$ownErrors本',
          '失点': '${lost.length}本',
        },
      ));
    }
  }

  /// 局面（ファイナル・ゲームポイント・デュース）への助言
  static void _addSituationAdvice(LiveCoachInput input, List<LiveAdvice> out) {
    final current = _currentGameScore(input);
    if (current == null) return;

    final myScore =
        input.myTeam == 'team1' ? current.team1Score : current.team2Score;
    final theirScore =
        input.myTeam == 'team1' ? current.team2Score : current.team1Score;

    final isFinal = GameRules.isFinalGame(
      gameCount: input.match.gameCount,
      gameScores: input.gameScores,
      gameNumber: current.gameNumber,
    );

    if (isFinal) {
      out.add(LiveAdvice(
        key: 'final_game',
        headline: 'ファイナル',
        template: 'ファイナルゲームです。$myScore-$theirScoreの場面、'
            '守りに入らず、これまで取れていた形をもう一度やりましょう。',
        priority: 90,
        facts: {'ポイント': '$myScore-$theirScore'},
      ));
      return;
    }

    // 相手のゲームポイント（4ポイント先取・2点差。デュース以降も含む）
    if (theirScore >= 3 && theirScore - myScore >= 1) {
      out.add(LiveAdvice(
        key: 'facing_game_point',
        headline: '踏ん張る',
        template: '相手のゲームポイントです。'
            '思い切って攻めるより、確実に1本返して長く続けましょう。',
        priority: 50,
        facts: {'ポイント': '$myScore-$theirScore'},
      ));
      return;
    }

    if (myScore >= 3 && myScore - theirScore >= 1) {
      out.add(LiveAdvice(
        key: 'game_point',
        headline: '取り切る',
        template: 'ゲームポイントです。'
            '新しいことは試さず、いつもどおりのサーブとコースで取り切りましょう。',
        priority: 40,
        facts: {'ポイント': '$myScore-$theirScore'},
      ));
      return;
    }

    if (myScore >= 3 && myScore == theirScore) {
      out.add(LiveAdvice(
        key: 'deuce',
        headline: 'デュース',
        template: 'デュースです。ここは1本ずつ。'
            '次のポイントをどう組み立てるか、ペアで一言だけ確認しましょう。',
        priority: 30,
        facts: {'ポイント': '$myScore-$theirScore'},
      ));
    }
  }

  // ============================================================================
  // 集計の補助
  // ============================================================================

  /// 進行中のゲーム（勝者が未確定のもの）
  static GameScore? _currentGameScore(LiveCoachInput input) {
    for (final score in input.gameScores.reversed) {
      if (score.winner == null) return score;
    }
    return null;
  }

  /// いま何本連続で失点しているか
  static int _currentLossStreak(LiveCoachInput input) {
    var streak = 0;
    for (final point in input.pointDetails.reversed) {
      if (point.pointWinner == input.myTeam) break;
      streak++;
    }
    return streak;
  }
}
