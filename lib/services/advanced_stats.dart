import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/utils/game_rules.dart';

/// 1試合分の結果（勝率推移・対戦相手別成績用）
class MatchRecord {
  final DateTime date;
  final bool won;

  /// 対戦相手の表示名（例: "長崎・熊本 (大阪スポーツ少年団)"）
  final String opponentLabel;

  MatchRecord({
    required this.date,
    required this.won,
    required this.opponentLabel,
  });
}

/// 月別勝率
class MonthlyWinRate {
  final DateTime month;
  final int wins;
  final int total;

  MonthlyWinRate({required this.month, required this.wins, required this.total});

  double get rate => total == 0 ? 0.0 : wins / total * 100;
}

/// 対戦相手別成績
class OpponentRecord {
  final String label;
  int wins = 0;
  int losses = 0;

  OpponentRecord(this.label);

  int get total => wins + losses;
  double get winRate => total == 0 ? 0.0 : wins / total * 100;
}

/// 試合結果の時系列から勝率推移・対戦相手別成績を集計する
class TrendStats {
  TrendStats._(); // インスタンス化を防ぐ

  /// 月別勝率（直近 [maxMonths] ヶ月分・古い月から順）
  static List<MonthlyWinRate> monthly(List<MatchRecord> records,
      {int maxMonths = 6}) {
    final byMonth = <DateTime, List<MatchRecord>>{};
    for (var record in records) {
      final month = DateTime(record.date.year, record.date.month);
      byMonth.putIfAbsent(month, () => []).add(record);
    }
    final months = byMonth.keys.toList()..sort();
    final recent = months.length > maxMonths
        ? months.sublist(months.length - maxMonths)
        : months;
    return recent.map((month) {
      final list = byMonth[month]!;
      return MonthlyWinRate(
        month: month,
        wins: list.where((r) => r.won).length,
        total: list.length,
      );
    }).toList();
  }

  /// 直近 [count] 試合の勝敗（古い試合から順）
  static List<bool> recentResults(List<MatchRecord> records, {int count = 10}) {
    final sorted = List<MatchRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));
    final recent =
        sorted.length > count ? sorted.sublist(sorted.length - count) : sorted;
    return recent.map((r) => r.won).toList();
  }

  /// 対戦相手別成績（対戦数の多い順）
  static List<OpponentRecord> opponents(List<MatchRecord> records) {
    final map = <String, OpponentRecord>{};
    for (var record in records) {
      final entry =
          map.putIfAbsent(record.opponentLabel, () => OpponentRecord(record.opponentLabel));
      if (record.won) {
        entry.wins++;
      } else {
        entry.losses++;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}

/// 選手別のサーブ時得点
class PlayerServeStat {
  final String player;
  int total = 0;
  int won = 0;

  PlayerServeStat(this.player);

  double get rate => total == 0 ? 0.0 : won / total * 100;
}

/// ポイント詳細データからのサーブ詳細・流れ統計
///
/// 試合ごとに [addMatch] で積み上げて使用します。
/// 「自チーム」視点で集計します（myTeam = 'team1' または 'team2'）。
class AdvancedPointStats {
  /// 1stサーブが入ったポイント（自チームサーブ時）
  int firstServePointTotal = 0;
  int firstServePointWon = 0;

  /// 2ndサーブになったポイント（自チームサーブ時）
  int secondServePointTotal = 0;
  int secondServePointWon = 0;

  /// 選手別サーブ時得点（自チームの選手のみ）
  final Map<String, PlayerServeStat> serverStats = {};

  /// 全ポイント
  int overallPointTotal = 0;
  int overallPointWon = 0;

  /// 失点直後のポイント（切り替え力）
  int afterLossTotal = 0;
  int afterLossWon = 0;

  /// 3連続以上の失点が発生した回数
  int lossStreak3Count = 0;

  /// 集計した試合数
  int matchCount = 0;

  /// ゲームポイント（あと1ポイントでゲーム取得の場面）
  int gamePointTotal = 0;
  int gamePointWon = 0;

  double get firstServePointRate =>
      firstServePointTotal == 0 ? 0.0 : firstServePointWon / firstServePointTotal * 100;
  double get secondServePointRate =>
      secondServePointTotal == 0 ? 0.0 : secondServePointWon / secondServePointTotal * 100;
  double get overallPointRate =>
      overallPointTotal == 0 ? 0.0 : overallPointWon / overallPointTotal * 100;
  double get afterLossRate =>
      afterLossTotal == 0 ? 0.0 : afterLossWon / afterLossTotal * 100;
  double get gamePointRate =>
      gamePointTotal == 0 ? 0.0 : gamePointWon / gamePointTotal * 100;
  double get lossStreak3PerMatch =>
      matchCount == 0 ? 0.0 : lossStreak3Count / matchCount;

  /// 選手別サーブ統計（サンプル数の多い順）
  List<PlayerServeStat> get serverStatsList {
    final list = serverStats.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// 1試合分のポイント詳細を集計に追加
  void addMatch({
    required String myTeam,
    required List<PointDetail> points,
    required List<GameScore> gameScores,
    required int gameCount,
  }) {
    if (points.isEmpty) return;
    matchCount++;

    // ゲームごとにポイントを分類（pointNumber順）
    final byGame = <int, List<PointDetail>>{};
    for (var point in points) {
      byGame.putIfAbsent(point.gameNumber, () => []).add(point);
    }
    for (var list in byGame.values) {
      list.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    }

    for (var entry in byGame.entries) {
      final gameNumber = entry.key;
      final gamePoints = entry.value;
      final isFinal = GameRules.isFinalGame(
        gameCount: gameCount,
        gameScores: gameScores,
        gameNumber: gameNumber,
      );
      // ゲームポイントの判定しきい値（通常4ポイント先取、ファイナルは7ポイント先取）
      final gamePointThreshold = isFinal ? 6 : 3;

      var myScore = 0;
      var oppScore = 0;
      var lossStreak = 0;
      bool? prevLost;

      for (var point in gamePoints) {
        final won = point.pointWinner == myTeam;

        // 全ポイント
        overallPointTotal++;
        if (won) overallPointWon++;

        // サーブ詳細（自チームサーブ時のみ）
        if (point.serverTeam == myTeam) {
          if (point.firstServeIn) {
            firstServePointTotal++;
            if (won) firstServePointWon++;
          } else {
            secondServePointTotal++;
            if (won) secondServePointWon++;
          }
          final server = point.serverPlayer;
          if (server != null && server.isNotEmpty) {
            final stat = serverStats.putIfAbsent(server, () => PlayerServeStat(server));
            stat.total++;
            if (won) stat.won++;
          }
        }

        // 失点直後のポイント（同一ゲーム内）
        if (prevLost == true) {
          afterLossTotal++;
          if (won) afterLossWon++;
        }

        // ゲームポイントの決定率
        // このポイントの開始時点で「あと1ポイントでゲーム取得」だったか
        if (myScore >= gamePointThreshold && myScore >= oppScore + 1) {
          gamePointTotal++;
          if (won) gamePointWon++;
        }

        // 連続失点（3連続に到達した時点で1回カウント）
        if (won) {
          lossStreak = 0;
        } else {
          lossStreak++;
          if (lossStreak == 3) {
            lossStreak3Count++;
          }
        }

        if (won) {
          myScore++;
        } else {
          oppScore++;
        }
        prevLost = !won;
      }
    }
  }
}
