import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';

/// 統計の集計対象（ペア／学校・クラブ／個人）
///
/// 統計画面のセグメント（[view]）と選択中の項目（[name]）の組で決まります。
/// 「山崎 (A高校)」のような表示名の読み取りと、「その試合でどちら側にいたか」の
/// 判定はこのクラスに集約してあります。
class StatsSubject {
  /// 0=ペア単位 / 1=学校・クラブ単位 / 2=個人単位
  final int view;

  /// 統計画面で選択されている項目の表示名
  final String name;

  /// 個人単位のときの選手名（それ以外はnull）
  final String? playerName;

  /// 個人単位のときの所属（所属なしのときはnull）
  final String? playerClub;

  StatsSubject._(this.view, this.name, this.playerName, this.playerClub);

  /// 表示名から集計対象を組み立てる
  factory StatsSubject(int view, String name) {
    if (view != 2) return StatsSubject._(view, name, null, null);

    // 個人単位は「山崎 (A高校)」または「山崎 (所属なし)」形式
    if (name.contains(' (')) {
      final parts = name.split(' (');
      final club = parts[1].replaceAll(')', '');
      return StatsSubject._(
        view,
        name,
        parts[0],
        club == '所属なし' ? null : club,
      );
    }
    // 旧形式（所属なしの選手名のみ）へのフォールバック
    return StatsSubject._(view, name, name, null);
  }

  /// ペア単位のときの、所属を除いたペア名
  String get pairName => name.split(' (').first;

  /// この試合が集計対象のものか
  bool covers(Match match) {
    switch (view) {
      case 0:
        return '${match.team1Player1}・${match.team1Player2}' == pairName ||
            '${match.team2Player1}・${match.team2Player2}' == pairName;
      case 1:
        return match.team1Club == name || match.team2Club == name;
      default:
        return _playerInTeam1(match) || _playerInTeam2(match);
    }
  }

  /// この試合で対象がチーム1側だったか
  ///
  /// 対象が見つからない場合はチーム1として扱います（元の実装と同じ挙動）。
  bool isTeam1(Match match) {
    switch (view) {
      case 0:
        return '${match.team1Player1}・${match.team1Player2}' == pairName;
      case 1:
        return match.team1Club == name;
      default:
        return _playerInTeam1(match);
    }
  }

  /// 対戦相手の表示名
  String opponentLabel(Match match) {
    final asTeam1 = isTeam1(match);
    final opponentPair = asTeam1
        ? '${match.team2Player1}・${match.team2Player2}'
        : '${match.team1Player1}・${match.team1Player2}';
    final opponentClub = asTeam1 ? match.team2Club : match.team1Club;

    // 学校・クラブ単位のときは相手も所属で集計する
    if (view == 1) {
      return opponentClub.isNotEmpty ? opponentClub : opponentPair;
    }
    return opponentClub.isNotEmpty
        ? '$opponentPair ($opponentClub)'
        : opponentPair;
  }

  bool _playerInTeam1(Match match) =>
      _matchesPlayer(match.team1Player1, match.team1Club) ||
      _matchesPlayer(match.team1Player2, match.team1Club);

  bool _playerInTeam2(Match match) =>
      _matchesPlayer(match.team2Player1, match.team2Club) ||
      _matchesPlayer(match.team2Player2, match.team2Club);

  /// 選手名と所属の両方が一致するか
  ///
  /// 同姓の選手を取り違えないよう、所属まで含めて判定します。
  bool _matchesPlayer(String name, String club) {
    if (name != playerName) return false;
    return playerClub != null ? club == playerClub : club.isEmpty;
  }
}

/// 統計画面に表示する集計結果
class StatisticsResult {
  final int totalMatches;
  final double winRate;
  final Map<int, double> gameWinRates;

  final double deuceWinRate;
  final int deuceWins;
  final int deuceLosses;

  final double serviceWinRate;
  final double receiveWinRate;

  final double finalGameWinRate;
  final int finalGameWins;
  final int finalGameTotal;

  final List<bool> recentResults;
  final List<MonthlyWinRate> monthlyWinRates;
  final List<OpponentRecord> opponentRecords;

  /// ポイント詳細（分析+）が記録されているか
  final bool hasPointDetails;
  final double firstServeInRate;
  final double firstServePointRate;
  final int winnerCount;
  final int myErrorCount;
  final AdvancedPointStats advancedPointStats;

  /// 分析コメント生成の入力
  final InsightInput insightInput;

  const StatisticsResult({
    required this.totalMatches,
    required this.winRate,
    required this.gameWinRates,
    required this.deuceWinRate,
    required this.deuceWins,
    required this.deuceLosses,
    required this.serviceWinRate,
    required this.receiveWinRate,
    required this.finalGameWinRate,
    required this.finalGameWins,
    required this.finalGameTotal,
    required this.recentResults,
    required this.monthlyWinRates,
    required this.opponentRecords,
    required this.hasPointDetails,
    required this.firstServeInRate,
    required this.firstServePointRate,
    required this.winnerCount,
    required this.myErrorCount,
    required this.advancedPointStats,
    required this.insightInput,
  });
}

