import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/set_score.dart';
import 'package:soft_tennis_scoring/widgets/score_input_dialog.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  Match? _match;
  List<SetScore> _setScores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);
    final match = await DatabaseHelper.instance.getMatch(widget.matchId);
    final setScores =
        await DatabaseHelper.instance.getSetScoresByMatchId(widget.matchId);
    setState(() {
      _match = match;
      _setScores = setScores;
      _isLoading = false;
    });
  }

  Future<void> _addSetScore() async {
    if (_match == null) return;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => ScoreInputDialog(
        team1Name: '${_match!.team1Player1} / ${_match!.team1Player2}',
        team2Name: '${_match!.team2Player1} / ${_match!.team2Player2}',
        setNumber: _setScores.length + 1,
      ),
    );

    if (result != null) {
      final setScore = SetScore(
        matchId: widget.matchId,
        setNumber: _setScores.length + 1,
        team1Score: result['team1']!,
        team2Score: result['team2']!,
        winner: result['team1']! > result['team2']! ? 'team1' : 'team2',
      );

      await DatabaseHelper.instance.insertSetScore(setScore);
      _loadMatchData();
    }
  }

  Future<void> _completeMatch() async {
    if (_match == null || _setScores.isEmpty) return;

    // 勝利数をカウント
    int team1Wins = 0;
    int team2Wins = 0;
    for (var setScore in _setScores) {
      if (setScore.winner == 'team1') {
        team1Wins++;
      } else if (setScore.winner == 'team2') {
        team2Wins++;
      }
    }

    if (team1Wins >= 2 || team2Wins >= 2) {
      final winner = team1Wins > team2Wins ? 'team1' : 'team2';
      final updatedMatch = Match(
        id: _match!.id,
        team1Player1: _match!.team1Player1,
        team1Player2: _match!.team1Player2,
        team2Player1: _match!.team2Player1,
        team2Player2: _match!.team2Player2,
        createdAt: _match!.createdAt,
        completedAt: DateTime.now(),
        winner: winner,
      );

      await DatabaseHelper.instance.updateMatch(updatedMatch);
      _loadMatchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              winner == 'team1'
                  ? '${_match!.team1Player1} / ${_match!.team1Player2} の勝利！'
                  : '${_match!.team2Player1} / ${_match!.team2Player2} の勝利！',
            ),
          ),
        );
      }
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('マッチ詳細'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // マッチ情報
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${_match!.team1Player1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_match!.team1Player2}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${_match!.team2Player1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_match!.team2Player2}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_match!.winner != null) ...[
                    const Divider(height: 32),
                    Chip(
                      label: Text(
                        _match!.winner == 'team1'
                            ? '${_match!.team1Player1} / ${_match!.team1Player2} の勝利'
                            : '${_match!.team2Player1} / ${_match!.team2Player2} の勝利',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.green[100],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // セットスコア一覧
          Expanded(
            child: _setScores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.score,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'セットスコアがありません',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _setScores.length,
                    itemBuilder: (context, index) {
                      final setScore = _setScores[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text('セット ${setScore.setNumber}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${setScore.team1Score}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: setScore.winner == 'team1'
                                      ? Colors.green
                                      : null,
                                ),
                              ),
                              const Text(
                                ' - ',
                                style: TextStyle(fontSize: 24),
                              ),
                              Text(
                                '${setScore.team2Score}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: setScore.winner == 'team2'
                                      ? Colors.green
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _match!.winner == null
          ? FloatingActionButton(
              onPressed: _addSetScore,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: _match!.winner == null && _setScores.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _completeMatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  'マッチを終了',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
