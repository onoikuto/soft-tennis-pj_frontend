import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';

class OfficialScoringScreen extends StatefulWidget {
  final int matchId;

  const OfficialScoringScreen({super.key, required this.matchId});

  @override
  State<OfficialScoringScreen> createState() => _OfficialScoringScreenState();
}

class _OfficialScoringScreenState extends State<OfficialScoringScreen> {
  Match? _match;
  List<GameScore> _gameScores = [];
  int _currentGame = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);
    final match = await DatabaseHelper.instance.getMatch(widget.matchId);
    final gameScores =
        await DatabaseHelper.instance.getGameScoresByMatchId(widget.matchId);
    
    setState(() {
      _match = match;
      _gameScores = gameScores;
      if (_gameScores.isNotEmpty) {
        _currentGame = _gameScores.last.gameNumber + 1;
      } else {
        _currentGame = 1;
      }
      _isLoading = false;
    });
  }

  Future<void> _addPoint(String team) async {
    if (_match == null) return;

    // 現在のゲームのスコアを取得または作成
    GameScore? currentGameScore;
    for (var score in _gameScores) {
      if (score.gameNumber == _currentGame) {
        currentGameScore = score;
        break;
      }
    }

    int team1Score = currentGameScore?.team1Score ?? 0;
    int team2Score = currentGameScore?.team2Score ?? 0;

    if (team == 'team1') {
      team1Score++;
    } else {
      team2Score++;
    }

    // ゲームの勝敗判定（4点先取、2点差）
    String? winner;
    if (team1Score >= 4 && team1Score - team2Score >= 2) {
      winner = 'team1';
    } else if (team2Score >= 4 && team2Score - team1Score >= 2) {
      winner = 'team2';
    }

    if (currentGameScore == null) {
      // 新しいゲームスコアを作成
      final newGameScore = GameScore(
        matchId: widget.matchId,
        gameNumber: _currentGame,
        team1Score: team1Score,
        team2Score: team2Score,
        serviceTeam: _currentGame == 1
            ? (_match!.firstServe ?? 'team1')
            : (_gameScores.isNotEmpty &&
                    _gameScores.last.winner == 'team1'
                ? 'team1'
                : 'team2'),
        winner: winner,
      );
      await DatabaseHelper.instance.insertGameScore(newGameScore);
    } else {
      // 既存のゲームスコアを更新
      final updatedGameScore = GameScore(
        id: currentGameScore.id,
        matchId: widget.matchId,
        gameNumber: _currentGame,
        team1Score: team1Score,
        team2Score: team2Score,
        serviceTeam: currentGameScore.serviceTeam,
        winner: winner,
      );
      await DatabaseHelper.instance.updateGameScore(updatedGameScore);
    }

    await _loadMatchData();

    // ゲームが終了したら次のゲームへ
    if (winner != null) {
      setState(() {
        _currentGame++;
      });
    }
  }

  Future<void> _undoLastPoint() async {
    if (_gameScores.isEmpty) return;

    final lastGame = _gameScores.last;
    if (lastGame.team1Score == 0 && lastGame.team2Score == 0) {
      // ゲームが空の場合は削除
      await DatabaseHelper.instance.deleteGameScore(lastGame.id!);
      setState(() {
        _currentGame--;
      });
    } else {
      // 最後のポイントを削除
      int team1Score = lastGame.team1Score;
      int team2Score = lastGame.team2Score;

      if (team1Score > team2Score) {
        team1Score--;
      } else if (team2Score > team1Score) {
        team2Score--;
      } else {
        team1Score = team2Score = 0;
      }

      final updatedGameScore = GameScore(
        id: lastGame.id,
        matchId: widget.matchId,
        gameNumber: lastGame.gameNumber,
        team1Score: team1Score,
        team2Score: team2Score,
        serviceTeam: lastGame.serviceTeam,
        winner: null,
      );
      await DatabaseHelper.instance.updateGameScore(updatedGameScore);
    }

    await _loadMatchData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: const Center(child: Text('マッチが見つかりません')),
      );
    }

    // ゲームごとのスコアを計算
    final gameScoresMap = <int, GameScore>{};
    for (var score in _gameScores) {
      gameScoresMap[score.gameNumber] = score;
    }

    // ゲーム数の合計
    int team1Games = 0;
    int team2Games = 0;
    for (var score in _gameScores) {
      if (score.winner == 'team1') {
        team1Games++;
      } else if (score.winner == 'team2') {
        team2Games++;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MATCH SCORE',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 2,
                color: const Color(0xFF7F7F7F),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _match!.tournamentName ?? '試合',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF333333)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // スコアテーブル
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // スコアテーブル
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF333333)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Table(
                      border: TableBorder.all(
                        color: const Color(0xFF333333),
                        width: 0.5,
                      ),
                      children: [
                        // ヘッダー
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9F9F9),
                          ),
                          children: [
                            _buildTableHeader('PLAYER'),
                            _buildTableHeader('S'),
                            _buildTableHeader('1'),
                            _buildTableHeader('2'),
                            _buildTableHeader('3'),
                            _buildTableHeader('4'),
                            _buildTableHeader('5'),
                            _buildTableHeader('6'),
                            _buildTableHeader('7'),
                            _buildTableHeader('ゲーム数', isGames: true),
                          ],
                        ),
                        // チーム1
                        TableRow(
                          children: [
                            _buildPlayerCell(
                              '${_match!.team1Player1}・${_match!.team1Player2}',
                              _match!.team1Club,
                            ),
                            _buildServiceCell(1, gameScoresMap),
                            _buildScoreCell(1, gameScoresMap, 'team1'),
                            _buildScoreCell(2, gameScoresMap, 'team1'),
                            _buildScoreCell(3, gameScoresMap, 'team1'),
                            _buildScoreCell(4, gameScoresMap, 'team1'),
                            _buildScoreCell(5, gameScoresMap, 'team1'),
                            _buildScoreCell(6, gameScoresMap, 'team1'),
                            _buildScoreCell(7, gameScoresMap, 'team1'),
                            _buildGamesCell(team1Games),
                          ],
                        ),
                        // チーム2
                        TableRow(
                          children: [
                            _buildPlayerCell(
                              '${_match!.team2Player1}・${_match!.team2Player2}',
                              _match!.team2Club,
                            ),
                            _buildServiceCell(1, gameScoresMap),
                            _buildScoreCell(1, gameScoresMap, 'team2'),
                            _buildScoreCell(2, gameScoresMap, 'team2'),
                            _buildScoreCell(3, gameScoresMap, 'team2'),
                            _buildScoreCell(4, gameScoresMap, 'team2'),
                            _buildScoreCell(5, gameScoresMap, 'team2'),
                            _buildScoreCell(6, gameScoresMap, 'team2'),
                            _buildScoreCell(7, gameScoresMap, 'team2'),
                            _buildGamesCell(team2Games),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 現在のゲーム表示
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '第 $_currentGame ゲーム',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // スコア入力ボタン
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamButton(
                        '${_match!.team1Player1}・${_match!.team1Player2}',
                        _match!.team1Club,
                        false,
                        () => _addPoint('team1'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTeamButton(
                        '${_match!.team2Player1}・${_match!.team2Player2}',
                        _match!.team2Club,
                        true,
                        () => _addPoint('team2'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _undoLastPoint,
                        icon: const Icon(Icons.undo),
                        label: const Text('一つ戻る'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: 試合終了処理
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('試合終了'),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {bool isGames = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildPlayerCell(String players, String? club) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            players,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
          if (club != null)
            Text(
              club,
              style: const TextStyle(
                fontSize: 8,
                color: Color(0xFF7F7F7F),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCell(int gameNum, Map<int, GameScore> scores) {
    final score = scores[gameNum];
    final hasService = score != null && score.serviceTeam == 'team1';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: hasService
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF333333),
                shape: BoxShape.circle,
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildScoreCell(int gameNum, Map<int, GameScore> scores, String team) {
    final score = scores[gameNum];
    if (score == null) return const SizedBox();
    
    final point = team == 'team1' ? score.team1Score : score.team2Score;
    final isWinner = score.winner == team;
    
    if (point == 0) return const SizedBox();
    
    if (point == 4) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF333333)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$point',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '$point',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
          color: isWinner ? Colors.green : const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildGamesCell(int games) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
      ),
      child: Text(
        '$games',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTeamButton(
    String players,
    String? club,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF000000) : Colors.white,
          border: Border.all(
            color: const Color(0xFF333333),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (club != null)
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
            if (club != null) const SizedBox(height: 8),
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
