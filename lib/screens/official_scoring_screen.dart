import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/screens/main_menu_screen.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _detailMode = false; // 詳細入力モード
  bool _isSubscribed = false; // サブスク状態
  List<PointDetail> _pointDetails = []; // 詳細ポイントデータ

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    _loadDetailModeSetting();
    _loadMatchData();
  }

  /// サブスクリプション状態を読み込む
  Future<void> _loadSubscriptionStatus() async {
    final isSubscribed = await SubscriptionService.isSubscribed();
    setState(() {
      _isSubscribed = isSubscribed;
      // サブスク解除された場合、詳細モードをオフにする
      if (!isSubscribed && _detailMode) {
        _detailMode = false;
        _saveDetailModeSetting(false);
      }
    });
  }

  /// 詳細入力モード設定を読み込む
  Future<void> _loadDetailModeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final isSubscribed = await SubscriptionService.isSubscribed();
    setState(() {
      // サブスク加入者のみ詳細モードを有効化できる
      if (isSubscribed) {
        _detailMode = prefs.getBool('detail_mode') ?? false;
      } else {
        // フリープランの場合は必ずOFF
        _detailMode = false;
      }
    });
  }

  /// 詳細入力モード設定を保存
  Future<void> _saveDetailModeSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('detail_mode', value);
  }

  /// プレミアム機能のダイアログを表示
  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFF9800),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'プレミアム機能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '「分析+」はプレミアムプランの機能です。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              '分析+機能で記録できる内容：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text('• 1stサーブ成功/フォルト'),
            Text('• ウィナー/エラー（選手別）'),
            SizedBox(height: 12),
            Text(
              'これらのデータを基に詳細な統計分析が可能になります。',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);
    final match = await DatabaseHelper.instance.getMatch(widget.matchId);
    final gameScores =
        await DatabaseHelper.instance.getGameScoresByMatchId(widget.matchId);
    final pointDetails =
        await DatabaseHelper.instance.getPointDetailsByMatchId(widget.matchId);
    
    setState(() {
      _match = match;
      _gameScores = gameScores;
      _pointDetails = pointDetails;
      
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

  /// ゲーム開始時の最初のサーバー選手を決定
  /// 
  /// [gameNumber] ゲーム番号
  /// [previousGameServiceTeam] 前のゲームのサーブ権チーム（nullの場合は1ゲーム目）
  /// 
  /// 戻り値: 最初のサーバー選手名
  String _getFirstServerPlayerForGame(int gameNumber, String? previousGameServiceTeam) {
    if (_match == null) return '';
    
    if (gameNumber == 1) {
      // 1ゲーム目: マッチの先サーブ設定から決定
      final firstServeTeam = _match!.firstServe ?? 'team1';
      if (firstServeTeam == 'team1') {
        return _match!.team1Player1; // チーム1の最初の選手
      } else {
        return _match!.team2Player1; // チーム2の最初の選手
      }
    } else {
      // 2ゲーム目以降: 前のゲームのサーブ権と逆のチームから開始
      if (previousGameServiceTeam == null) {
        // 前のゲーム情報がない場合は、デフォルトでteam2から開始
        return _match!.team2Player1;
      }
      
      // 前のゲームのサーブ権と逆のチームから開始
      if (previousGameServiceTeam == 'team1') {
        return _match!.team2Player1; // チーム2の最初の選手
      } else {
        return _match!.team1Player1; // チーム1の最初の選手
      }
    }
  }

  /// 現在のポイントでのサーバー選手を計算
  /// 
  /// [firstServerPlayer] ゲーム開始時の最初のサーバー選手名
  /// [totalPoints] 現在のゲームの合計ポイント数（追加前）
  /// [isFinalGame] ファイナルゲームかどうか
  /// 
  /// 戻り値: 現在のサーバー選手名
  String _getCurrentServerPlayer(String firstServerPlayer, int totalPoints, bool isFinalGame) {
    if (_match == null) return '';
    
    // 最初のサーバーがどのチームに属するかを判定
    final isFirstServerTeam1 = firstServerPlayer == _match!.team1Player1 || 
                               firstServerPlayer == _match!.team1Player2;
    
    String player1, player2;
    if (isFirstServerTeam1) {
      player1 = _match!.team1Player1;
      player2 = _match!.team1Player2;
    } else {
      player1 = _match!.team2Player1;
      player2 = _match!.team2Player2;
    }
    
    // 最初のサーバーがplayer1かplayer2かを判定
    final isFirstServerPlayer1 = firstServerPlayer == player1;
    
    if (isFinalGame) {
      // ファイナルゲーム: 2ポイントごとに交代
      // 0-1: player1(A), 2-3: 相手player1(C), 4-5: player2(B), 6-7: 相手player2(D), 8-9: player1(A)...
      // ポイント数を2で割った商で判定
      final serveRotation = (totalPoints ~/ 2) % 4;
      if (serveRotation == 0) {
        // 0-1ポイント目: 最初のサーバー（A）
        return isFirstServerPlayer1 ? player1 : player2;
      } else if (serveRotation == 1) {
        // 2-3ポイント目: 相手チームのplayer1（C）
        final opponentPlayer1 = isFirstServerTeam1 ? _match!.team2Player1 : _match!.team1Player1;
        return opponentPlayer1;
      } else if (serveRotation == 2) {
        // 4-5ポイント目: 同じペア内のもう一人（B）
        return isFirstServerPlayer1 ? player2 : player1;
      } else {
        // 6-7ポイント目: 相手チームのplayer2（D）
        final opponentPlayer2 = isFirstServerTeam1 ? _match!.team2Player2 : _match!.team1Player2;
        return opponentPlayer2;
      }
    } else {
      // 通常のゲーム: 2ポイントごとに交代（同じペア内で）
      // ポイント数を2で割った商が偶数の場合、最初のサーバーと同じ選手
      // 奇数の場合、最初のサーバーと逆の選手
      final serveRotation = (totalPoints ~/ 2) % 2;
      if (serveRotation == 0) {
        return isFirstServerPlayer1 ? player1 : player2;
      } else {
        return isFirstServerPlayer1 ? player2 : player1;
      }
    }
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

    // ファイナルゲームかどうかを判定
    final isFinalGame = _isFinalGame(_currentGame);
    
    // 現在のポイント数（追加前）を計算
    final totalPointsBefore = team1Score + team2Score;
    
    // 現在のサーバー選手を計算（ポイント追加前）
    String? currentServerPlayer;
    if (currentGameScore == null) {
      // 新しいゲームの場合、最初のサーバーを決定
      String? previousGameServiceTeam;
      if (_currentGame > 1 && _gameScores.isNotEmpty) {
        // 完了したゲームの中で最後のものを探す
        for (var score in _gameScores.reversed) {
          if (score.winner != null) {
            previousGameServiceTeam = score.serviceTeam;
            break;
          }
        }
      }
      currentServerPlayer = _getFirstServerPlayerForGame(_currentGame, previousGameServiceTeam);
    } else {
      // 既存のゲームの場合、ゲーム開始時の最初のサーバーを取得
      String? previousGameServiceTeam;
      if (_currentGame > 1 && _gameScores.isNotEmpty) {
        // 前の完了したゲームのサーブ権を取得
        for (var score in _gameScores.reversed) {
          if (score.gameNumber == _currentGame - 1 && score.winner != null) {
            previousGameServiceTeam = score.serviceTeam;
            break;
          }
        }
      }
      final firstServerPlayer = _getFirstServerPlayerForGame(_currentGame, previousGameServiceTeam);
      currentServerPlayer = _getCurrentServerPlayer(firstServerPlayer, totalPointsBefore, isFinalGame);
    }

    // 詳細入力モードがONの場合、詳細入力ダイアログを表示
    if (_detailMode) {
      final pointDetail = await _showPointDetailDialog(team, currentServerPlayer ?? '');
      if (pointDetail == null) {
        // キャンセルされた場合は何もしない
        return;
      }
    } else {
      // 詳細入力モードがOFFでも、最低限のPointDetailを保存（一つ戻る用）
      // サーブ側チームを決定
      String serverTeam;
      if (currentGameScore != null) {
        serverTeam = currentGameScore.serviceTeam ?? 'team1';
      } else {
        // 新しいゲームの場合
        if (_currentGame == 1) {
          serverTeam = _match!.firstServe ?? 'team1';
        } else if (_gameScores.isNotEmpty) {
          GameScore? lastCompletedGame;
          for (var score in _gameScores.reversed) {
            if (score.winner != null) {
              lastCompletedGame = score;
              break;
            }
          }
          serverTeam = lastCompletedGame?.serviceTeam == 'team1' ? 'team2' : 'team1';
        } else {
          serverTeam = 'team1';
        }
      }
      
      // 現在のゲームのポイント数を計算
      final currentGamePoints = _pointDetails.where(
        (p) => p.matchId == widget.matchId && p.gameNumber == _currentGame
      ).length;
      
      // 最低限のPointDetailを作成して保存
      final simplePointDetail = PointDetail(
        matchId: widget.matchId,
        gameNumber: _currentGame,
        pointNumber: currentGamePoints + 1,
        serverTeam: serverTeam,
        serverPlayer: currentServerPlayer,
        firstServeIn: true, // デフォルト値
        pointWinner: team,
        pointType: 'opponent_error', // デフォルト値
        actionPlayer: null,
        createdAt: DateTime.now(),
      );
      
      await DatabaseHelper.instance.insertPointDetail(simplePointDetail);
      setState(() {
        _pointDetails.add(simplePointDetail);
      });
    }

    // ポイントを加算
    if (team == 'team1') {
      team1Score++;
    } else {
      team2Score++;
    }
    
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
            winner: matchWinner, // 勝利チームを設定
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
    
    // 最後のポイントを取ったチームを特定（ポイント詳細から取得）
    String? lastPointWinner;
    if (_pointDetails.isNotEmpty) {
      // 現在のゲームの最後のポイント詳細を探す
      PointDetail? lastPointDetail;
      for (var point in _pointDetails.reversed) {
        if (point.matchId == widget.matchId && point.gameNumber == lastGame.gameNumber) {
          lastPointDetail = point;
          break;
        }
      }
      if (lastPointDetail != null) {
        lastPointWinner = lastPointDetail.pointWinner;
      }
    }
    
    // 最後のポイントを取ったチームが不明な場合、スコアから推測
    if (lastPointWinner == null) {
      if (lastGame.team1Score > lastGame.team2Score) {
        lastPointWinner = 'team1';
      } else if (lastGame.team2Score > lastGame.team1Score) {
        lastPointWinner = 'team2';
      } else {
        // 同点の場合は、デフォルトでteam1から減らす（本来は発生しないはず）
        lastPointWinner = 'team1';
      }
    }

    // 最後のポイント詳細を削除
    if (_pointDetails.isNotEmpty) {
      await DatabaseHelper.instance.deleteLastPointDetail(widget.matchId);
      setState(() {
        _pointDetails.removeLast();
      });
    }

    if (lastGame.team1Score == 0 && lastGame.team2Score == 0) {
      // ゲームが空の場合は削除
      await DatabaseHelper.instance.deleteGameScore(lastGame.id!);
      setState(() {
        _currentGame--;
      });
    } else {
      // 最後のポイントを削除（最後にポイントを取ったチームから1ポイント減らす）
      int team1Score = lastGame.team1Score;
      int team2Score = lastGame.team2Score;

      if (lastPointWinner == 'team1') {
        team1Score--;
      } else if (lastPointWinner == 'team2') {
        team2Score--;
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

      // サーブ権を計算（ファイナルゲームの場合は正しく戻す）
      String? serviceTeam;
      if (isFinalGame) {
        // ファイナルゲーム: 戻した後のポイント数でサーブ権を計算
        final totalPointsAfterUndo = team1Score + team2Score;
        
        // ゲーム開始時のサーブ権を取得
        String initialServiceTeam;
        if (lastGame.gameNumber == 1) {
          initialServiceTeam = _match!.firstServe ?? 'team1';
        } else {
          // 前のゲームの最後のサーブ権と逆
          GameScore? previousGame;
          for (var score in _gameScores.reversed) {
            if (score.gameNumber == lastGame.gameNumber - 1 && score.winner != null) {
              previousGame = score;
              break;
            }
          }
          initialServiceTeam = previousGame?.serviceTeam == 'team1' ? 'team2' : 'team1';
        }
        
        // 2ポイントごとにサーブ権が交代
        final serveRotation = (totalPointsAfterUndo ~/ 2) % 2;
        if (serveRotation == 0) {
          serviceTeam = initialServiceTeam;
        } else {
          serviceTeam = initialServiceTeam == 'team1' ? 'team2' : 'team1';
        }
      } else {
        // 通常のゲーム: サーブ権は維持
        serviceTeam = lastGame.serviceTeam;
      }

      final updatedGameScore = GameScore(
        id: lastGame.id,
        matchId: widget.matchId,
        gameNumber: lastGame.gameNumber,
        team1Score: team1Score,
        team2Score: team2Score,
        serviceTeam: serviceTeam,
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
      
      // マッチデータを再読み込みして、_isMatchCompletedフラグを更新
      await _loadMatchData();
    }
  }

  /// 詳細入力ダイアログを表示
  /// 
  /// [pointWinner] ポイントを獲得するチーム（'team1' or 'team2'）
  /// [serverPlayer] サーブを打った選手名
  /// 戻り値: ポイント詳細データ。キャンセルの場合はnull
  Future<PointDetail?> _showPointDetailDialog(String pointWinner, String serverPlayer) async {
    if (_match == null) return null;

    // 現在のゲーム情報を取得
    GameScore? currentGameScore;
    int currentGameNum = _currentGame;
    for (var score in _gameScores.reversed) {
      if (score.winner == null) {
        currentGameScore = score;
        currentGameNum = score.gameNumber;
        break;
      }
    }
    
    // サーブ側チームを決定
    String serverTeam;
    if (currentGameScore != null) {
      serverTeam = currentGameScore.serviceTeam ?? 'team1';
    } else {
      // 新しいゲームの場合
      if (currentGameNum == 1) {
        serverTeam = _match!.firstServe ?? 'team1';
      } else if (_gameScores.isNotEmpty) {
        final lastGame = _gameScores.last;
        serverTeam = lastGame.serviceTeam == 'team1' ? 'team2' : 'team1';
      } else {
        serverTeam = 'team1';
      }
    }

    // 現在のゲームのポイント数を計算
    final currentGamePoints = _pointDetails.where(
      (p) => p.matchId == widget.matchId && p.gameNumber == currentGameNum
    ).length;

    final result = await showDialog<PointDetail?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _PointDetailDialog(
          matchId: widget.matchId,
          gameNumber: currentGameNum,
          pointNumber: currentGamePoints + 1,
          serverTeam: serverTeam,
          serverPlayer: serverPlayer,
          pointWinner: pointWinner,
          team1Player1: _match!.team1Player1,
          team1Player2: _match!.team1Player2,
          team2Player1: _match!.team2Player1,
          team2Player2: _match!.team2Player2,
        );
      },
    );

    if (result != null) {
      // ポイント詳細を保存
      await DatabaseHelper.instance.insertPointDetail(result);
      
      // 詳細リストを更新
      setState(() {
        _pointDetails.add(result);
      });
    }

    return result;
  }

  /// 試合設定ダイアログを表示
  Future<void> _showMatchSettingsDialog() async {
    if (_match == null) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _MatchSettingsDialog(
          initialTournamentName: _match!.tournamentName,
          initialTeam1Player1: _match!.team1Player1,
          initialTeam1Player2: _match!.team1Player2,
          initialTeam1Club: _match!.team1Club,
          initialTeam2Player1: _match!.team2Player1,
          initialTeam2Player2: _match!.team2Player2,
          initialTeam2Club: _match!.team2Club,
          initialFirstServe: _match!.firstServe,
        );
      },
    );

    if (result != null && _match != null) {
      // 名前変更があった場合、point_detailsも更新する
      final oldTeam1Player1 = _match!.team1Player1;
      final oldTeam1Player2 = _match!.team1Player2;
      final oldTeam2Player1 = _match!.team2Player1;
      final oldTeam2Player2 = _match!.team2Player2;
      
      final newTeam1Player1 = result['team1Player1'] as String;
      final newTeam1Player2 = result['team1Player2'] as String;
      final newTeam2Player1 = result['team2Player1'] as String;
      final newTeam2Player2 = result['team2Player2'] as String;
      
      // 各選手の名前変更をチェックしてpoint_detailsを更新
      if (_match!.id != null) {
        if (oldTeam1Player1 != newTeam1Player1 && oldTeam1Player1.isNotEmpty) {
          await DatabaseHelper.instance.updatePlayerNameInPointDetails(
            _match!.id!,
            oldTeam1Player1,
            newTeam1Player1,
          );
        }
        if (oldTeam1Player2 != newTeam1Player2 && oldTeam1Player2.isNotEmpty) {
          await DatabaseHelper.instance.updatePlayerNameInPointDetails(
            _match!.id!,
            oldTeam1Player2,
            newTeam1Player2,
          );
        }
        if (oldTeam2Player1 != newTeam2Player1 && oldTeam2Player1.isNotEmpty) {
          await DatabaseHelper.instance.updatePlayerNameInPointDetails(
            _match!.id!,
            oldTeam2Player1,
            newTeam2Player1,
          );
        }
        if (oldTeam2Player2 != newTeam2Player2 && oldTeam2Player2.isNotEmpty) {
          await DatabaseHelper.instance.updatePlayerNameInPointDetails(
            _match!.id!,
            oldTeam2Player2,
            newTeam2Player2,
          );
        }
      }
      
      // マッチ情報を更新
      final updatedMatch = Match(
        id: _match!.id,
        tournamentName: result['tournamentName'] as String,
        team1Player1: newTeam1Player1,
        team1Player2: newTeam1Player2,
        team1Club: result['team1Club'] as String,
        team2Player1: newTeam2Player1,
        team2Player2: newTeam2Player2,
        team2Club: result['team2Club'] as String,
        gameCount: _match!.gameCount,
        firstServe: result['firstServe'] as String?,
        createdAt: _match!.createdAt,
        completedAt: _match!.completedAt,
        winner: _match!.winner,
      );
      await DatabaseHelper.instance.updateMatch(updatedMatch);
      
      // _pointDetailsのメモリ上のデータも更新
      setState(() {
        _pointDetails = _pointDetails.map((point) {
          var updatedPoint = point;
          
          // serverPlayerの更新
          if (updatedPoint.serverPlayer == oldTeam1Player1) {
            updatedPoint = updatedPoint.copyWith(serverPlayer: newTeam1Player1);
          } else if (updatedPoint.serverPlayer == oldTeam1Player2) {
            updatedPoint = updatedPoint.copyWith(serverPlayer: newTeam1Player2);
          } else if (updatedPoint.serverPlayer == oldTeam2Player1) {
            updatedPoint = updatedPoint.copyWith(serverPlayer: newTeam2Player1);
          } else if (updatedPoint.serverPlayer == oldTeam2Player2) {
            updatedPoint = updatedPoint.copyWith(serverPlayer: newTeam2Player2);
          }
          
          // actionPlayerの更新
          if (updatedPoint.actionPlayer == oldTeam1Player1) {
            updatedPoint = updatedPoint.copyWith(actionPlayer: newTeam1Player1);
          } else if (updatedPoint.actionPlayer == oldTeam1Player2) {
            updatedPoint = updatedPoint.copyWith(actionPlayer: newTeam1Player2);
          } else if (updatedPoint.actionPlayer == oldTeam2Player1) {
            updatedPoint = updatedPoint.copyWith(actionPlayer: newTeam2Player1);
          } else if (updatedPoint.actionPlayer == oldTeam2Player2) {
            updatedPoint = updatedPoint.copyWith(actionPlayer: newTeam2Player2);
          }
          
          return updatedPoint;
        }).toList();
      });
      
      await _loadMatchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('試合設定を保存しました'),
            duration: Duration(seconds: 2),
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
              _match!.tournamentName.isEmpty ? '大会名なし' : _match!.tournamentName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        actions: [
          // 分析+モード切り替え（プレミアム機能）
          GestureDetector(
            onTap: () {
              if (!_isSubscribed) {
                _showPremiumRequiredDialog();
                return;
              }
              setState(() {
                _detailMode = !_detailMode;
              });
              _saveDetailModeSetting(_detailMode);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _detailMode && _isSubscribed ? const Color(0xFF1E293B) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _detailMode && _isSubscribed ? const Color(0xFF1E293B) : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isSubscribed)
                    const Icon(
                      Icons.lock,
                      size: 12,
                      color: Color(0xFF888888),
                    )
                  else
                    Icon(
                      _detailMode ? Icons.check_circle : Icons.circle_outlined,
                      size: 14,
                      color: _detailMode ? Colors.white : const Color(0xFFAAAAAA),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    '分析+',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isSubscribed
                          ? (_detailMode ? Colors.white : const Color(0xFF666666))
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF333333)),
            onPressed: () => _showMatchSettingsDialog(),
          ),
        ],
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
                            // 現在のゲーム数から勝者を判定
                            int team1Games = 0;
                            int team2Games = 0;
                            for (var score in _gameScores) {
                              if (score.winner == 'team1') {
                                team1Games++;
                              } else if (score.winner == 'team2') {
                                team2Games++;
                              }
                            }
                            // 勝者を決定（ゲーム数が多い方が勝ち）
                            String? matchWinner;
                            if (team1Games > team2Games) {
                              matchWinner = 'team1';
                            } else if (team2Games > team1Games) {
                              matchWinner = 'team2';
                            }
                            // 同点の場合はnull（引き分け扱い）
                            
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
                              winner: matchWinner, // 勝利チームを設定
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
        // 次のポイントのサーブ権を表示するため、totalPoints + 1で判定
        final totalPoints = currentGameScore.team1Score + currentGameScore.team2Score;
        final nextPoint = totalPoints + 1;
        
        // ゲーム開始時のサーブ権を取得
        String initialServiceTeam;
        if (_currentGame == 1) {
          initialServiceTeam = match.firstServe ?? 'team1';
        } else {
          // 前のゲームのサーブ権と逆
          GameScore? previousGame;
          for (var gameNum = _currentGame - 1; gameNum >= 1; gameNum--) {
            final game = scores[gameNum];
            if (game != null && game.winner != null) {
              previousGame = game;
              break;
            }
          }
          initialServiceTeam = previousGame?.serviceTeam == 'team1' ? 'team2' : 'team1';
        }
        
        // 次のポイントが何ポイント目かで判定（2ポイントごとに交代）
        final serveRotation = ((nextPoint - 1) ~/ 2) % 2;
        if (serveRotation == 0) {
          firstServeTeam = initialServiceTeam;
        } else {
          firstServeTeam = initialServiceTeam == 'team1' ? 'team2' : 'team1';
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

/// 試合設定ダイアログ（独立したStatefulWidget）
class _MatchSettingsDialog extends StatefulWidget {
  final String initialTournamentName;
  final String initialTeam1Player1;
  final String initialTeam1Player2;
  final String initialTeam1Club;
  final String initialTeam2Player1;
  final String initialTeam2Player2;
  final String initialTeam2Club;
  final String? initialFirstServe;

  const _MatchSettingsDialog({
    required this.initialTournamentName,
    required this.initialTeam1Player1,
    required this.initialTeam1Player2,
    required this.initialTeam1Club,
    required this.initialTeam2Player1,
    required this.initialTeam2Player2,
    required this.initialTeam2Club,
    this.initialFirstServe,
  });

  @override
  State<_MatchSettingsDialog> createState() => _MatchSettingsDialogState();
}

class _MatchSettingsDialogState extends State<_MatchSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _firstServe;
  
  late TextEditingController _tournamentNameController;
  late TextEditingController _team1Player1Controller;
  late TextEditingController _team1Player2Controller;
  late TextEditingController _team1ClubController;
  late TextEditingController _team2Player1Controller;
  late TextEditingController _team2Player2Controller;
  late TextEditingController _team2ClubController;

  @override
  void initState() {
    super.initState();
    _firstServe = widget.initialFirstServe;
    _tournamentNameController = TextEditingController(text: widget.initialTournamentName);
    _team1Player1Controller = TextEditingController(text: widget.initialTeam1Player1);
    _team1Player2Controller = TextEditingController(text: widget.initialTeam1Player2);
    _team1ClubController = TextEditingController(text: widget.initialTeam1Club);
    _team2Player1Controller = TextEditingController(text: widget.initialTeam2Player1);
    _team2Player2Controller = TextEditingController(text: widget.initialTeam2Player2);
    _team2ClubController = TextEditingController(text: widget.initialTeam2Club);
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _team1Player1Controller.dispose();
    _team1Player2Controller.dispose();
    _team1ClubController.dispose();
    _team2Player1Controller.dispose();
    _team2Player2Controller.dispose();
    _team2ClubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        '試合設定',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // イベント名
              const Text(
                '大会・イベント名',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF7F7F7F),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tournamentNameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '大会・イベント名を入力してください';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: '大会名など',
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              // ペアA
              _buildPairSection(
                'ペアA',
                _team1ClubController,
                _team1Player1Controller,
                _team1Player2Controller,
                isFirstServe: _firstServe == 'team1',
              ),
              const SizedBox(height: 16),
              // ペアB
              _buildPairSection(
                'ペアB',
                _team2ClubController,
                _team2Player1Controller,
                _team2Player2Controller,
                isFirstServe: _firstServe == 'team2',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'キャンセル',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF333333),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      // バリデーション：同じペア内で同じ選手チェック
      final team1Player1 = _team1Player1Controller.text.trim();
      final team1Player2 = _team1Player2Controller.text.trim();
      final team2Player1 = _team2Player1Controller.text.trim();
      final team2Player2 = _team2Player2Controller.text.trim();

      if (team1Player1 == team1Player2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペアAで同じ選手が選択されています'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (team2Player1 == team2Player2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ペアBで同じ選手が選択されています'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ペア間で同じ選手（名前と所属の組み合わせ）チェック
      final team1Club = _team1ClubController.text.trim();
      final team2Club = _team2ClubController.text.trim();

      final team1Players = [
        {'name': team1Player1, 'club': team1Club},
        {'name': team1Player2, 'club': team1Club},
      ];
      final team2Players = [
        {'name': team2Player1, 'club': team2Club},
        {'name': team2Player2, 'club': team2Club},
      ];

      final duplicatePlayers = <String>[];
      for (var p1 in team1Players) {
        for (var p2 in team2Players) {
          if (p1['name'] == p2['name'] && p1['club'] == p2['club']) {
            duplicatePlayers.add(p1['name'] as String);
          }
        }
      }

      if (duplicatePlayers.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ペアAとペアBに同じ選手（${duplicatePlayers.join('、')}）が含まれています'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.of(context).pop({
        'firstServe': _firstServe,
        'tournamentName': _tournamentNameController.text.trim(),
        'team1Player1': team1Player1,
        'team1Player2': team1Player2,
        'team1Club': team1Club,
        'team2Player1': team2Player1,
        'team2Player2': team2Player2,
        'team2Club': team2Club,
      });
    }
  }

  Widget _buildPairSection(
    String label,
    TextEditingController clubController,
    TextEditingController player1Controller,
    TextEditingController player2Controller, {
    required bool isFirstServe,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              // 先サーブ表示（変更不可）
              if (isFirstServe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '先サーブ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 所属
          TextFormField(
            controller: clubController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '所属を入力してください';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: '所属',
              labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          // 選手
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: player1Controller,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '選手1を入力';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: '選手1',
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: player2Controller,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '選手2を入力';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: '選手2',
                    labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分析+入力ダイアログ
/// 
/// ポイントごとの詳細情報を入力するダイアログです。
/// 選手名をタップして選択すると自動で保存されます。
class _PointDetailDialog extends StatefulWidget {
  final int matchId;
  final int gameNumber;
  final int pointNumber;
  final String serverTeam;
  final String serverPlayer;
  final String pointWinner;
  final String team1Player1;
  final String team1Player2;
  final String team2Player1;
  final String team2Player2;

  const _PointDetailDialog({
    required this.matchId,
    required this.gameNumber,
    required this.pointNumber,
    required this.serverTeam,
    required this.serverPlayer,
    required this.pointWinner,
    required this.team1Player1,
    required this.team1Player2,
    required this.team2Player1,
    required this.team2Player2,
  });

  @override
  State<_PointDetailDialog> createState() => _PointDetailDialogState();
}

class _PointDetailDialogState extends State<_PointDetailDialog> {
  bool _firstServeIn = true;

  // 得点チームの選手リスト
  List<String> get _winnerPlayers {
    if (widget.pointWinner == 'team1') {
      return [widget.team1Player1, widget.team1Player2];
    } else {
      return [widget.team2Player1, widget.team2Player2];
    }
  }

  // 失点チームの選手リスト
  List<String> get _loserPlayers {
    if (widget.pointWinner == 'team1') {
      return [widget.team2Player1, widget.team2Player2];
    } else {
      return [widget.team1Player1, widget.team1Player2];
    }
  }

  // サーブ側が得点したか
  bool get _serverWon => widget.serverTeam == widget.pointWinner;

  void _selectAndSave(String pointType, String actionPlayer) {
    final pointDetail = PointDetail(
      matchId: widget.matchId,
      gameNumber: widget.gameNumber,
      pointNumber: widget.pointNumber,
      serverTeam: widget.serverTeam,
      serverPlayer: widget.serverPlayer.isNotEmpty ? widget.serverPlayer : null,
      firstServeIn: _firstServeIn,
      pointWinner: widget.pointWinner,
      pointType: pointType,
      actionPlayer: actionPlayer,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pop(pointDetail);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ヘッダー
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.insights,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '分析+',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showPointTypeInfo(context),
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1stサーブ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '1stサーブ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                          if (widget.serverPlayer.isNotEmpty)
                            Text(
                              'サーバー: ${widget.serverPlayer}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF999999),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _firstServeIn = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _firstServeIn 
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _firstServeIn 
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFE5E5E5),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'IN',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _firstServeIn 
                                          ? Colors.white 
                                          : const Color(0xFF888888),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _firstServeIn = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_firstServeIn 
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !_firstServeIn 
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFE5E5E5),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'FAULT',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: !_firstServeIn 
                                          ? Colors.white 
                                          : const Color(0xFF888888),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ウィナー（得点チームの選手から選択）
                _buildPointTypeCard(
                  icon: Icons.emoji_events,
                  iconColor: const Color(0xFF1E293B),
                  title: 'ウィナー',
                  description: '攻めて決めたポイント',
                  players: _winnerPlayers,
                  pointType: PointType.winner,
                ),
                const SizedBox(height: 12),

                // 相手のミス（失点チームの選手から選択）
                _buildPointTypeCard(
                  icon: Icons.close,
                  iconColor: const Color(0xFF888888),
                  title: '相手のミス',
                  description: '相手のエラーで得点',
                  players: _loserPlayers,
                  pointType: PointType.opponentError,
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointTypeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> players,
    required String pointType,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: players.map((player) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: players.indexOf(player) == 0 ? 6 : 0,
                    left: players.indexOf(player) == 1 ? 6 : 0,
                  ),
                  child: Material(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _selectAndSave(pointType, player),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Center(
                          child: Text(
                            player,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showPointTypeInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ポイント種類について',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                emoji: '🏆',
                title: 'ウィナー',
                description: '自分が攻めて決めたポイント',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 10),
              _buildInfoItem(
                emoji: '❌',
                title: '相手のミス',
                description: '相手のエラーで得たポイント',
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '閉じる',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required String emoji,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
