import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/widgets/scoring/scoring_sheet_table.dart';

Match _buildMatch() {
  return Match(
    id: 1,
    tournamentName: 'テスト大会',
    team1Player1: '山田',
    team1Player2: '田中',
    team1Club: 'A中学',
    team2Player1: '佐藤',
    team2Player2: '鈴木',
    team2Club: 'B中学',
    gameCount: 7,
    firstServe: 'team1',
    createdAt: DateTime(2026, 7, 1),
  );
}

PointDetail _point(int game, int number, String winner) {
  return PointDetail(
    matchId: 1,
    gameNumber: game,
    pointNumber: number,
    serverTeam: 'team1',
    firstServeIn: true,
    pointWinner: winner,
    pointType: 'opponent_error',
    createdAt: DateTime(2026, 7, 1),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 390, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('進行中のゲームは○✕マークと現在の得点が表示される', (tester) async {
    await tester.pumpWidget(_wrap(
      ScoringSheetTable(
        match: _buildMatch(),
        gameScores: [
          GameScore(
            id: 1,
            matchId: 1,
            gameNumber: 1,
            team1Score: 2,
            team2Score: 1,
            serviceTeam: 'team1',
          ),
        ],
        pointDetails: [
          _point(1, 1, 'team1'),
          _point(1, 2, 'team2'),
          _point(1, 3, 'team1'),
        ],
        currentGame: 1,
        isMatchCompleted: false,
        isFinalGame: (_) => false,
      ),
    ));

    // 左右合わせて ○3つ・✕3つ
    expect(find.text('○'), findsNWidgets(3));
    expect(find.text('✕'), findsNWidgets(3));
    // 中央に現在の得点
    expect(find.text('2 - 1'), findsOneWidget);
  });

  testWidgets('完了したゲームは○✕マークと得点が表示される', (tester) async {
    await tester.pumpWidget(_wrap(
      ScoringSheetTable(
        match: _buildMatch(),
        gameScores: [
          GameScore(
            id: 1,
            matchId: 1,
            gameNumber: 1,
            team1Score: 4,
            team2Score: 1,
            serviceTeam: 'team1',
            winner: 'team1',
          ),
        ],
        pointDetails: [
          _point(1, 1, 'team1'),
          _point(1, 2, 'team2'),
          _point(1, 3, 'team1'),
          _point(1, 4, 'team1'),
          _point(1, 5, 'team1'),
        ],
        currentGame: 2,
        isMatchCompleted: false,
        isFinalGame: (_) => false,
      ),
    ));

    // ○✕マーク: 4-1のゲームなので左右合わせて ○が5つ・✕が5つ
    expect(find.text('○'), findsNWidgets(5));
    expect(find.text('✕'), findsNWidgets(5));
    // 中央の得点 4（＋未開始ゲームの行番号4）
    expect(find.text('4'), findsNWidgets(2));
    // '1' は中央の得点1＋上部のゲームカウント1
    expect(find.text('1'), findsNWidgets(2));
    // 上部ゲームカウントの相手側 0
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('ポイント時系列がないゲームは最終スコアのみ表示される', (tester) async {
    await tester.pumpWidget(_wrap(
      ScoringSheetTable(
        match: _buildMatch(),
        gameScores: [
          GameScore(
            id: 1,
            matchId: 1,
            gameNumber: 1,
            team1Score: 4,
            team2Score: 2,
            serviceTeam: 'team1',
            winner: 'team1',
          ),
        ],
        pointDetails: const [],
        currentGame: 2,
        isMatchCompleted: false,
        isFinalGame: (_) => false,
      ),
    ));

    // フォールバック表示: ○✕マークは表示されず中央の得点のみ
    expect(find.text('○'), findsNothing);
    expect(find.text('✕'), findsNothing);
    // 得点4（＋未開始ゲームの行番号4）、得点2（＋進行中ゲームの行番号2）
    expect(find.text('4'), findsNWidgets(2));
    expect(find.text('2'), findsNWidgets(2));
  });

  testWidgets('デュースが続いてもレイアウトが崩れない（マークが折り返される）', (tester) async {
    // 8-8まで続くデュース（16ポイント、交互に取り合う）＋進行中
    final points = <PointDetail>[];
    for (var i = 1; i <= 16; i++) {
      points.add(_point(1, i, i.isOdd ? 'team1' : 'team2'));
    }

    await tester.pumpWidget(_wrap(
      ScoringSheetTable(
        match: _buildMatch(),
        gameScores: [
          GameScore(
            id: 1,
            matchId: 1,
            gameNumber: 1,
            team1Score: 8,
            team2Score: 8,
            serviceTeam: 'team1',
          ),
        ],
        pointDetails: points,
        currentGame: 1,
        isMatchCompleted: false,
        isFinalGame: (_) => false,
      ),
    ));

    // オーバーフロー例外が発生していないこと
    expect(tester.takeException(), isNull);

    // 全ポイントのマークが表示されている（左右合わせて○16・✕16）
    expect(find.text('○'), findsNWidgets(16));
    expect(find.text('✕'), findsNWidgets(16));

    // 横スクロールは発生せず、表の幅は画面内に収まっている
    final tableSize = tester.getSize(find.byType(ScoringSheetTable));
    expect(tableSize.width, lessThanOrEqualTo(390));
  });
}
