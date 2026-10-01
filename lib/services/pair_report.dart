import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';

/// 選手1人分の良かった点・課題
class PlayerReport {
  final String name;

  /// 得点の傾向（材料が足りなければnull）
  final String? good;

  /// 失点の傾向（材料が足りなければnull）
  final String? bad;

  const PlayerReport({required this.name, this.good, this.bad});

  /// 何か1つでも言えることがあるか
  bool get hasContent => good != null || bad != null;
}

/// 相手ペアの傾向
class OpponentReport {
  /// 弱点（相手が崩れている球・展開）
  final String? weakness;

  /// 強み（相手が決めてきている球・展開）
  final String? strength;

  const OpponentReport({this.weakness, this.strength});

  bool get hasContent => weakness != null || strength != null;
}

/// ペア2人分のまとめ
///
/// 統計画面（複数試合の累計）と、試合が終わった直後（その1試合）の
/// 両方で同じ形を使います。作り方を分けると、同じ数字なのに言い方が違う
/// という事故が起きるためです。
class PairReport {
  final List<PlayerReport> players;

  /// 一言（全体で一番大きい傾向を1行で）
  final String? summary;

  /// 相手ペアの傾向（材料が足りなければnull）
  final OpponentReport? opponent;

  const PairReport({required this.players, this.summary, this.opponent});

  /// 一部だけ差し替えた写しを作る
  ///
  /// 言い回しを整えた一言で差し替えるときなど、**渡さなかった項目は元のまま
  /// 残します。** コンストラクタを直接呼び直すと、書き忘れた項目が黙って
  /// 消えます（相手ペアの傾向が実際にそれで消えていました）。
  PairReport copyWith({
    List<PlayerReport>? players,
    String? summary,
    OpponentReport? opponent,
  }) {
    return PairReport(
      players: players ?? this.players,
      summary: summary ?? this.summary,
      opponent: opponent ?? this.opponent,
    );
  }

  /// 表示するものがあるか
  bool get hasContent =>
      players.any((p) => p.hasContent) ||
      summary != null ||
      (opponent?.hasContent ?? false);

  // ============================================================================
  // 組み立て
  // ============================================================================

  /// 集計結果からまとめを作る
  ///
  /// [playerNames] にはペアの2選手を渡します。空のときは記録に出てくる
  /// 選手から本数の多い順に2人を使います。
  ///
  /// **数字から言えることしか書きません。** 「頑張りましょう」の類は、
  /// 記録が無くても言えるので入れません。
  static PairReport build(
    AdvancedPointStats stats, {
    List<String> playerNames = const [],
  }) {
    var names = playerNames.where((n) => n.trim().isNotEmpty).toList();
    if (names.isEmpty) names = stats.involvedPlayers.take(2).toList();

    final players = [
      for (final name in names.take(2)) _buildPlayer(stats, name),
    ];

    return PairReport(
      players: players,
      summary: _buildSummary(stats, players),
      opponent: _buildOpponent(stats),
    );
  }

  /// 一言を出すのに必要な、ウィナーとミスの合計本数
  static const int _minSummaryTotal = 6;

  static PlayerReport _buildPlayer(AdvancedPointStats stats, String name) {
    return PlayerReport(
      name: name,
      good: _sentence(
        shots: stats.playerWinnerShots[name],
        courses: stats.playerWinnerCourses[name],
        countWord: '得点',
        courseWord: '得点しやすい',
      ),
      bad: _sentence(
        shots: stats.playerErrorShots[name],
        courses: stats.playerErrorCourses[name],
        countWord: '失点',
        courseWord: '失点しやすい',
      ),
    );
  }

  /// 「スマッシュで5得点。クロス展開で得点しやすい。」の形を作る
  ///
  /// 球種・コースはどちらも任意入力なので、入っている側だけで作ります。
  /// 3本未満のときは傾向と言えないので何も返しません。
  static String? _sentence({
    required Map<String, int>? shots,
    required Map<String, int>? courses,
    required String countWord,
    required String courseWord,
    String? player,
  }) {
    const minCount = 3;
    final parts = <String>[];

    final topShot = shots == null ? null : AdvancedPointStats.topOf(shots);
    if (topShot != null && _sum(shots!) >= minCount) {
      final subject = player == null ? '' : '$playerは';
      parts.add(
          '$subject${ShotType.getDisplay(topShot.key)}で${topShot.value}$countWord。');
    }

    final topCourse = courses == null ? null : AdvancedPointStats.topOf(courses);
    if (topCourse != null && _sum(courses!) >= minCount) {
      parts.add('${CourseType.getDisplay(topCourse.key)}展開で$courseWord。');
    }

    return parts.isEmpty ? null : parts.join('');
  }

