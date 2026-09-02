import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';

/// スコアテーブルのヘッダーセル
class ScoreTableHeaderCell extends StatelessWidget {
  final String text;
  final bool isGames;

  const ScoreTableHeaderCell(this.text, {super.key, this.isGames = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isGames ? 7 : 8,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF7F7F7F),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// スコアテーブルの選手名セル
class ScoreTablePlayerCell extends StatelessWidget {
  final String players;
  final String club;

  const ScoreTablePlayerCell(this.players, this.club, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            players,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (club.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                club,
                style: const TextStyle(
                  fontSize: 7,
                  color: Color(0xFF7F7F7F),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// スコアテーブルのスコアセル
///
/// [gameNum] ゲーム番号（1-7）
/// [scores] ゲームスコアのマップ
/// [team] 表示するチーム（'team1' または 'team2'）
///
/// 各ゲームのスコアは対応する列に固定表示されます。
/// 1ゲームが終わるまで、そのゲームの列だけが更新されます。
class ScoreTableScoreCell extends StatelessWidget {
  final int gameNum;
  final Map<int, GameScore> scores;
  final String team;

  const ScoreTableScoreCell(this.gameNum, this.scores, this.team, {super.key});

  @override
  Widget build(BuildContext context) {
    final score = scores[gameNum];

    // ゲームが開始されていない場合は何も表示しない
    if (score == null) return const SizedBox();

    final point = team == 'team1' ? score.team1Score : score.team2Score;
    final isWinner = score.winner == team;
    final isGameCompleted = score.winner != null;

    // スコアが0の場合は何も表示しない（ゲーム開始前）
    if (point == 0 && !isGameCompleted) return const SizedBox();

    // ゲームが完了した場合の表示（勝利チームのみ4ポイント以上で丸囲み）
    // デュースの場合でも、勝利チームのみ丸を表示する
    if (isGameCompleted && isWinner && point >= 4) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.green,
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$point',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ),
      );
    }

    // ゲームが完了したが、このチームが負けた場合（4ポイント以上でも丸なしで表示）
    if (isGameCompleted && !isWinner && point >= 4) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          '$point',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: Color(0xFF333333),
          ),
        ),
      );
    }

    // 進行中のゲームのスコア表示
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        '$point',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
          color: isWinner ? Colors.green : const Color(0xFF333333),
        ),
      ),
    );
  }
}

/// スコアテーブルのゲーム数セル
class ScoreTableGamesCell extends StatelessWidget {
  final int games;

  const ScoreTableGamesCell(this.games, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$games',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// スコア入力用のチームボタン
class TeamScoreButton extends StatelessWidget {
  final String players;
  final String club;
  final bool isActive;
  final VoidCallback? onTap;

  const TeamScoreButton(this.players, this.club, this.isActive, this.onTap,
      {super.key});

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey[300]
              : (isActive ? const Color(0xFF000000) : Colors.white),
          border: Border.all(
            color: isDisabled
                ? Colors.grey[400]!
                : const Color(0xFF333333),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (club.isNotEmpty)
              Text(
                club,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white.withOpacity(0.6)
                      : const Color(0xFF7F7F7F),
                ),
              ),
            if (club.isNotEmpty) const SizedBox(height: 8),
            Text(
              players,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : const Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
