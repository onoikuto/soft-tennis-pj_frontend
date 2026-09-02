import 'package:soft_tennis_scoring/models/game_score.dart';

/// ソフトテニスのゲーム進行ルールに関する共通ロジック
class GameRules {
  GameRules._(); // インスタンス化を防ぐ

  /// 勝利に必要なゲーム数を取得
  ///
  /// 5ゲームマッチ: 3ゲーム
  /// 7ゲームマッチ: 4ゲーム
  /// 9ゲームマッチ: 5ゲーム
  static int requiredGamesToWin(int gameCount) {
    switch (gameCount) {
      case 5:
        return 3;
      case 7:
        return 4;
      case 9:
        return 5;
      default:
        return 4;
    }
  }

  /// ファイナルゲームかどうかを判定
  ///
  /// [gameCount] マッチのゲーム数設定（5/7/9）
  /// [gameScores] これまでのゲームスコア
  /// [gameNumber] 判定するゲーム番号
  ///
  /// ファイナルゲームは、ゲームカウントが同点のまま最終ゲームに達した場合に発生します。
  /// 例: 7ゲームマッチで3-3になった場合、次のゲーム（7ゲーム目）がファイナルゲーム
  static bool isFinalGame({
    required int gameCount,
    required List<GameScore> gameScores,
    required int gameNumber,
  }) {
    // 対象ゲームより前の完了したゲームの数をカウント
    int team1Games = 0;
    int team2Games = 0;
    for (var score in gameScores) {
      if (score.gameNumber < gameNumber && score.winner != null) {
        if (score.winner == 'team1') {
          team1Games++;
        } else if (score.winner == 'team2') {
          team2Games++;
        }
      }
    }

    final requiredGames = requiredGamesToWin(gameCount);
    final totalCompletedGames = team1Games + team2Games;

    // ゲームカウントが同点のまま最終ゲームに達した場合
    // 例: 7ゲームマッチで3-3（合計6ゲーム完了）の場合、次のゲームがファイナルゲーム
    return totalCompletedGames == requiredGames * 2 - 2 &&
        team1Games == team2Games;
  }
}