/// 保存済みの試合から統計を集計する
///
/// 以前は統計画面の中で計算していましたが、試合を保存した直後に
/// バックグラウンドでAI分析を生成する（統計画面を開いていなくても）ために
/// 画面から切り離してあります。画面はここが返した値を表示するだけです。
class StatisticsCalculator {
  StatisticsCalculator._(); // インスタンス化を防ぐ

  /// 集計対象 [subject] の統計を計算する
  static Future<StatisticsResult> calculate(StatsSubject subject) async {
    final matches = await DatabaseHelper.instance.getAllMatches();
    final relevantMatches = matches
        .where((m) => m.completedAt != null && subject.covers(m))
        .toList();

    int wins = 0;
    final gameWins = <int, int>{};
    final gameTotal = <int, int>{};
    int deuceWins = 0;
    int deuceTotal = 0;
    int serviceWins = 0;
    int serviceTotal = 0;
    int receiveWins = 0;
    int receiveTotal = 0;
    int finalGameWins = 0;
    int finalGameTotal = 0;
    final matchRecords = <MatchRecord>[];

    for (final match in relevantMatches) {
      final isThisTeam1 = subject.isTeam1(match);

      if (match.winner != null) {
        final won = (isThisTeam1 && match.winner == 'team1') ||
            (!isThisTeam1 && match.winner == 'team2');
        if (won) wins++;

        matchRecords.add(MatchRecord(
          date: match.createdAt,
          won: won,
          opponentLabel: subject.opponentLabel(match),
        ));
      }

      final gameScores =
          await DatabaseHelper.instance.getGameScoresByMatchId(match.id!);
      final completedGameScores =
          gameScores.where((g) => g.winner != null).toList();
      // 勝利に必要なゲーム数（5ゲームマッチ→3、7ゲームマッチ→4、9ゲームマッチ→5）
      final gamesToWin = (match.gameCount + 1) ~/ 2;

      for (final gameScore in gameScores) {
        if (gameScore.winner == null) continue;

        final gameNum = gameScore.gameNumber;
        final isWin = (isThisTeam1 && gameScore.winner == 'team1') ||
            (!isThisTeam1 && gameScore.winner == 'team2');

        gameTotal[gameNum] = (gameTotal[gameNum] ?? 0) + 1;
        if (isWin) gameWins[gameNum] = (gameWins[gameNum] ?? 0) + 1;

        // デュース判定（3-3以上で2ポイント差で決着）
        final teamScore =
            isThisTeam1 ? gameScore.team1Score : gameScore.team2Score;
        final opponentScore =
            isThisTeam1 ? gameScore.team2Score : gameScore.team1Score;
        if (teamScore >= 3 && opponentScore >= 3) {
          deuceTotal++;
          if (isWin) deuceWins++;
        }

        // ファイナルゲーム判定
        // 前のゲームまでで両者が「勝利必要数-1」勝なら、このゲームがファイナル
        int team1GamesBefore = 0;
        int team2GamesBefore = 0;
        for (final gs in completedGameScores) {
          if (gs.gameNumber >= gameNum) continue;
          if (gs.winner == 'team1') {
            team1GamesBefore++;
          } else if (gs.winner == 'team2') {
            team2GamesBefore++;
          }
        }
        final isFinalGame = team1GamesBefore == gamesToWin - 1 &&
            team2GamesBefore == gamesToWin - 1;
        if (isFinalGame) {
          finalGameTotal++;
          if (isWin) finalGameWins++;
        }

        // サーブ・レシーブ判定
        final isService = (isThisTeam1 && gameScore.serviceTeam == 'team1') ||
            (!isThisTeam1 && gameScore.serviceTeam == 'team2');
        if (isService) {
          serviceTotal++;
          if (isWin) serviceWins++;
        } else {
          receiveTotal++;
          if (isWin) receiveWins++;
        }
      }
    }

    final gameWinRates = <int, double>{};
    for (int i = 1; i <= 9; i++) {
      if (gameTotal.containsKey(i)) {
        gameWinRates[i] = (gameWins[i] ?? 0) / gameTotal[i]! * 100;
      }
    }

    final detailed = await _calculateDetailed(subject, relevantMatches);

    final recentResults = TrendStats.recentResults(matchRecords);
    final monthlyWinRates = TrendStats.monthly(matchRecords);
    final opponentRecords = TrendStats.opponents(matchRecords);

    final winRate =
        relevantMatches.isEmpty ? 0.0 : wins / relevantMatches.length * 100;
    final serviceWinRate =
        serviceTotal == 0 ? 0.0 : serviceWins / serviceTotal * 100;
    final receiveWinRate =
        receiveTotal == 0 ? 0.0 : receiveWins / receiveTotal * 100;
    final deuceWinRate = deuceTotal == 0 ? 0.0 : deuceWins / deuceTotal * 100;
    final finalGameWinRate =
        finalGameTotal == 0 ? 0.0 : finalGameWins / finalGameTotal * 100;

    return StatisticsResult(
      totalMatches: relevantMatches.length,
      winRate: winRate,
      gameWinRates: gameWinRates,
      deuceWinRate: deuceWinRate,
      deuceWins: deuceWins,
      deuceLosses: deuceTotal - deuceWins,
      serviceWinRate: serviceWinRate,
      receiveWinRate: receiveWinRate,
      finalGameWinRate: finalGameWinRate,
      finalGameWins: finalGameWins,
      finalGameTotal: finalGameTotal,
      recentResults: recentResults,
      monthlyWinRates: monthlyWinRates,
      opponentRecords: opponentRecords,
      hasPointDetails: detailed.hasPointDetails,
      firstServeInRate: detailed.firstServeInRate,
      firstServePointRate: detailed.firstServePointRate,
      winnerCount: detailed.winnerCount,
      myErrorCount: detailed.myErrorCount,
      advancedPointStats: detailed.advancedStats,
      insightInput: InsightInput(
        totalMatches: relevantMatches.length,
        winRate: winRate,
        recentResults: recentResults,
        serviceWinRate: serviceWinRate,
        receiveWinRate: receiveWinRate,
        deuceWinRate: deuceWinRate,
        deuceTotal: deuceTotal,
        finalGameWinRate: finalGameWinRate,
        finalGameTotal: finalGameTotal,
        hasPointDetails: detailed.hasPointDetails,
        firstServeInRate: detailed.firstServeInRate,
        pointStats: detailed.hasPointDetails ? detailed.advancedStats : null,
        opponents: opponentRecords,
      ),
    );
  }

