import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/utils/game_rules.dart';

GameScore _completedGame(int gameNumber, String winner) {
  return GameScore(
    matchId: 1,
    gameNumber: gameNumber,
    team1Score: winner == 'team1' ? 4 : 1,
    team2Score: winner == 'team2' ? 4 : 1,
    serviceTeam: 'team1',
    winner: winner,
  );
}

void main() {
  group('requiredGamesToWin', () {
    test('5/7/9ゲームマッチの必要ゲーム数', () {
      expect(GameRules.requiredGamesToWin(5), 3);
      expect(GameRules.requiredGamesToWin(7), 4);
      expect(GameRules.requiredGamesToWin(9), 5);
      // 不明な値はデフォルト4
      expect(GameRules.requiredGamesToWin(3), 4);
    });
  });

  group('isFinalGame', () {
    test('7ゲームマッチで3-3の場合、7ゲーム目がファイナルゲーム', () {
      final scores = [
        _completedGame(1, 'team1'),
        _completedGame(2, 'team2'),
        _completedGame(3, 'team1'),
        _completedGame(4, 'team2'),
        _completedGame(5, 'team1'),
        _completedGame(6, 'team2'),
      ];
      expect(
        GameRules.isFinalGame(gameCount: 7, gameScores: scores, gameNumber: 7),
        isTrue,
      );
    });

    test('7ゲームマッチで4-2の場合、7ゲーム目はファイナルゲームではない', () {
      final scores = [
        _completedGame(1, 'team1'),
        _completedGame(2, 'team1'),
        _completedGame(3, 'team2'),
        _completedGame(4, 'team1'),
        _completedGame(5, 'team2'),
        _completedGame(6, 'team1'),
      ];
      expect(
        GameRules.isFinalGame(gameCount: 7, gameScores: scores, gameNumber: 7),
        isFalse,
      );
    });

    test('5ゲームマッチで2-2の場合、5ゲーム目がファイナルゲーム', () {
      final scores = [
        _completedGame(1, 'team1'),
        _completedGame(2, 'team2'),
        _completedGame(3, 'team1'),
        _completedGame(4, 'team2'),
      ];
      expect(
        GameRules.isFinalGame(gameCount: 5, gameScores: scores, gameNumber: 5),
        isTrue,
      );
    });

    test('序盤のゲームはファイナルゲームではない', () {
      final scores = [
        _completedGame(1, 'team1'),
        _completedGame(2, 'team2'),
      ];
      expect(
        GameRules.isFinalGame(gameCount: 7, gameScores: scores, gameNumber: 3),
        isFalse,
      );
    });
  });
}
