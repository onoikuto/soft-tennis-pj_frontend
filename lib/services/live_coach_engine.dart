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
    _addShotAdvice(input, advices);
    _addGameBreakAdvice(input, advices);

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

  /// 球種・ミスの種類からの助言
  ///
  /// 詳細入力モードで、かつ選手が入力をスキップしなかったぶんだけ見ます
  /// （どちらも任意入力なので、未入力を「無かったこと」と数えないよう
  /// 入力済みの件数を母数にします）。
  static void _addShotAdvice(LiveCoachInput input, List<LiveAdvice> out) {
    if (!input.detailMode) return;

    // 自分たちのミスによる失点
    final ownErrors = input.pointDetails
        .where((p) =>
            p.pointWinner == input.opponentTeam &&
            p.pointType == PointType.opponentError)
        .toList();

    // どの球種で崩れているか
    final shots = _countBy(ownErrors, (p) => p.shotType);
    final topShot = _mostCommon(shots);
    // 入力済み8本以上・その球種が半分以上でないと、偏りとは言えない
    if (topShot != null && shots.total >= 8 && topShot.count * 2 >= shots.total) {
      final label = ShotType.getDisplay(topShot.key);
      out.add(LiveAdvice(
        key: 'error_shot_concentrated',
        headline: '$labelを整える',
        template: 'ミスの${topShot.count}本が$labelです。'
            'この球はいったん確実に返すことを優先しましょう。',
        priority: 75,
        facts: {
          '崩れている球種': label,
          'その球種でのミス': '${topShot.count}本',
          '入力済みのミス': '${shots.total}本',
        },
      ));
    }

    // ネットかアウトか（直し方が逆になるので分けて言う）
    final errorTypes = _countBy(ownErrors, (p) => p.errorType);
    final topError = _mostCommon(errorTypes);
    if (topError != null &&
        errorTypes.total >= 8 &&
        topError.count * 5 >= errorTypes.total * 3) {
      final advice = switch (topError.key) {
        ErrorType.net => '軌道を少し上げて、ネットの上を通す幅を作りましょう。',
        ErrorType.out => '振り切らず、回転をかけて中に収めましょう。',
        _ => '2ndサーブは確実さを優先しましょう。',
      };
      final label = ErrorType.getDisplay(topError.key);
      out.add(LiveAdvice(
        key: 'error_type_concentrated',
        headline: '$labelが多い',
        template: 'ミスの${topError.count}本が$labelです。$advice',
        priority: 72,
        facts: {
          '多いミス': label,
          'その本数': '${topError.count}本',
          '入力済みのミス': '${errorTypes.total}本',
        },
      ));
    }

    // 決まっている球種（伸ばすところも言う）
    final winners = input.pointDetails
        .where((p) =>
            p.pointWinner == input.myTeam && p.pointType == PointType.winner)
        .toList();
    final winnerShots = _countBy(winners, (p) => p.shotType);
    final topWinner = _mostCommon(winnerShots);
    if (topWinner != null &&
        winnerShots.total >= 5 &&
        topWinner.count * 2 >= winnerShots.total) {
      final label = ShotType.getDisplay(topWinner.key);
      out.add(LiveAdvice(
        key: 'winner_shot_strength',
        headline: '$labelが効いている',
        template: '$labelで${topWinner.count}本決まっています。'
            'この形に持ち込む組み立てを続けましょう。',
        priority: 25,
        facts: {
          '決まっている球種': label,
          'その球種でのウィナー': '${topWinner.count}本',
        },
      ));
    }
  }

  /// ゲームの区切りでの、ゲームカウントに応じた助言
  ///
  /// 助言はゲームが終わったところで出します。プレー中に読ませても頭に
  /// 入らないうえ、ポイントごとに文言が変わると気が散るためです。
  /// したがって進行中のゲームは無く、見るのは**ゲームカウント**になります。
  static void _addGameBreakAdvice(LiveCoachInput input, List<LiveAdvice> out) {
    var myGames = 0;
    var theirGames = 0;
    for (final score in input.gameScores) {
      if (score.winner == null) continue;
      if (score.winner == input.myTeam) {
        myGames++;
      } else {
        theirGames++;
      }
    }
    if (myGames + theirGames == 0) return;

    final required = GameRules.requiredGamesToWin(input.match.gameCount);
    final count = '$myGames-$theirGames';

    // 次がファイナルゲーム（あと1ゲームずつで決まる並び）
    if (myGames == required - 1 && theirGames == required - 1) {
      out.add(LiveAdvice(
        key: 'before_final_game',
        headline: '次がファイナル',
        template: '$countで次がファイナルゲームです。'
            '守りに入らず、ここまで取れていた形をもう一度やりましょう。',
        priority: 90,
        facts: {'ゲームカウント': count},
      ));
      return;
    }

    // 相手にあと1ゲームで取られる
    if (theirGames == required - 1) {
      out.add(LiveAdvice(
        key: 'facing_match_game',
        headline: '後がない',
        template: '$countで、次を落とすと負けです。'
            '思い切って攻めるより、確実に1本返して長く続けましょう。',
        priority: 65,
        facts: {'ゲームカウント': count},
      ));
      return;
    }

    // あと1ゲームで勝てる
    if (myGames == required - 1) {
      out.add(LiveAdvice(
        key: 'game_to_win',
        headline: 'あと1ゲーム',
        template: '$countで、次を取れば勝ちです。'
            '新しいことは試さず、いつもどおりのサーブとコースで取り切りましょう。',
        priority: 55,
        facts: {'ゲームカウント': count},
      ));
      return;
    }

    // 2ゲーム以上離されている
    if (theirGames - myGames >= 2) {
      out.add(LiveAdvice(
        key: 'behind',
        headline: '立て直す',
        template: '$countです。取り返そうと急がず、'
            '次の1ゲームだけに集中しましょう。',
        priority: 20,
        facts: {'ゲームカウント': count},
      ));
      return;
    }

    // 2ゲーム以上リードしている
    if (myGames - theirGames >= 2) {
      out.add(LiveAdvice(
        key: 'ahead',
        headline: '緩めない',
        template: '$countとリードしています。'
            'ここで形を変えず、同じ入り方を続けましょう。',
        priority: 15,
        facts: {'ゲームカウント': count},
      ));
    }
  }

  // ============================================================================
  // 集計の補助
  // ============================================================================

  /// 未入力を除いて数えた集計結果
  static _Counts _countBy(
    List<PointDetail> points,
    String? Function(PointDetail) selector,
  ) {
    final counts = <String, int>{};
    var total = 0;
    for (final point in points) {
      final key = selector(point);
      // 任意入力なので、未入力は母数からも除く
      if (key == null || key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      total++;
    }
    return _Counts(counts, total);
  }

  /// 一番多かった項目（同数のときは名前順で安定させる）
  static _Entry? _mostCommon(_Counts counts) {
    _Entry? best;
    final keys = counts.map.keys.toList()..sort();
    for (final key in keys) {
      final count = counts.map[key]!;
      if (best == null || count > best.count) best = _Entry(key, count);
    }
    return best;
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

/// 項目ごとの件数と、その合計（未入力を除いたもの）
class _Counts {
  final Map<String, int> map;
  final int total;

  const _Counts(this.map, this.total);
}

/// 一番多かった項目
class _Entry {
  final String key;
  final int count;

  const _Entry(this.key, this.count);
}
