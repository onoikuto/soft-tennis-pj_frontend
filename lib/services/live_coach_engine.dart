import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';

/// 試合中に出す気づき1件
///
/// [template] は「そのまま画面に出せる文章」です。端末内LLMが使えるときは
/// [facts] を渡して言い回しだけ作り直しますが、失敗しても [template] が
/// 出るので、利用者には何も起きません。
class LiveAdvice {
  /// 種類を表すキー（テストとログで使う）
  final String key;

  /// 見出し（試合中はここだけ見れば分かるようにする）
  final String headline;

  /// 定型文（LLMが使えないときはこれをそのまま表示する）
  final String template;

  /// 表示優先度（大きいほど先）
  final int priority;

  /// 得点側の傾向か（falseなら失点側）
  final bool isGood;

  /// LLMに渡す根拠となる数値
  ///
  /// **ここに入れた値だけ**をLLMに渡します。何を言うかはルール側で決め切って
  /// いるので、LLMには言い回しを整えてもらうだけです。
  final Map<String, String> facts;

  const LiveAdvice({
    required this.key,
    required this.headline,
    required this.template,
    required this.priority,
    required this.isGood,
    this.facts = const {},
  });
}

/// 試合中の気づきの入力データ
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
  /// 球種・コース・ミスの種類を見る判定は、このフラグが立っているときだけ
  /// 行います。
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

/// 試合中に、記録から読み取れる傾向を選ぶエンジン
///
/// **事実の指摘だけを出します。** 「取り切りましょう」「耐えましょう」の類は
/// 記録が無くても言える精神論で、記録アプリの価値になりません。ここが返すのは
/// 「何で・どれだけ・どの展開で」得点/失点したかだけです。対策はコーチと
/// 選手が決めることです。
///
/// LLMは使いません。何を言うかはここで決め切ります。LLMの役割は、ここで
/// 選んだ内容の言い回しを整えることだけです。
///
/// 入力数が少ない指標では何も言いません（2本外しただけで「バックが崩れて
/// います」と言われても困るため）。
class LiveCoachEngine {
  LiveCoachEngine._(); // インスタンス化を防ぐ

  /// 球種の偏りを指摘するのに必要な、入力済みの最少本数
  ///
  /// 1ゲームは4〜7ポイントしかなく、そのうち球種が入るのは自分たちの
  /// ウィナーとミスだけです。4本にすると2〜3ゲーム目まで何も出ません。
  static const int _minShots = 3;

  /// コースの偏りを指摘するのに必要な、入力済みの最少本数
  static const int _minCourses = 3;

  /// 1stサーブ成功率を出すのに必要な最少本数
  static const int _minServes = 6;

  /// いま出すべき気づきを1件返す（何もないときはnull）
  static LiveAdvice? advise(LiveCoachInput input) {
    final all = evaluate(input);
    return all.isEmpty ? null : all.first;
  }

  /// 当てはまる気づきを優先度順にすべて返す（テスト用）
  static List<LiveAdvice> evaluate(LiveCoachInput input) {
    final advices = <LiveAdvice>[];

    _addConcedingPattern(input, advices);
    _addScoringPattern(input, advices);
    _addFirstServeRate(input, advices);

    advices.sort((a, b) => b.priority.compareTo(a.priority));
    return advices;
  }

  // ============================================================================
  // 個別のルール
  // ============================================================================

  /// 失点の傾向（何の球で、どのコースで落としているか）
  ///
  /// 直したいのは失点なので、得点の傾向より先に出します。
  static void _addConcedingPattern(LiveCoachInput input, List<LiveAdvice> out) {
    if (!input.detailMode) return;

    // 自分たちのミスによる失点
    final lost = input.pointDetails
        .where((p) =>
            p.pointWinner == input.opponentTeam &&
            p.pointType == PointType.opponentError)
        .toList();

    final advice = _buildPattern(
      points: lost,
      key: 'conceding_pattern',
      isGood: false,
      shotWord: '失点',
      courseWord: '失点しやすい',
      priority: 80,
    );
    if (advice != null) out.add(advice);
  }

