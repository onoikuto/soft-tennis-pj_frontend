// 採点表ウィジェットの見た目確認用（ゴールデン画像を生成するだけの一時テスト）
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() {
  testWidgets('採点表プレビュー画像を生成', (tester) async {
    final fontData = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
        .readAsBytesSync();
    final fontLoader = FontLoader('JPFont')
      ..addFont(Future.value(ByteData.view(fontData.buffer)));
    await fontLoader.load();

    // ゲーム1: 4-2で team1 勝利（デュースなし）
    // ゲーム2: デュースが続いて 7-5 で team2 勝利（12ポイント）
    // ゲーム3: 進行中 2-1
    final gameScores = [
      GameScore(id: 1, matchId: 1, gameNumber: 1, team1Score: 4, team2Score: 2, serviceTeam: 'team1', winner: 'team1'),
      GameScore(id: 2, matchId: 1, gameNumber: 2, team1Score: 5, team2Score: 7, serviceTeam: 'team2', winner: 'team2'),
      GameScore(id: 3, matchId: 1, gameNumber: 3, team1Score: 2, team2Score: 1, serviceTeam: 'team1'),
    ];
    final points = [
      _point(1, 1, 'team1'),
      _point(1, 2, 'team2'),
      _point(1, 3, 'team1'),
      _point(1, 4, 'team1'),
      _point(1, 5, 'team2'),
      _point(1, 6, 'team1'),
      // ゲーム2: 3-3から交互に取り合い、最後にteam2が連取して5-7
      _point(2, 1, 'team1'),
      _point(2, 2, 'team2'),
      _point(2, 3, 'team1'),
      _point(2, 4, 'team2'),
      _point(2, 5, 'team1'),
      _point(2, 6, 'team2'),
      _point(2, 7, 'team1'),
      _point(2, 8, 'team2'),
      _point(2, 9, 'team1'),
      _point(2, 10, 'team2'),
      _point(2, 11, 'team2'),
      _point(2, 12, 'team2'),
      _point(3, 1, 'team1'),
      _point(3, 2, 'team2'),
      _point(3, 3, 'team1'),
    ];

    // iPhone 相当の画面サイズ
    await tester.binding.setSurfaceSize(const Size(390, 700));
    tester.view.physicalSize = const Size(1170, 2100);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'JPFont'),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topCenter,
              child: ScoringSheetTable(
                match: _buildMatch(),
                gameScores: gameScores,
                pointDetails: points,
                currentGame: 3,
                isMatchCompleted: false,
                isFinalGame: (_) => false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/scoring_sheet_preview.png'),
    );
  });
}
