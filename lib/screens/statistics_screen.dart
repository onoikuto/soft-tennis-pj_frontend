import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedView = 0; // 0: ペア単位, 1: 学校・クラブ単位, 2: 選手単位
  String? _selectedPair;
  List<String> _pairs = [];
  List<String> _organizations = [];
  List<String> _players = [];
  List<String> _filteredItems = [];
  final _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSubscribed = false;

  // 統計データ
  int _totalMatches = 0;
  double _winRate = 0.0;
  Map<int, double> _gameWinRates = {};
  double _deuceWinRate = 0.0;
  int _deuceWins = 0;
  int _deuceLosses = 0;
  double _serviceWinRate = 0.0;
  double _receiveWinRate = 0.0;
  // 追加統計
  double _finalGameWinRate = 0.0;
  int _finalGameWins = 0;
  int _finalGameTotal = 0;

  // 詳細統計（ポイント詳細データからの統計）
  double _firstServeInRate = 0.0;  // 1stサーブ成功率
  double _firstServePointRate = 0.0;  // 1stサーブ時得点率
  int _winnerCount = 0;  // ウィナー数（エース含む）
  int _myErrorCount = 0;  // 自分のミス数
  bool _hasPointDetails = false;  // ポイント詳細データがあるか

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _checkSubscriptionStatus();
    _loadStatistics();
  }
  
  Future<void> _checkSubscriptionStatus() async {
    final isSubscribed = await SubscriptionService.isSubscribed();
    setState(() {
      _isSubscribed = isSubscribed;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<String> sourceList;
      if (_selectedView == 0) {
        sourceList = _pairs;
      } else if (_selectedView == 1) {
        sourceList = _organizations;
      } else {
        sourceList = _players;
      }
      _filteredItems = sourceList
          .where((item) => item.toLowerCase().contains(query))
          .toList();
    });
  }
  
  List<String> get _currentItems {
    if (_selectedView == 0) {
      return _pairs;
    } else if (_selectedView == 1) {
      return _organizations;
    } else {
      return _players;
    }
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final matches = await DatabaseHelper.instance.getAllMatches();
      List<Match> completedMatches = matches.where((m) => m.completedAt != null).toList();
    
    // ペア、組織、個人のリストを生成
    final pairsSet = <String>{};
    final orgsSet = <String>{};
    final playersSet = <String>{};
    
    for (var match in completedMatches) {
      // ペア単位
      final pair1 = '${match.team1Player1}・${match.team1Player2}';
      final pair2 = '${match.team2Player1}・${match.team2Player2}';
      if (match.team1Club.isNotEmpty) {
        pairsSet.add('$pair1 (${match.team1Club})');
      } else {
        pairsSet.add(pair1);
      }
      if (match.team2Club.isNotEmpty) {
        pairsSet.add('$pair2 (${match.team2Club})');
      } else {
        pairsSet.add(pair2);
      }
      
      // 組織単位
      if (match.team1Club.isNotEmpty) {
        orgsSet.add(match.team1Club);
      }
      if (match.team2Club.isNotEmpty) {
        orgsSet.add(match.team2Club);
      }
      
      // 人単位（選手名 + 所属の組み合わせで一意性を保つ）
      // 所属がある場合は「選手名 (所属)」、ない場合は「選手名 (所属なし)」として区別
      final team1Player1Key = match.team1Club.isNotEmpty
          ? '${match.team1Player1} (${match.team1Club})'
          : '${match.team1Player1} (所属なし)';
      final team1Player2Key = match.team1Club.isNotEmpty
          ? '${match.team1Player2} (${match.team1Club})'
          : '${match.team1Player2} (所属なし)';
      final team2Player1Key = match.team2Club.isNotEmpty
          ? '${match.team2Player1} (${match.team2Club})'
          : '${match.team2Player1} (所属なし)';
      final team2Player2Key = match.team2Club.isNotEmpty
          ? '${match.team2Player2} (${match.team2Club})'
          : '${match.team2Player2} (所属なし)';
      
      playersSet.add(team1Player1Key);
      playersSet.add(team1Player2Key);
      playersSet.add(team2Player1Key);
      playersSet.add(team2Player2Key);
    }
    
    _pairs = pairsSet.toList()..sort();
    _organizations = orgsSet.toList()..sort();
    _players = playersSet.toList()..sort();
    
    // フィルタリング用のリストを初期化
    _filteredItems = _currentItems;
    
    // デフォルトで最初の項目を選択
    if (_currentItems.isNotEmpty && _selectedPair == null) {
      _selectedPair = _currentItems.first;
    }
    
      await _calculateStatistics();
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('統計データの読み込みエラー: $e');
      setState(() {
        _pairs = [];
        _organizations = [];
        _players = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _calculateStatistics() async {
    if (_selectedPair == null) {
      setState(() {
        _totalMatches = 0;
        _winRate = 0.0;
        _gameWinRates = {};
        _deuceWinRate = 0.0;
        _deuceWins = 0;
        _deuceLosses = 0;
        _serviceWinRate = 0.0;
        _receiveWinRate = 0.0;
        _finalGameWinRate = 0.0;
        _finalGameWins = 0;
        _finalGameTotal = 0;
      });
      return;
    }

    final matches = await DatabaseHelper.instance.getAllMatches();
    List<Match> completedMatches = matches.where((m) => m.completedAt != null).toList();
    
    // 選択されたペア、組織、または個人に関連する試合をフィルタリング
    List<Match> relevantMatches;
    bool isTeam1;
    
    if (_selectedView == 0) {
      // ペア単位
      final pairName = _selectedPair!.split(' (').first;
      relevantMatches = completedMatches.where((m) {
        final pair1 = '${m.team1Player1}・${m.team1Player2}';
        final pair2 = '${m.team2Player1}・${m.team2Player2}';
        return pair1 == pairName || pair2 == pairName;
      }).toList();
      
      // 最初の試合でどちらのチームかを判定
      if (relevantMatches.isNotEmpty) {
        final firstMatch = relevantMatches.first;
        isTeam1 = '${firstMatch.team1Player1}・${firstMatch.team1Player2}' == pairName;
      } else {
        isTeam1 = true;
      }
    } else if (_selectedView == 1) {
      // 学校・クラブ単位
      final orgName = _selectedPair!;
      relevantMatches = completedMatches.where((m) {
        return m.team1Club == orgName || m.team2Club == orgName;
      }).toList();
      
      if (relevantMatches.isNotEmpty) {
        final firstMatch = relevantMatches.first;
        isTeam1 = firstMatch.team1Club == orgName;
      } else {
        isTeam1 = true;
      }
    } else {
      // 人単位（選手名 + 所属の組み合わせで判定）
      final selectedPlayerInfo = _selectedPair!;
      String playerName;
      String? playerClub;
      
      if (selectedPlayerInfo.contains(' (')) {
        // 「山崎 (A高校)」または「山崎 (所属なし)」形式
        final parts = selectedPlayerInfo.split(' (');
        playerName = parts[0];
        final clubPart = parts[1].replaceAll(')', '');
        playerClub = clubPart == '所属なし' ? null : clubPart;
      } else {
        // フォールバック（旧形式対応）
        playerName = selectedPlayerInfo;
        playerClub = null;
      }
      
      relevantMatches = completedMatches.where((m) {
        // チーム1の選手1と一致するか
        bool match1 = m.team1Player1 == playerName;
        if (match1) {
          if (playerClub != null) {
            match1 = m.team1Club == playerClub;
          } else {
            match1 = m.team1Club.isEmpty;
          }
        }
        
        // チーム1の選手2と一致するか
        bool match2 = m.team1Player2 == playerName;
        if (match2) {
          if (playerClub != null) {
            match2 = m.team1Club == playerClub;
          } else {
            match2 = m.team1Club.isEmpty;
          }
        }
        
        // チーム2の選手1と一致するか
        bool match3 = m.team2Player1 == playerName;
        if (match3) {
          if (playerClub != null) {
            match3 = m.team2Club == playerClub;
          } else {
            match3 = m.team2Club.isEmpty;
          }
        }
        
        // チーム2の選手2と一致するか
        bool match4 = m.team2Player2 == playerName;
        if (match4) {
          if (playerClub != null) {
            match4 = m.team2Club == playerClub;
          } else {
            match4 = m.team2Club.isEmpty;
          }
        }
        
        return match1 || match2 || match3 || match4;
      }).toList();
      
      if (relevantMatches.isNotEmpty) {
        final firstMatch = relevantMatches.first;
        // チーム1にいるか判定
        bool inTeam1 = false;
        if (firstMatch.team1Player1 == playerName) {
          if (playerClub != null) {
            inTeam1 = firstMatch.team1Club == playerClub;
          } else {
            inTeam1 = firstMatch.team1Club.isEmpty;
          }
        }
        if (!inTeam1 && firstMatch.team1Player2 == playerName) {
          if (playerClub != null) {
            inTeam1 = firstMatch.team1Club == playerClub;
          } else {
            inTeam1 = firstMatch.team1Club.isEmpty;
          }
        }
        isTeam1 = inTeam1;
      } else {
        isTeam1 = true;
      }
    }

    // 統計を計算
    int wins = 0;
    int totalGames = 0;
    Map<int, int> gameWins = {};
    Map<int, int> gameTotal = {};
    int deuceWins = 0;
    int deuceTotal = 0;
    int serviceWins = 0;
    int serviceTotal = 0;
    int receiveWins = 0;
    int receiveTotal = 0;
    // 追加統計
    int finalGameWins = 0;
    int finalGameTotal = 0;

    for (var match in relevantMatches) {
      bool isThisTeam1;
      if (_selectedView == 0) {
        // ペア単位
        final pairName = _selectedPair!.split(' (').first;
        isThisTeam1 = '${match.team1Player1}・${match.team1Player2}' == pairName;
      } else if (_selectedView == 1) {
        // 学校・クラブ単位
        isThisTeam1 = match.team1Club == _selectedPair;
      } else {
        // 人単位（選手名 + 所属の組み合わせで判定）
        final selectedPlayerInfo = _selectedPair!;
        String playerName;
        String? playerClub;
        
        if (selectedPlayerInfo.contains(' (')) {
          final parts = selectedPlayerInfo.split(' (');
          playerName = parts[0];
          final clubPart = parts[1].replaceAll(')', '');
          playerClub = clubPart == '所属なし' ? null : clubPart;
        } else {
          // フォールバック（旧形式対応）
          playerName = selectedPlayerInfo;
          playerClub = null;
        }
        
        // チーム1にいるか判定
        bool inTeam1 = false;
        if (match.team1Player1 == playerName) {
          if (playerClub != null) {
            inTeam1 = match.team1Club == playerClub;
          } else {
            inTeam1 = match.team1Club.isEmpty;
          }
        }
        if (!inTeam1 && match.team1Player2 == playerName) {
          if (playerClub != null) {
            inTeam1 = match.team1Club == playerClub;
          } else {
            inTeam1 = match.team1Club.isEmpty;
          }
        }
        
        isThisTeam1 = inTeam1;
      }
      
      // 試合の勝敗
      if (match.winner != null) {
        if ((isThisTeam1 && match.winner == 'team1') ||
            (!isThisTeam1 && match.winner == 'team2')) {
          wins++;
        }
      }

      // ゲームスコアを取得
      final gameScores = await DatabaseHelper.instance.getGameScoresByMatchId(match.id!);
      final completedGameScores = gameScores.where((g) => g.winner != null).toList();
      // 勝利に必要なゲーム数を計算（5ゲームマッチ→3、7ゲームマッチ→4、9ゲームマッチ→5）
      final gamesToWin = (match.gameCount + 1) ~/ 2;
      
      for (var gameScore in gameScores) {
        if (gameScore.winner == null) continue;
        
        final gameNum = gameScore.gameNumber;
        final isWin = (isThisTeam1 && gameScore.winner == 'team1') ||
                      (!isThisTeam1 && gameScore.winner == 'team2');
        
        gameTotal[gameNum] = (gameTotal[gameNum] ?? 0) + 1;
        if (isWin) {
          gameWins[gameNum] = (gameWins[gameNum] ?? 0) + 1;
        }
        totalGames++;

        // デュース判定（3-3以上で2ポイント差で決着）
        final teamScore = isThisTeam1 ? gameScore.team1Score : gameScore.team2Score;
        final opponentScore = isThisTeam1 ? gameScore.team2Score : gameScore.team1Score;
        
        if (teamScore >= 3 && opponentScore >= 3) {
          deuceTotal++;
          if (isWin) {
            deuceWins++;
          }
        }

        // ファイナルゲーム判定
        // 前のゲームまでで同点かつゲーム数に達している場合、現在のゲームがファイナルゲーム
        int gamesBeforeThis = 0;
        int team1GamesBefore = 0;
        int team2GamesBefore = 0;
        for (var gs in completedGameScores) {
          if (gs.gameNumber < gameNum) {
            gamesBeforeThis++;
            if (gs.winner == 'team1') {
              team1GamesBefore++;
            } else if (gs.winner == 'team2') {
              team2GamesBefore++;
            }
          }
        }
        
        // ファイナルゲームの条件: 前のゲームまでで同点（各チームが勝利必要数-1勝）
        // 例: 7ゲームマッチ(勝利必要4)では3-3の時（6ゲーム完了後）がファイナルゲーム
        final isFinalGame = (team1GamesBefore == gamesToWin - 1) &&
                           (team2GamesBefore == gamesToWin - 1);
        
        if (isFinalGame) {
          finalGameTotal++;
          if (isWin) {
            finalGameWins++;
          }
        }

        // サーブ・レシーブ判定
        final isService = (isThisTeam1 && gameScore.serviceTeam == 'team1') ||
                          (!isThisTeam1 && gameScore.serviceTeam == 'team2');
        
        if (isService) {
          serviceTotal++;
          if (isWin) {
            serviceWins++;
          }
        } else {
          receiveTotal++;
          if (isWin) {
            receiveWins++;
          }
        }
      }
    }

    // ゲーム別勝率を計算
    final gameWinRates = <int, double>{};
    for (int i = 1; i <= 9; i++) {
      if (gameTotal.containsKey(i)) {
        gameWinRates[i] = (gameWins[i] ?? 0) / gameTotal[i]! * 100;
      }
    }

    // 詳細統計の計算（ポイント詳細データから）
    await _calculateDetailedStatistics(relevantMatches);

    setState(() {
      _totalMatches = relevantMatches.length;
      _winRate = relevantMatches.isEmpty ? 0.0 : wins / relevantMatches.length * 100;
      _gameWinRates = gameWinRates;
      _deuceWinRate = deuceTotal == 0 ? 0.0 : deuceWins / deuceTotal * 100;
      _deuceWins = deuceWins;
      _deuceLosses = deuceTotal - deuceWins;
      _serviceWinRate = serviceTotal == 0 ? 0.0 : serviceWins / serviceTotal * 100;
      _receiveWinRate = receiveTotal == 0 ? 0.0 : receiveWins / receiveTotal * 100;
      // 追加統計
      _finalGameWinRate = finalGameTotal == 0 ? 0.0 : finalGameWins / finalGameTotal * 100;
      _finalGameWins = finalGameWins;
      _finalGameTotal = finalGameTotal;
    });
  }

  /// 詳細統計の計算（ポイント詳細データから）
  Future<void> _calculateDetailedStatistics(List<Match> relevantMatches) async {
    int firstServeInCount = 0;
    int firstServeTotalCount = 0;
    int firstServePointWinCount = 0;
    int firstServePointTotalCount = 0;
    int winnerCount = 0;
    int myErrorCount = 0;
    bool hasData = false;

    for (var match in relevantMatches) {
      if (match.id == null) continue;

      // このマッチのポイント詳細データを取得
      final pointDetails = await DatabaseHelper.instance.getPointDetailsByMatchId(match.id!);
      if (pointDetails.isEmpty) continue;

      hasData = true;

      // 選択されたペア/組織/個人のチームを判定
      bool isThisTeam1;
      String? targetPlayerName; // 選手単位の場合、対象の選手名
      
      if (_selectedView == 0) {
        final pairName = _selectedPair!.split(' (').first;
        isThisTeam1 = '${match.team1Player1}・${match.team1Player2}' == pairName;
      } else if (_selectedView == 1) {
        isThisTeam1 = match.team1Club == _selectedPair;
      } else {
        // 選手単位
        final selectedPlayerInfo = _selectedPair!;
        String playerName;
        String? playerClub;
        if (selectedPlayerInfo.contains(' (')) {
          final parts = selectedPlayerInfo.split(' (');
          playerName = parts[0];
          final clubPart = parts[1].replaceAll(')', '');
          playerClub = clubPart == '所属なし' ? null : clubPart;
        } else {
          playerName = selectedPlayerInfo;
          playerClub = null;
        }
        
        targetPlayerName = playerName; // 選手名を記録
        
        bool inTeam1 = false;
        if (match.team1Player1 == playerName) {
          if (playerClub != null) {
            inTeam1 = match.team1Club == playerClub;
          } else {
            inTeam1 = match.team1Club.isEmpty;
          }
        }
        if (!inTeam1 && match.team1Player2 == playerName) {
          if (playerClub != null) {
            inTeam1 = match.team1Club == playerClub;
          } else {
            inTeam1 = match.team1Club.isEmpty;
          }
        }
        isThisTeam1 = inTeam1;
      }

      final myTeam = isThisTeam1 ? 'team1' : 'team2';
      final opponentTeam = isThisTeam1 ? 'team2' : 'team1';

      for (var point in pointDetails) {
        final isMyServe = point.serverTeam == myTeam;

        // 1stサーブ統計
        if (_selectedView == 2 && targetPlayerName != null) {
          // 選手単位: serverPlayerで個人をフィルタリング
          if (point.serverPlayer == targetPlayerName) {
            firstServeTotalCount++;
            if (point.firstServeIn) {
              firstServeInCount++;
              firstServePointTotalCount++;
              if (point.pointWinner == myTeam) {
                firstServePointWinCount++;
              }
            }
          }
        } else if (_selectedView != 2 && isMyServe) {
          // ペア/クラブ単位: チーム全体でカウント
          firstServeTotalCount++;
          if (point.firstServeIn) {
            firstServeInCount++;
            firstServePointTotalCount++;
            if (point.pointWinner == myTeam) {
              firstServePointWinCount++;
            }
          }
        }

        // ウィナー/エラー統計
        if (_selectedView == 2 && targetPlayerName != null) {
          // 選手単位: action_playerで個人をフィルタリング
          // ウィナー: その選手が決めた
          if (point.pointType == PointType.winner && point.actionPlayer == targetPlayerName) {
            winnerCount++;
          }
          // エラー: その選手がミスした
          if (point.pointType == PointType.opponentError && point.actionPlayer == targetPlayerName) {
            myErrorCount++;
          }
        } else {
          // ペア/クラブ単位: チーム全体でカウント
          if (point.pointWinner == myTeam && point.pointType == PointType.winner) {
            winnerCount++;
          }
          if (point.pointWinner == opponentTeam && point.pointType == PointType.opponentError) {
            myErrorCount++;
          }
        }
      }
    }

    _hasPointDetails = hasData;
    _firstServeInRate = firstServeTotalCount == 0 ? 0.0 : firstServeInCount / firstServeTotalCount * 100;
    _firstServePointRate = firstServePointTotalCount == 0 ? 0.0 : firstServePointWinCount / firstServePointTotalCount * 100;
    _winnerCount = winnerCount;
    _myErrorCount = myErrorCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        title: Text(
          '統計ダッシュボード',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pairs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '統計データがありません',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '試合を完了すると統計が表示されます',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // サブスクリプション未購入の場合、アップグレード促しを表示
                              if (!_isSubscribed) _buildUpgradePrompt(),
                              // セグメントコントロール（サブスクリプション未購入の場合はペア単位のみ）
                              if (_isSubscribed) _buildSegmentedControl(),
                              if (!_isSubscribed) _buildLimitedSegmentedControl(),
                              const SizedBox(height: 16),
                              // ペア/組織選択（リスト形式）
                              if (_isSubscribed || _selectedView == 0) _buildSelectionList(),
                              const SizedBox(height: 16),
                              // 選択中の表示
                              if (_selectedPair != null) _buildSelectedInfo(),
                              const SizedBox(height: 16),
                              // 通算試合数と勝率（常に表示）
                              _buildTotalStatsCard(),
                              // 広告表示（サブスクリプション未購入の場合）
                              if (!_isSubscribed) ...[
                                const SizedBox(height: 16),
                                _buildAdBanner(),
                              ],
                              // サブスクリプション未購入の場合、他の統計は表示しない
                              if (_isSubscribed) ...[
                                const SizedBox(height: 16),
                                // ゲーム別の得点率
                                _buildGameWinRatesCard(),
                                const SizedBox(height: 16),
                                // デュース時取得率
                                _buildDeuceWinRateCard(),
                                const SizedBox(height: 16),
                                // ファイナルゲームの勝率
                                _buildFinalGameWinRateCard(),
                                const SizedBox(height: 16),
                                // サーブ・レシーブ別取得率
                                _buildServiceReceiveCard(),
                                const SizedBox(height: 16),
                                // 詳細統計（1stサーブ成功率・得点率、レシーブミス率、ウィナー/エラー）
                                _buildDetailedStatisticsCard(),
                                const SizedBox(height: 16),
                                // データインサイト
                                _buildDataInsightsCard(),
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildLimitedSegmentedControl() {
    // サブスクリプション未購入の場合、ペア単位のみ表示
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedView = 0;
                  _selectedPair = _pairs.isNotEmpty ? _pairs.first : null;
                });
                _calculateStatistics();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'ペア単位',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'By Pair',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Opacity(
              opacity: 0.5,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Text(
                      '学校・クラブ単位',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const Text(
                      'By Organization',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.lock,
                      size: 12,
                      color: Color(0xFF888888),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Opacity(
              opacity: 0.5,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Text(
                      '選手単位',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const Text(
                      'By Player',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.lock,
                      size: 12,
                      color: Color(0xFF888888),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedView = 0;
                  _selectedPair = _pairs.isNotEmpty ? _pairs.first : null;
                });
                _calculateStatistics();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedView == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedView == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      'ペア単位',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedView == 0 ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedView == 0 ? const Color(0xFF1E293B) : const Color(0xFF888888),
                      ),
                    ),
                    Text(
                      'By Pair',
                      style: TextStyle(
                        fontSize: 8,
                        color: _selectedView == 0 ? const Color(0xFF1E293B) : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isSubscribed) {
                  setState(() {
                    _selectedView = 1;
                    _selectedPair = _organizations.isNotEmpty ? _organizations.first : null;
                  });
                  _calculateStatistics();
                } else {
                  _showSubscriptionDialog();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedView == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedView == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      '学校・クラブ単位',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedView == 1 ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedView == 1 ? const Color(0xFF1E293B) : const Color(0xFF888888),
                      ),
                    ),
                    Text(
                      'By Organization',
                      style: TextStyle(
                        fontSize: 8,
                        color: _selectedView == 1 ? const Color(0xFF1E293B) : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isSubscribed) {
                  setState(() {
                    _selectedView = 2;
                    _selectedPair = _players.isNotEmpty ? _players.first : null;
                  });
                  _calculateStatistics();
                } else {
                  _showSubscriptionDialog();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedView == 2 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedView == 2
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      '選手単位',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedView == 2 ? FontWeight.w600 : FontWeight.normal,
                        color: _selectedView == 2 ? const Color(0xFF1E293B) : const Color(0xFF888888),
                      ),
                    ),
                    Text(
                      'By Player',
                      style: TextStyle(
                        fontSize: 8,
                        color: _selectedView == 2 ? const Color(0xFF1E293B) : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionList() {
    String buttonText;
    if (_selectedPair == null) {
      buttonText = _selectedView == 0
          ? 'ペアを選択'
          : _selectedView == 1
              ? '学校・クラブを選択'
              : 'プレイヤーを選択';
    } else {
      buttonText = _selectedPair!;
    }

    return GestureDetector(
      onTap: _showSelectionDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedPair == null
                      ? const Color(0xFF888888)
                      : const Color(0xFF333333),
                  fontWeight: _selectedPair == null
                      ? FontWeight.normal
                      : FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF888888),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSelectionDialog() async {
    _searchController.clear();
    _filterItems();

    final selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: Text(
                _selectedView == 0
                    ? 'ペアを選択'
                    : _selectedView == 1
                        ? '学校・クラブを選択'
                        : 'プレイヤーを選択',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF555555),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 検索バー
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() {
                          _filterItems();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '検索...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Color(0xFFAAAAAA), size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setDialogState(() {
                                    _filterItems();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    // リスト
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFFAFAFA),
                      ),
                      child: _filteredItems.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  '検索結果がありません',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = _filteredItems[index];
                                  final isSelected = _selectedPair == item;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.pop(context, item);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFF5F7FA) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: isSelected
                                            ? Border.all(color: Colors.grey[300]!, width: 1)
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                                color: isSelected
                                                    ? const Color(0xFF555555)
                                                    : const Color(0xFF666666),
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.check,
                                                color: Colors.grey[700],
                                                size: 16,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                  child: Text(
                    'キャンセル',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedPair = selected;
      });
      _calculateStatistics();
    }
  }

  Widget _buildSelectedInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(
            Icons.person_search,
            size: 16,
            color: Color(0xFF888888),
          ),
          const SizedBox(width: 8),
          Text(
            '選択中: $_selectedPair',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTotalStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'TOTAL MATCHES',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_totalMatches',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '通算試合数',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: const Color(0xFFEEEEEE),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'WIN RATE',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_winRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '勝率',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameWinRatesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              color: Color(0xFFF7F7F7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'ゲーム別の得点率',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'SCORE RATE / GAME',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _gameWinRates.entries.map((entry) {
                final gameNum = entry.key;
                final rate = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GAME $gameNum',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF888888),
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${rate.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: rate / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeuceWinRateCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              color: Color(0xFFF7F7F7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'デュース時取得率',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'DEUCE WIN RATE',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ドーナツチャート
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth < 200 
                        ? constraints.maxWidth * 0.6 
                        : 120.0;
                    return SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: size,
                            height: size,
                            child: CircularProgressIndicator(
                              value: _deuceWinRate / 100,
                              strokeWidth: size * 0.125,
                              backgroundColor: const Color(0xFFEEEEEE),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E293B)),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${_deuceWinRate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: size * 0.23,
                                    fontWeight: FontWeight.w300,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                              ),
                              const Text(
                                'WIN',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF888888),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '取得',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_deuceWins',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEEEEEE),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '喪失',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_deuceLosses',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
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

  Widget _buildFinalGameWinRateCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'ファイナルゲームの勝率',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'FINAL GAME WIN RATE',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                if (_finalGameTotal == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'ファイナルゲームのデータがありません',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_finalGameWinRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E293B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '勝利',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_finalGameWins',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEEEEE),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '敗北',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_finalGameTotal - _finalGameWins}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceReceiveCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              color: Color(0xFFF7F7F7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'サーブ・レシーブ別ゲーム取得率',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'SERVICE / RECEIVE WIN RATE',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // サーブ時
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sports_tennis,
                                size: 16,
                                color: Color(0xFF1E293B),
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'サーブ時 (Service)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_serviceWinRate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _serviceWinRate / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // レシーブ時
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.front_hand,
                                size: 16,
                                color: Color(0xFF888888),
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'レシーブ時 (Receive)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_receiveWinRate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _receiveWinRate / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(5),
                          ),
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

  /// 詳細統計カード（サブスク対象）
  /// 1stサーブ成功率・得点率、レシーブミス率、ウィナー/アンフォーストエラー
  Widget _buildDetailedStatisticsCard() {
    if (!_hasPointDetails) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                color: Color(0xFFF7F7F7),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.analytics,
                    size: 16,
                    color: Color(0xFF1E293B),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '詳細統計',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DETAILED STATISTICS',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '詳細データがありません',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'マッチスコア画面で「分析+」モードをONにして\n記録した試合の統計が表示されます',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }


    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              color: Color(0xFFF7F7F7),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics,
                  size: 16,
                  color: Color(0xFF1E293B),
                ),
                const SizedBox(width: 8),
                const Text(
                  '詳細統計',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showWinnerErrorInfo(context),
                  child: const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: Color(0xFF999999),
                  ),
                ),
                const Spacer(),
                const Text(
                  'DETAILED STATISTICS',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1stサーブ成功率
                _buildDetailStatRow(
                  '1stサーブ成功率',
                  '${_firstServeInRate.toStringAsFixed(1)}%',
                  Icons.sports_tennis,
                  const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),
                // 1stサーブ得点率
                _buildDetailStatRow(
                  '1stサーブ得点率',
                  '${_firstServePointRate.toStringAsFixed(1)}%',
                  Icons.check_circle_outline,
                  const Color(0xFF2196F3),
                ),
                const Divider(height: 32),
                // ウィナー - エラー
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ウィナー',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_winnerCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                    Text(
                      '$_myErrorCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'エラー',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
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

  void _showWinnerErrorInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                    'ウィナー / エラーとは',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ウィナー',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '自分が攻めて決めたポイント',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '❌',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'エラー',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF5722),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '自分のミスで失ったポイント\n（アンフォーストエラー）',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
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

  Widget _buildDetailStatRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF333333),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildDataInsightsCard() {
    // 最も低いゲーム勝率を探す
    int? lowestGame;
    double? lowestRate;
    if (_gameWinRates.isNotEmpty) {
      _gameWinRates.forEach((gameNum, rate) {
        if (lowestRate == null || rate < lowestRate!) {
          lowestRate = rate;
          lowestGame = gameNum;
        }
      });
    }

    String insightText = '';
    if (lowestGame != null && lowestRate != null && lowestRate! < 50) {
      insightText = 'Game $lowestGameの立ち上がりにデータ上の課題が見られます。';
    } else if (_winRate >= 60) {
      insightText = '安定した勝率を誇ります。';
    } else {
      insightText = 'さらなる改善の余地があります。';
    }

    String adviceText = '';
    if (_serviceWinRate > _receiveWinRate + 10) {
      adviceText =
          'サーブ時の取得率が非常に高い（${_serviceWinRate.toStringAsFixed(0)}%）ため、サービスゲームを確実にキープする戦術を維持しましょう。一方でレシーブ時は相手のセカンドサーブをより積極的に攻めることで、全体の勝率をさらに高められます。';
    } else if (_receiveWinRate > _serviceWinRate + 10) {
      adviceText =
          'レシーブ時の取得率が高い（${_receiveWinRate.toStringAsFixed(0)}%）ため、レシーブゲームを積極的に狙う戦術が有効です。サーブ時はより確実にポイントを取ることを意識しましょう。';
    } else {
      adviceText =
          'サーブとレシーブのバランスが取れています。両方の取得率をさらに向上させることで、より安定した成績を残せます。';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: const BorderSide(color: Color(0xFF1E293B), width: 4),
          top: const BorderSide(color: Color(0xFFEEEEEE)),
          right: const BorderSide(color: Color(0xFFEEEEEE)),
          bottom: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                size: 14,
                color: Color(0xFF1E293B),
              ),
              const SizedBox(width: 6),
              const Text(
                'DATA INSIGHTS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insightText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),
          const Text(
            'SERVICE & RECEIVE ADVICE:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            adviceText,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePrompt() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'プレミアムにアップグレード',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '詳細な統計データと広告非表示',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              _showSubscriptionDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              '購入',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubscriptionDialog() async {
    final service = SubscriptionService();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プレミアムにアップグレード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('プレミアムの特典：'),
            const SizedBox(height: 8),
            const Text('• 広告非表示'),
            const Text('• 詳細な統計データ（ゲーム別、デュース、ファイナルゲームなど）'),
            const Text('• 学校・クラブ単位の統計'),
            const Text('• 選手単位の統計'),
            if (defaultTargetPlatform == TargetPlatform.macOS || kIsWeb) ...[
              const SizedBox(height: 16),
              const Text(
                '※ macOS/Web版ではテスト用に手動で有効化できます',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await service.purchaseSubscription();
              if (success && mounted) {
                await _checkSubscriptionStatus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('プレミアムにアップグレードしました'),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('購入に失敗しました'),
                  ),
                );
              }
            },
            child: const Text('購入'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBanner() {
    // 広告バナーを表示（実際の広告ユニットIDに置き換える）
    // macOS/Webでは広告を表示しない
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS) {
      return const SizedBox.shrink();
    }
    
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 50,
      child: AdWidget(
        ad: BannerAd(
          adUnitId: 'ca-app-pub-3940256099942544/6300978111', // テスト広告ID（実際のIDに置き換える）
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (_) {},
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
            },
          ),
        )..load(),
      ),
    );
  }
}
