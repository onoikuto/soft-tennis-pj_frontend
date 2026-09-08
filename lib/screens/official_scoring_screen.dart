import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/services/ai_insight_service.dart';
import 'package:soft_tennis_scoring/services/live_coach_service.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/pair_report.dart';
import 'package:soft_tennis_scoring/services/statistics_calculator.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/screens/main_menu_screen.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';
import 'package:soft_tennis_scoring/utils/game_rules.dart';
import 'package:soft_tennis_scoring/widgets/scoring/match_settings_dialog.dart';
import 'package:soft_tennis_scoring/widgets/common/pair_report_view.dart';
import 'package:soft_tennis_scoring/widgets/scoring/game_report_card.dart';
import 'package:soft_tennis_scoring/widgets/scoring/point_detail_dialog.dart';
import 'package:soft_tennis_scoring/widgets/scoring/score_table_cells.dart';
import 'package:soft_tennis_scoring/widgets/scoring/scoring_sheet_table.dart';
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
  bool _firstServeIn = true; // 1stサーブ選択（メイン画面用）
  List<PointDetail> _pointDetails = []; // 詳細ポイントデータ

  /// 自分側のチーム（'team1' / 'team2'）
  ///
  /// 統計画面で直近に見ていた対象から決めます。手がかりがないときは
  /// チーム1として扱います（統計まわりの既存の挙動に合わせています）。
  String _myTeam = 'team1';

  /// いま表示しているゲームごとの振り返り（未表示のときnull）
  GameReportMessage? _gameReport;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    _loadDetailModeSetting();
    _loadMatchData();
  }

  @override
  void dispose() {
    // 端末内LLMはメモリを大きく使うので、試合画面を離れたら解放する
    unawaited(LiveCoachService.onLeaveMatch());
    super.dispose();
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

  /// 自分側のチームを、統計画面で直近に見ていた対象から決める
  ///
  /// 採点票は両チームぶんを記録するため、どちら側に向けて助言するかを
  /// 決めないと、相手への助言が出てしまいます。
  Future<void> _resolveMyTeam() async {
    final match = _match;
    if (match == null) return;

    StatsSubject? subject;
    try {
      subject = await AiInsightService.lastViewedSubject();
    } catch (e) {
      debugPrint('自チームの判定に失敗（チーム1として扱います）: $e');
      return;
    }
    if (subject == null || !subject.covers(match)) return;

    final team = subject.isTeam1(match) ? 'team1' : 'team2';
    if (!mounted || team == _myTeam) return;
    setState(() => _myTeam = team);
  }

  /// 試合が終わったところで、この試合だけの振り返りを出す
  ///
  /// 統計画面（累計）と同じ作り方・同じ見た目を使います。数字は同じなのに
  /// 言い方が違う、という事故を避けるためです。
  Future<void> _showMatchReport() async {
    final match = _match;
    if (match == null || !mounted) return;
    if (!await LiveCoachService.isEntitled()) return;
    if (!mounted) return;

    final stats = AdvancedPointStats()
      ..addMatch(
        myTeam: _myTeam,
        points: _pointDetails,
        gameScores: _gameScores,
        gameCount: match.gameCount,
      );

    final report = PairReport.build(
      stats,
      playerNames: _myTeam == 'team1'
          ? [match.team1Player1, match.team1Player2]
          : [match.team2Player1, match.team2Player2],
    );
    if (!report.hasContent || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'この試合の振り返り',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(child: PairReportView(report: report)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// ゲームが終わったところで、ここまでの傾向を取り直す
  ///
  /// 生成に数秒かかることがあるため、**待たずに**進めます。入力が止まると
  /// 採点票として使い物にならないためです。間に合ったぶんだけ画面に出します。
  void _refreshGameReport() {
    final match = _match;
    if (match == null || _isMatchCompleted) return;

    final stats = AdvancedPointStats()
      ..addMatch(
        myTeam: _myTeam,
        points: _pointDetails,
        gameScores: _gameScores,
        gameCount: match.gameCount,
      );

    final report = PairReport.build(
      stats,
      playerNames: _myTeam == 'team1'
          ? [match.team1Player1, match.team1Player2]
          : [match.team2Player1, match.team2Player2],
    );

    LiveCoachService.report(report).then((message) {
      if (!mounted) return;
      // 出せる材料が無くなったときは消す（古い内容が残らないように）
      setState(() => _gameReport = message);
    }).catchError((Object e) {
      // 振り返りが出せなくても採点の邪魔はしない
      debugPrint('ゲームごとの振り返りの取得に失敗: $e');
    });
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

    // 試合が終わったら振り返りカードは残さない（画面に居座るため）
    if (_isMatchCompleted && _gameReport != null) {
      setState(() => _gameReport = null);
    }

    await _resolveMyTeam();
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

  /// 現在のサーバー選手名を取得（UI表示用）
  String _getCurrentServerPlayerName() {
    if (_match == null) return '---';
    
    // 試合が終了している場合
    if (_isMatchCompleted) return '---';
    
    // 現在のゲームのスコアを取得
    GameScore? currentGameScore;
    for (var score in _gameScores.reversed) {
      if (score.winner == null) {
        currentGameScore = score;
        break;
      }
    }
    
    // ゲームが開始されていない場合でも、次のゲームのサーバーを表示
    if (currentGameScore == null) {
      // 次のゲームの最初のサーバーを取得
      String? previousGameServiceTeam;
      if (_currentGame > 1 && _gameScores.isNotEmpty) {
        for (var score in _gameScores.reversed) {
          if (score.gameNumber == _currentGame - 1 && score.winner != null) {
            previousGameServiceTeam = score.serviceTeam;
            break;
          }
        }
      }
      return _getFirstServerPlayerForGame(_currentGame, previousGameServiceTeam);
    }
    
    final isFinalGame = _isFinalGame(_currentGame);
    final totalPoints = currentGameScore.team1Score + currentGameScore.team2Score;
    
    // ゲーム開始時の最初のサーバーを取得
    String? previousGameServiceTeam;
    if (_currentGame > 1 && _gameScores.isNotEmpty) {
      for (var score in _gameScores.reversed) {
        if (score.gameNumber == _currentGame - 1 && score.winner != null) {
          previousGameServiceTeam = score.serviceTeam;
          break;
        }
      }
    }
    final firstServerPlayer = _getFirstServerPlayerForGame(_currentGame, previousGameServiceTeam);
    
    return _getCurrentServerPlayer(firstServerPlayer, totalPoints, isFinalGame);
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
      final pointDetail = await _showPointDetailDialog(team, currentServerPlayer ?? '', _firstServeIn);
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
        firstServeIn: _firstServeIn, // メイン画面で選択した値を使用
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
          // 試合が1つ増えたので、AI分析を作り直す予約を入れる。
          // すぐには走らず、最後の保存から少し待ってから1回だけ生成される。
          await AiInsightService.scheduleGenerationAfterMatchSaved();
          // この試合だけの振り返りをその場で見せる
          await _showMatchReport();
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

    // 振り返りはゲームが終わったところでだけ出す。
    // 生成は待たない（採点の手を止めないため）。
    if (winner != null) {
      _refreshGameReport();
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
    return GameRules.isFinalGame(
      gameCount: _match!.gameCount,
      gameScores: _gameScores,
      gameNumber: gameNumber,
    );
  }

  /// 勝利に必要なゲーム数を取得
  int _getRequiredGamesToWin() {
    if (_match == null) return 4;
    return GameRules.requiredGamesToWin(_match!.gameCount);
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

  /// 一つ戻るボタンが有効かどうかを判定
  bool _canUndo() {
    if (_gameScores.isEmpty) return false;
    
    final lastGame = _gameScores.last;
    
    // 0-0の場合は戻せない
    if (lastGame.team1Score == 0 && lastGame.team2Score == 0) {
      return false;
    }
    
    return true;
  }

  Future<void> _undoLastPoint() async {
    if (_gameScores.isEmpty) return;

    final lastGame = _gameScores.last;
    
    // 0-0の場合は何もしない（試合の最初）
    if (lastGame.team1Score == 0 && lastGame.team2Score == 0) {
      return;
    }
    
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
  /// [initialFirstServeIn] メイン画面で選択された1stサーブの状態
  /// 戻り値: ポイント詳細データ。キャンセルの場合はnull
  Future<PointDetail?> _showPointDetailDialog(String pointWinner, String serverPlayer, bool initialFirstServeIn) async {
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
        return PointDetailDialog(
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
          initialFirstServeIn: initialFirstServeIn, // メイン画面の選択を渡す
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
        return MatchSettingsDialog(
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
                  // 採点表（公式採点票と同じ形式・表示専用。入力は下部のボタンから）
                  ScoringSheetTable(
                    match: _match!,
                    gameScores: _gameScores,
                    pointDetails: _pointDetails,
                    currentGame: _currentGame,
                    isMatchCompleted: _isMatchCompleted,
                    isFinalGame: _isFinalGame,
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
                // ゲームごとの振り返り（プレミアム限定・入力ボタンのすぐ上に出す）
                if (_gameReport != null)
                  GameReportCard(
                    message: _gameReport!,
                    onDismiss: () => setState(() => _gameReport = null),
                  ),
                // 分析+モードがONの場合、1stサーブ選択を表示
                if (_detailMode) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF666666),
                              ),
                            ),
                            Text(
                              'サーバー: ${_getCurrentServerPlayerName()}',
                              style: const TextStyle(
                                fontSize: 11,
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
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _firstServeIn 
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
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
                                        fontSize: 12,
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _firstServeIn = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_firstServeIn 
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
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
                                        fontSize: 12,
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
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TeamScoreButton(
                        '${_match!.team1Player1}・${_match!.team1Player2}',
                        _match!.team1Club,
                        false,
                        _isMatchCompleted ? null : () => _addPoint('team1'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TeamScoreButton(
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
                        onPressed: _canUndo() ? _undoLastPoint : null,
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
                            // 試合が1つ増えたので、AI分析を作り直す予約を入れる
                            await AiInsightService
                                .scheduleGenerationAfterMatchSaved();
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

}