  /// 相手ペアの傾向
  ///
  /// 採点票は両チームぶんを記録しているので、相手が崩れている球・決めて
  /// きている球もそのまま出せます。弱点のほうが打ち手に直結するので先です。
  static OpponentReport? _buildOpponent(AdvancedPointStats stats) {
    final weakness = _sentence(
      shots: stats.opponentErrorShots,
      courses: stats.opponentErrorCourses,
      countWord: 'ミス',
      courseWord: 'ミスが出やすい',
      player: _dominantPlayer(
        stats.opponentPlayerErrorShots,
        AdvancedPointStats.topOf(stats.opponentErrorShots)?.key,
      ),
    );
    final strength = _sentence(
      shots: stats.opponentWinnerShots,
      courses: stats.opponentWinnerCourses,
      countWord: '得点',
      courseWord: '決められやすい',
      player: _dominantPlayer(
        stats.opponentPlayerWinnerShots,
        AdvancedPointStats.topOf(stats.opponentWinnerShots)?.key,
      ),
    );

    if (weakness == null && strength == null) return null;
    return OpponentReport(weakness: weakness, strength: strength);
  }

  /// 一言（Good/Bad 行では分からないことだけを1行にする）
  ///
  /// 選手ごとのGood/Badをそのまま言い直しても、読み手には何も増えません。
  /// ここでは**得点と失点のどちらが上回っているか**という、行を並べただけでは
  /// 見えない比較を出します。偏りが十分はっきりしているときだけ、
  /// その中身にも触れます。
  ///
  /// 言えることが無いときはnullを返します。薄い一言を無理に出すくらいなら、
  /// 何も出さないほうがよいためです。
  static String? _buildSummary(
    AdvancedPointStats stats,
    List<PlayerReport> players,
  ) {
    final winners = stats.winnerShotTotal;
    final errors = stats.errorShotTotal;
    // 合計が少ないうちは、差が出ても偶然と区別できない
    if (winners + errors < _minSummaryTotal) return null;

    final balance = 'ウィナー$winners本・ミス$errors本。';

    // 差が小さいときは比較だけを言う（どちらが多いとは言わない）
    if ((winners - errors).abs() < 2) return balance;

    if (errors > winners) {
      final detail = _concentration(stats.errorShots, stats.playerErrorShots);
      return detail == null
          ? '$balanceミスのほうが多い。'
          : '$balanceミスのほうが多く、その中心は$detail。';
    }

    final detail = _concentration(stats.winnerShots, stats.playerWinnerShots);
    return detail == null
        ? '$balance取れているほうが多い。'
        : '$balance取れているほうが多く、その中心は$detail。';
  }

  /// 偏りがはっきりしているときだけ「（選手の）球種」を返す
  ///
  /// 3本未満、または全体の4割に満たないものは「中心」とは言えません。
  static String? _concentration(
    Map<String, int> shots,
    Map<String, Map<String, int>> byPlayer,
  ) {
    final top = AdvancedPointStats.topOf(shots);
    final total = _sum(shots);
    if (top == null || top.value < 3) return null;
    if (top.value * 10 < total * 4) return null;

    final player = _dominantPlayer(byPlayer, top.key);
    final label = ShotType.getDisplay(top.key);
    return player == null ? '$label（${top.value}本）' : '$playerの$label（${top.value}本）';
  }

  /// その球種を打っているのが主にひとりなら、その選手名
  static String? _dominantPlayer(
    Map<String, Map<String, int>> byPlayer,
    String? shot,
  ) {
    if (shot == null) return null;
    final counts = <String, int>{};
    byPlayer.forEach((player, shots) {
      final count = shots[shot];
      if (count != null) counts[player] = count;
    });
    final total = _sum(counts);
    final top = AdvancedPointStats.topOf(counts);
    if (top == null || total < 3) return null;
    if (top.value * 2 <= total) return null;
    return top.key;
  }

  static int _sum(Map<String, int> counts) =>
      counts.values.fold(0, (a, b) => a + b);
}
