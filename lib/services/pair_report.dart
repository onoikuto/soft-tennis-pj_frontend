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

/// ペア2人分のまとめ
///
/// 統計画面（複数試合の累計）と、試合が終わった直後（その1試合）の
/// 両方で同じ形を使います。作り方を分けると、同じ数字なのに言い方が違う
/// という事故が起きるためです。
class PairReport {
  final List<PlayerReport> players;

  /// 一言（全体で一番大きい傾向を1行で）
  final String? summary;

  const PairReport({required this.players, this.summary});

  /// 表示するものがあるか
  bool get hasContent => players.any((p) => p.hasContent) || summary != null;

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

    return PairReport(players: players, summary: _buildSummary(stats, players));
  }

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
  }) {
    const minCount = 3;
    final parts = <String>[];

    final topShot = shots == null ? null : AdvancedPointStats.topOf(shots);
    if (topShot != null && _sum(shots!) >= minCount) {
      parts.add('${ShotType.getDisplay(topShot.key)}で${topShot.value}$countWord。');
    }

    final topCourse = courses == null ? null : AdvancedPointStats.topOf(courses);
    if (topCourse != null && _sum(courses!) >= minCount) {
      parts.add('${CourseType.getDisplay(topCourse.key)}展開で$courseWord。');
    }

    return parts.isEmpty ? null : parts.join('');
  }

  /// 一言（全体で一番本数の多い傾向を1行にする）
  ///
  /// ここだけは「まとめ」なので解釈が入ります。だからこそ**候補は数字から
  /// 機械的に選び**、LLMには言い回しを整えさせるだけにします。1.5B級に
  /// 自由に書かせると、渡していない理由や対策を作り出します。
  static String? _buildSummary(
    AdvancedPointStats stats,
    List<PlayerReport> players,
  ) {
    final topError = AdvancedPointStats.topOf(stats.errorShots);
    final topWinner = AdvancedPointStats.topOf(stats.winnerShots);

    // 失点のほうが直しどころなので先に見る
    if (topError != null && stats.errorShotTotal >= 5) {
      final player = _dominantPlayer(stats.playerErrorShots, topError.key);
      final who = player == null ? '' : '$playerの';
      return 'いま一番失点しているのは$who${ShotType.getDisplay(topError.key)}'
          '（${topError.value}本）。';
    }

    if (topWinner != null && stats.winnerShotTotal >= 5) {
      final player = _dominantPlayer(stats.playerWinnerShots, topWinner.key);
      final who = player == null ? '' : '$playerの';
      return 'いま一番取れているのは$who${ShotType.getDisplay(topWinner.key)}'
          '（${topWinner.value}本）。';
    }

    return null;
  }

  /// その球種を打っているのが主にひとりなら、その選手名
  static String? _dominantPlayer(
    Map<String, Map<String, int>> byPlayer,
    String shot,
  ) {
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
