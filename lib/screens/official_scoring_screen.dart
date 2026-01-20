import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/screens/main_menu_screen.dart';

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
  bool _isMatchCompleted = false;

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
      
      // 試合の勝敗をチェック
      // completedAtが設定されている場合、または試合の勝敗が決まっている場合は終了
      if (match != null && match.completedAt != null) {
        _isMatchCompleted = true;
      } else {
        final matchWinner = _checkMatchWinner();
        if (matchWinner != null) {
          _isMatchCompleted = true;
        } else {
          _isMatchCompleted = false;
        }
      }
      
      // 現在進行中のゲームを決定
      // 完了していないゲーム（winner == null）があれば、それが現在のゲーム
      // 全てのゲームが完了している場合は、現在の_currentGameを維持（既に次のゲーム番号に更新されている）
      if (_gameScores.isNotEmpty) {
        // 完了していない最後のゲームを探す
        GameScore? incompleteGame;
        for (var score in _gameScores.reversed) {
          if (score.winner == null) {
            incompleteGame = score;
            break;
          }
        }
        
        if (incompleteGame != null) {
          // 進行中のゲームがある場合は、そのゲーム番号
          _currentGame = incompleteGame.gameNumber;
        }
        // 完了していないゲームがない場合は、_currentGameは既に_nextGameに更新されているので変更しない
      }
      // ゲームスコアが存在しない場合も、_currentGameは既に設定されているので変更しない
      _isLoading = false;
    });
  }

  Future<void> _addPoint(String team) async {
    if (_match == null) return;

    // 現在のゲームのスコアを取得
    // 完了していないゲーム（winner == null）を探す
    GameScore? currentGameScore;
    for (var score in _gameScores.reversed) {
      if (score.winner == null) {
        currentGameScore = score;
        _currentGame = score.gameNumber;
        break;
      }
    }
    
    // 完了していないゲームがない場合は、新しいゲームを開始
    if (currentGameScore == null) {
      // 次のゲーム番号を決定
      if (_gameScores.isNotEmpty) {
        // 最後のゲーム番号 + 1
        _currentGame = _gameScores.last.gameNumber + 1;
      } else {
        // 最初のゲーム
        _currentGame = 1;
      }
    }

    int team1Score = currentGameScore?.team1Score ?? 0;
    int team2Score = currentGameScore?.team2Score ?? 0;

    if (team == 'team1') {
      team1Score++;
    } else {
      team2Score++;
    }

    // ファイナルゲームかどうかを判定
    // ファイナルゲームは、ゲーム数に達した時点で同点の場合に発生
    // 現在のゲームがファイナルゲームかどうかを判定
    final isFinalGame = _isFinalGame(_currentGame);
    
    // ゲームの勝敗判定
    String? winner;
    if (isFinalGame) {
      // ファイナルゲーム: 先に7ポイント取った方が勝ち、デュースあり（2ポイント差が必要）
      if (team1Score >= 7 && team1Score - team2Score >= 2) {
        winner = 'team1';
      } else if (team2Score >= 7 && team2Score - team1Score >= 2) {
        winner = 'team2';
      }
    } else {
      // 通常のゲーム: 4ポイント先取、デュースあり（2ポイント差が必要）
      if (team1Score >= 4 && team1Score - team2Score >= 2) {
        winner = 'team1';
      } else if (team2Score >= 4 && team2Score - team1Score >= 2) {
        winner = 'team2';
      }
    }

    // サーブ権の決定
    // ソフトテニスでは、ゲームごとにサーブ権が交代する
    String? serviceTeam;
    if (currentGameScore == null) {
      // 新しいゲームの場合、先サーブを決定
      if (_currentGame == 1) {
        // 1ゲーム目はマッチの先サーブ設定を使用
        serviceTeam = _match!.firstServe ?? 'team1';
      } else {
        // 2ゲーム目以降は前のゲームの先サーブと逆にする（交代）
        if (_gameScores.isNotEmpty) {
          // 完了したゲームの中で最後のものを探す
          GameScore? lastCompletedGame;
          for (var score in _gameScores.reversed) {
            if (score.winner != null) {
              lastCompletedGame = score;
              break;
            }
          }
          
          if (lastCompletedGame != null) {
            // 前のゲームの先サーブと逆にする
            serviceTeam = lastCompletedGame.serviceTeam == 'team1' ? 'team2' : 'team1';
          } else {
            serviceTeam = 'team1';
          }
        } else {
          serviceTeam = 'team1';
        }
      }
    } else {
      // 既存のゲームの場合
      if (isFinalGame) {
        // ファイナルゲーム: 2ポイントごとにサーブ権が交代
        final totalPoints = team1Score + team2Score;
        // 合計ポイント数が2の倍数の時にサーブ権が交代
        if (totalPoints > 0 && totalPoints % 2 == 0) {
          // サーブ権を交代
          serviceTeam = currentGameScore.serviceTeam == 'team1' ? 'team2' : 'team1';
        } else {
          // サーブ権を維持
          serviceTeam = currentGameScore.serviceTeam;
        }
      } else {
        // 通常のゲーム: サーブ権を維持
        serviceTeam = currentGameScore.serviceTeam;
      }
    }

    if (currentGameScore == null) {
      // 新しいゲームスコアを作成
      final newGameScore = GameScore(
        matchId: widget.matchId,
        gameNumber: _currentGame,
        team1Score: team1Score,
        team2Score: team2Score,
        serviceTeam: serviceTeam,
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
        serviceTeam: serviceTeam, // ファイナルゲームの場合は更新されたサーブ権を使用
        winner: winner,
      );
      await DatabaseHelper.instance.updateGameScore(updatedGameScore);
    }

    // ゲームが終了した場合、試合の勝敗をチェック
    if (winner != null) {
      await _loadMatchData();
      
      // 試合の勝敗を判定
      final matchWinner = _checkMatchWinner();
      if (matchWinner != null) {
        // 試合が終了した場合
        setState(() {
          _isMatchCompleted = true;
        });
        // マッチを完了状態に更新
        if (_match != null) {
          final updatedMatch = Match(
            id: _match!.id,
            tournamentName: _match!.tournamentName,
            team1Player1: _match!.team1Player1,
            team1Player2: _match!.team1Player2,
            team1Club: _match!.team1Club,
            team2Player1: _match!.team2Player1,
            team2Player2: _match!.team2Player2,
            team2Club: _match!.team2Club,
            gameCount: _match!.gameCount,
            firstServe: _match!.firstServe,
            createdAt: _match!.createdAt,
            completedAt: DateTime.now(),
          );
          await DatabaseHelper.instance.updateMatch(updatedMatch);
        }
      } else {
        // 試合が続行する場合、次のゲームの先サーブを表示するために
        // 完了していないゲームがない場合、次のゲーム番号を設定
        bool hasIncompleteGame = false;
        for (var score in _gameScores) {
          if (score.winner == null) {
            hasIncompleteGame = true;
            break;
          }
        }
        
        if (!hasIncompleteGame) {
          // 全てのゲームが完了している場合、次のゲーム番号に進む
          setState(() {
            if (_gameScores.isNotEmpty) {
              _currentGame = _gameScores.last.gameNumber + 1;
            } else {
              _currentGame = 1;
            }
          });
        }
      }
    } else {
      await _loadMatchData();
    }
  }
  
  /// ファイナルゲームかどうかを判定
  /// 
  /// [gameNumber] 判定するゲーム番号
  /// 
  /// ファイナルゲームは、ゲーム数に達した時点で同点の場合に発生します。
  /// 例: 7ゲームマッチで3-3になった場合、次のゲーム（7ゲーム目）がファイナルゲーム
  /// 5ゲームマッチで2-2になった場合、次のゲーム（5ゲーム目）がファイナルゲーム
  bool _isFinalGame(int gameNumber) {
    if (_match == null) return false;
    
    // 完了したゲームの数をカウント（現在のゲームを除く）
    int team1Games = 0;
    int team2Games = 0;
    for (var score in _gameScores) {
      if (score.gameNumber < gameNumber && score.winner != null) {
        if (score.winner == 'team1') {
          team1Games++;
        } else if (score.winner == 'team2') {
          team2Games++;
        }
      }
    }
    
    // ゲーム数に達した時点で同点の場合、次のゲームがファイナルゲーム
    final requiredGames = _getRequiredGamesToWin();
    final totalCompletedGames = team1Games + team2Games;
    
    // ゲーム数に達していて、かつ同点の場合
    // 例: 7ゲームマッチで3-3（合計6ゲーム完了）の場合、次のゲーム（7ゲーム目）がファイナルゲーム
    if (totalCompletedGames == requiredGames * 2 - 2 && team1Games == team2Games) {
      return true;
    }
    
    return false;
  }
  
  /// 勝利に必要なゲーム数を取得
  /// 
  /// 5ゲームマッチ: 3ゲーム
  /// 7ゲームマッチ: 4ゲーム
  /// 9ゲームマッチ: 5ゲーム
  int _getRequiredGamesToWin() {
    if (_match == null) return 4;
    
    switch (_match!.gameCount) {
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
  
  /// 試合の勝敗を判定
  /// 
  /// 戻り値: 勝利チーム（'team1' or 'team2'）またはnull（試合続行中）
  String? _checkMatchWinner() {
    if (_match == null) return null;
    
    // 完了したゲームの数をカウント
    int team1Games = 0;
    int team2Games = 0;
    for (var score in _gameScores) {
      if (score.winner == 'team1') {
        team1Games++;
      } else if (score.winner == 'team2') {
        team2Games++;
      }
    }
    
    final requiredGames = _getRequiredGamesToWin();
    
    // 先に必要なゲーム数を取った方が勝ち
    if (team1Games >= requiredGames) {
      return 'team1';
    } else if (team2Games >= requiredGames) {
      return 'team2';
    }
    
    return null;
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

      // 勝敗を再判定
      String? winner;
      final isFinalGame = _isFinalGame(lastGame.gameNumber);
      
      if (isFinalGame) {
        // ファイナルゲーム: 先に7ポイント取った方が勝ち、デュースあり（2ポイント差が必要）
        if (team1Score >= 7 && team1Score - team2Score >= 2) {
          winner = 'team1';
        } else if (team2Score >= 7 && team2Score - team1Score >= 2) {
          winner = 'team2';
        }
      } else {
        // 通常のゲーム: 4ポイント先取、デュースあり（2ポイント差が必要）
        if (team1Score >= 4 && team1Score - team2Score >= 2) {
          winner = 'team1';
        } else if (team2Score >= 4 && team2Score - team1Score >= 2) {
          winner = 'team2';
        }
      }

      final updatedGameScore = GameScore(
        id: lastGame.id,
        matchId: widget.matchId,
        gameNumber: lastGame.gameNumber,
        team1Score: team1Score,
        team2Score: team2Score,
        serviceTeam: lastGame.serviceTeam,
        winner: winner,
      );
      await DatabaseHelper.instance.updateGameScore(updatedGameScore);
    }

    await _loadMatchData();
    
    // 試合の勝敗を再チェック（試合が終了していない場合、completedAtをクリア）
    final matchWinner = _checkMatchWinner();
    if (matchWinner == null && _match != null && _match!.completedAt != null) {
      // 試合が終了していない状態に戻った場合、completedAtをクリア
      final updatedMatch = Match(
        id: _match!.id,
        tournamentName: _match!.tournamentName,
        team1Player1: _match!.team1Player1,
        team1Player2: _match!.team1Player2,
        team1Club: _match!.team1Club,
        team2Player1: _match!.team2Player1,
        team2Player2: _match!.team2Player2,
        team2Club: _match!.team2Club,
        gameCount: _match!.gameCount,
        firstServe: _match!.firstServe,
        createdAt: _match!.createdAt,
        completedAt: null, // 試合を進行中に戻す
      );
      await DatabaseHelper.instance.updateMatch(updatedMatch);
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

    // ゲームごとのスコアをマップに変換
    // 完了したゲームと進行中のゲームの両方を含む
    // 各列（1-7）は対応するゲーム番号に固定され、1ゲームが終わるまでその列だけが更新される
    final gameScoresMap = <int, GameScore>{};
    for (var score in _gameScores) {
      gameScoresMap[score.gameNumber] = score;
    }

    // ゲーム数の合計（完了したゲームのみカウント）
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
              _match!.tournamentName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // スコアテーブル
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // スコアテーブル（横スクロール可能）
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF333333)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Table(
                        border: TableBorder.all(
                          color: const Color(0xFF333333),
                          width: 0.5,
                        ),
                        columnWidths: {
                          // PLAYER列は固定幅
                          0: const FixedColumnWidth(80),
                          // S列は固定幅
                          1: const FixedColumnWidth(30),
                          // ゲーム列は固定幅（コンパクトに）
                          2: const FixedColumnWidth(28),
                          3: const FixedColumnWidth(28),
                          4: const FixedColumnWidth(28),
                          5: const FixedColumnWidth(28),
                          6: const FixedColumnWidth(28),
                          7: const FixedColumnWidth(28),
                          8: const FixedColumnWidth(28),
                          9: const FixedColumnWidth(28),
                          10: const FixedColumnWidth(28),
                          // ゲーム数列は固定幅
                          11: const FixedColumnWidth(50),
                        },
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
                            _buildTableHeader('8'),
                            _buildTableHeader('9'),
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
                            _buildCurrentGameServiceCell(gameScoresMap, 'team1', _match!),
                            _buildScoreCell(1, gameScoresMap, 'team1'),
                            _buildScoreCell(2, gameScoresMap, 'team1'),
                            _buildScoreCell(3, gameScoresMap, 'team1'),
                            _buildScoreCell(4, gameScoresMap, 'team1'),
                            _buildScoreCell(5, gameScoresMap, 'team1'),
                            _buildScoreCell(6, gameScoresMap, 'team1'),
                            _buildScoreCell(7, gameScoresMap, 'team1'),
                            _buildScoreCell(8, gameScoresMap, 'team1'),
                            _buildScoreCell(9, gameScoresMap, 'team1'),
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
                            _buildCurrentGameServiceCell(gameScoresMap, 'team2', _match!),
                            _buildScoreCell(1, gameScoresMap, 'team2'),
                            _buildScoreCell(2, gameScoresMap, 'team2'),
                            _buildScoreCell(3, gameScoresMap, 'team2'),
                            _buildScoreCell(4, gameScoresMap, 'team2'),
                            _buildScoreCell(5, gameScoresMap, 'team2'),
                            _buildScoreCell(6, gameScoresMap, 'team2'),
                            _buildScoreCell(7, gameScoresMap, 'team2'),
                            _buildScoreCell(8, gameScoresMap, 'team2'),
                            _buildScoreCell(9, gameScoresMap, 'team2'),
                            _buildGamesCell(team2Games),
                          ],
                          ),
                        ],
                      ),
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
                        _isFinalGame(_currentGame) 
                            ? 'ファイナルゲーム'
                            : '第 $_currentGame ゲーム',
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
                        _isMatchCompleted ? null : () => _addPoint('team1'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTeamButton(
                        '${_match!.team2Player1}・${_match!.team2Player2}',
                        _match!.team2Club,
                        true,
                        _isMatchCompleted ? null : () => _addPoint('team2'),
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
                        onPressed: () async {
                          // 試合が終了していない場合は確認ダイアログを2回表示
                          final matchWinner = _checkMatchWinner();
                          if (matchWinner == null && _match != null && _match!.completedAt == null) {
                            // 1回目の確認ダイアログを表示
                            final shouldProceed = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('試合を終了しますか？'),
                                  content: const Text(
                                    '試合がまだ終了していません。\n'
                                    '本当に試合を終了してよろしいですか？',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('終了する'),
                                    ),
                                  ],
                                );
                              },
                            );
                            
                            // キャンセルされた場合は何もしない
                            if (shouldProceed != true) {
                              return;
                            }
                            
                            // 2回目の確認ダイアログを表示
                            final shouldComplete = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('本当によろしいですか？'),
                                  content: const Text(
                                    '試合を終了すると、スコアの変更ができなくなります。\n'
                                    '本当に終了してよろしいですか？',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('終了する'),
                                    ),
                                  ],
                                );
                              },
                            );
                            
                            // キャンセルされた場合は何もしない
                            if (shouldComplete != true) {
                              return;
                            }
                          }
                          
                          // 試合を完了状態にする
                          if (_match != null && _match!.completedAt == null) {
                            final updatedMatch = Match(
                              id: _match!.id,
                              tournamentName: _match!.tournamentName,
                              team1Player1: _match!.team1Player1,
                              team1Player2: _match!.team1Player2,
                              team1Club: _match!.team1Club,
                              team2Player1: _match!.team2Player1,
                              team2Player2: _match!.team2Player2,
                              team2Club: _match!.team2Club,
                              gameCount: _match!.gameCount,
                              firstServe: _match!.firstServe,
                              createdAt: _match!.createdAt,
                              completedAt: DateTime.now(),
                            );
                            await DatabaseHelper.instance.updateMatch(updatedMatch);
                          }
                          
                          // メインメニューに戻る
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const MainMenuScreen(),
                              ),
                              (route) => false, // 全ての前のルートを削除
                            );
                          }
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

  Widget _buildPlayerCell(String players, String club) {
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

  /// 現在進行中のゲームのサーブセルを構築
  /// 
  /// [scores] ゲームスコアのマップ
  /// [team] 表示するチーム（'team1' または 'team2'）
  /// [match] マッチ情報（先サーブを取得するため）
  /// 
  /// 現在進行中のゲーム（_currentGame）の先サーブを表示します。
  /// 1ゲームが終了したタイミングで、次のゲームの先サーブに自動的に更新されます。
  Widget _buildCurrentGameServiceCell(
    Map<int, GameScore> scores,
    String team,
    Match match,
  ) {
    // 現在進行中のゲームの先サーブを取得
    String? firstServeTeam;
    
    // 現在のゲームのスコアを取得
    final currentGameScore = scores[_currentGame];
    
    if (currentGameScore != null) {
      // ゲームが開始されている場合
      final isFinalGame = _isFinalGame(_currentGame);
      if (isFinalGame) {
        // ファイナルゲーム: 2ポイントごとにサーブ権が交代
        final totalPoints = currentGameScore.team1Score + currentGameScore.team2Score;
        // 合計ポイント数が2の倍数の時にサーブ権が交代
        if (totalPoints > 0 && totalPoints % 2 == 0) {
          // サーブ権を交代
          firstServeTeam = currentGameScore.serviceTeam == 'team1' ? 'team2' : 'team1';
        } else {
          // サーブ権を維持
          firstServeTeam = currentGameScore.serviceTeam;
        }
      } else {
        // 通常のゲーム: そのゲームのサーブ権
        firstServeTeam = currentGameScore.serviceTeam;
      }
    } else {
      // ゲームがまだ開始されていない場合（次のゲームの先サーブを表示）
      if (_currentGame == 1) {
        // 1ゲーム目はマッチの先サーブ設定を使用
        firstServeTeam = match.firstServe ?? 'team1';
      } else {
        // 2ゲーム目以降は前のゲームの先サーブと逆にする（交代）
        // 前のゲームを探す（完了したゲームの中で最後のもの）
        GameScore? prevGame;
        for (var gameNum = _currentGame - 1; gameNum >= 1; gameNum--) {
          final game = scores[gameNum];
          if (game != null && game.winner != null) {
            prevGame = game;
            break;
          }
        }
        
        if (prevGame != null) {
          // 前のゲームの先サーブと逆にする（交代）
          firstServeTeam = prevGame.serviceTeam == 'team1' ? 'team2' : 'team1';
        } else {
          // 前のゲームが見つからない場合は、team1をデフォルト
          firstServeTeam = 'team1';
        }
      }
    }
    
    final hasService = firstServeTeam == team;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: hasService
          ? Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF333333), width: 1.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '○',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  /// スコアセルを構築
  /// 
  /// [gameNum] ゲーム番号（1-7）
  /// [scores] ゲームスコアのマップ
  /// [team] 表示するチーム（'team1' または 'team2'）
  /// 
  /// 各ゲームのスコアは対応する列に固定表示されます。
  /// 1ゲームが終わるまで、そのゲームの列だけが更新されます。
  Widget _buildScoreCell(int gameNum, Map<int, GameScore> scores, String team) {
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

  Widget _buildGamesCell(int games) {
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

  Widget _buildTeamButton(
    String players,
    String club,
    bool isActive,
    VoidCallback? onTap,
  ) {
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