  /// ポイント詳細データ（分析+）からの集計
  static Future<_DetailedStats> _calculateDetailed(
    StatsSubject subject,
    List<Match> relevantMatches,
  ) async {
    int firstServeInCount = 0;
    int firstServeTotalCount = 0;
    int firstServePointWinCount = 0;
    int firstServePointTotalCount = 0;
    int winnerCount = 0;
    int myErrorCount = 0;
    bool hasData = false;
    final advancedStats = AdvancedPointStats();

    // 個人単位のときだけ、サーブ・ウィナーをその選手に絞り込む
    final targetPlayerName = subject.view == 2 ? subject.playerName : null;

    for (final match in relevantMatches) {
      if (match.id == null) continue;

      final pointDetails =
          await DatabaseHelper.instance.getPointDetailsByMatchId(match.id!);
      if (pointDetails.isEmpty) continue;

      hasData = true;

      final isThisTeam1 = subject.isTeam1(match);
      final myTeam = isThisTeam1 ? 'team1' : 'team2';
      final opponentTeam = isThisTeam1 ? 'team2' : 'team1';

      // ゲームポイント判定にゲームスコアが要る
      final matchGameScores =
          await DatabaseHelper.instance.getGameScoresByMatchId(match.id!);
      advancedStats.addMatch(
        myTeam: myTeam,
        points: pointDetails,
        gameScores: matchGameScores,
        gameCount: match.gameCount,
      );

      for (final point in pointDetails) {
        // 1stサーブ統計
        // 個人単位は本人が打ったサーブだけ、それ以外はチームのサーブを数える
        final countsAsMyServe = targetPlayerName != null
            ? point.serverPlayer == targetPlayerName
            : point.serverTeam == myTeam;
        if (countsAsMyServe) {
          firstServeTotalCount++;
          if (point.firstServeIn) {
            firstServeInCount++;
            firstServePointTotalCount++;
            if (point.pointWinner == myTeam) firstServePointWinCount++;
          }
        }

        // ウィナー／エラー統計
        if (targetPlayerName != null) {
          // 個人単位: 本人が決めた／ミスしたものだけ
          if (point.actionPlayer == targetPlayerName) {
            if (point.pointType == PointType.winner) winnerCount++;
            if (point.pointType == PointType.opponentError) myErrorCount++;
          }
        } else {
          if (point.pointWinner == myTeam &&
              point.pointType == PointType.winner) {
            winnerCount++;
          }
          if (point.pointWinner == opponentTeam &&
              point.pointType == PointType.opponentError) {
            myErrorCount++;
          }
        }
      }
    }

    return _DetailedStats(
      hasPointDetails: hasData,
      firstServeInRate: firstServeTotalCount == 0
          ? 0.0
          : firstServeInCount / firstServeTotalCount * 100,
      firstServePointRate: firstServePointTotalCount == 0
          ? 0.0
          : firstServePointWinCount / firstServePointTotalCount * 100,
      winnerCount: winnerCount,
      myErrorCount: myErrorCount,
      advancedStats: advancedStats,
    );
  }
}

/// ポイント詳細からの集計結果（このファイル内部でのみ使用）
class _DetailedStats {
  final bool hasPointDetails;
  final double firstServeInRate;
  final double firstServePointRate;
  final int winnerCount;
  final int myErrorCount;
  final AdvancedPointStats advancedStats;

  const _DetailedStats({
    required this.hasPointDetails,
    required this.firstServeInRate,
    required this.firstServePointRate,
    required this.winnerCount,
    required this.myErrorCount,
    required this.advancedStats,
  });
}