  /// 得点の傾向（何の球で、どのコースで取れているか）
  static void _addScoringPattern(LiveCoachInput input, List<LiveAdvice> out) {
    if (!input.detailMode) return;

    final won = input.pointDetails
        .where((p) =>
            p.pointWinner == input.myTeam &&
            (p.pointType == PointType.winner || p.pointType == 'ace'))
        .toList();

    final advice = _buildPattern(
      points: won,
      key: 'scoring_pattern',
      isGood: true,
      shotWord: '得点',
      courseWord: '得点しやすい',
      priority: 70,
    );
    if (advice != null) out.add(advice);
  }

  /// 球種とコースの偏りから1件を組み立てる
  ///
  /// 「スマッシュで5得点。クロス展開で得点しやすい。」のように、
  /// 何の球かと、どの展開かを続けて言います。片方しか入力されていなければ、
  /// 入力されている側だけを言います。
  ///
  /// ダブルスなので、その球種の過半をひとりが占めていれば選手名も添えます。
  static LiveAdvice? _buildPattern({
    required List<PointDetail> points,
    required String key,
    required bool isGood,
    required String shotWord,
    required String courseWord,
    required int priority,
  }) {
    final shots = _countBy(points, (p) => p.shotType);
    final topShot = _mostCommon(shots);
    final courses = _countBy(points, (p) => p.courseType);
    final topCourse = _mostCommon(courses);

    final hasShot = topShot != null && shots.total >= _minShots;
    final hasCourse = topCourse != null && courses.total >= _minCourses;
    if (!hasShot && !hasCourse) return null;

    final sentences = <String>[];
    final facts = <String, String>{};
    var headline = '';

    if (hasShot) {
      final shotLabel = ShotType.getDisplay(topShot.key);
      // その球種を打ったのが主にひとりなら、選手名まで言う
      final player = _dominantPlayer(
        points.where((p) => p.shotType == topShot.key).toList(),
      );
      final subject = player == null ? '' : '$playerは';
      sentences.add('$subject$shotLabelで${topShot.count}$shotWord。');
      headline = shotLabel;
      facts['球種'] = shotLabel;
      facts[shotWord] = '${topShot.count}本';
      facts['入力済みの本数'] = '${shots.total}本';
      if (player != null) facts['主に打った選手'] = player;
    }

    if (hasCourse) {
      final courseLabel = CourseType.getDisplay(topCourse.key);
      sentences.add('$courseLabel展開で$courseWord。');
      if (headline.isEmpty) headline = courseLabel;
      facts['コース'] = courseLabel;
      facts['そのコースの本数'] = '${topCourse.count}本';
    }

    return LiveAdvice(
      key: key,
      headline: headline,
      template: sentences.join(''),
      priority: priority,
      isGood: isGood,
      facts: facts,
    );
  }

  /// 1stサーブの成功率
  ///
  /// 詳細モードでなくても、メイン画面の1st選択から記録されています。
  static void _addFirstServeRate(LiveCoachInput input, List<LiveAdvice> out) {
    final serves = input.pointDetails
        .where((p) => p.serverTeam == input.myTeam)
        .toList();
    if (serves.length < _minServes) return;

    final inCount = serves.where((p) => p.firstServeIn).length;
    final percent = (inCount / serves.length * 100).round();
    // 十分入っているときにわざわざ言う必要はない
    if (percent >= 60) return;

    out.add(LiveAdvice(
      key: 'first_serve_rate',
      headline: '1stサーブ',
      template: '1stサーブは${serves.length}本中$inCount本（$percent%）。',
      priority: 40,
      isGood: false,
      facts: {
        '1stサーブ成功率': '$percent%',
        '入った本数': '$inCount本',
        '打った本数': '${serves.length}本',
      },
    ));
  }

  // ============================================================================
  // 集計の補助
  // ============================================================================

  /// その球を打ったのが主にひとりなら、その選手名を返す
  ///
  /// ダブルスなので、ペアのどちらの傾向なのかが分かると打ち手が変わります。
  /// 過半を占めていないときは、名指しできないのでnullを返します。
  static String? _dominantPlayer(List<PointDetail> points) {
    final counts = _countBy(points, (p) => p.actionPlayer);
    final top = _mostCommon(counts);
    if (top == null || counts.total < 3) return null;
    if (top.count * 2 <= counts.total) return null;
    return top.key;
  }

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
