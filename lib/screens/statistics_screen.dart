import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/ai_insight_service.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';
import 'package:soft_tennis_scoring/services/pair_report.dart';
import 'package:soft_tennis_scoring/services/statistics_calculator.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';
import 'package:soft_tennis_scoring/widgets/statistics/ad_banner.dart';
import 'package:soft_tennis_scoring/widgets/common/pair_report_view.dart';
import 'package:soft_tennis_scoring/widgets/statistics/analysis_comment_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/detailed_statistics_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/deuce_win_rate_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/final_game_win_rate_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/game_win_rates_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/momentum_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/opponent_records_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/serve_detail_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/service_receive_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/total_stats_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/upgrade_prompt_card.dart';
import 'package:soft_tennis_scoring/widgets/statistics/win_rate_trend_card.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

  // 勝率推移・対戦相手別成績（試合データから計算）
  List<bool> _recentResults = [];
  List<MonthlyWinRate> _monthlyWinRates = [];
  List<OpponentRecord> _opponentRecords = [];

  // サーブ詳細・流れ統計（ポイント詳細データから計算）
  AdvancedPointStats _advancedPointStats = AdvancedPointStats();

  // 分析コメント
  List<Insight> _insights = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    // フレームが描画された後にデータを読み込む（エラーを防ぐ）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkSubscriptionStatus();
        _loadStatistics();
      }
    });
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
        _recentResults = [];
        _monthlyWinRates = [];
        _opponentRecords = [];
        _advancedPointStats = AdvancedPointStats();
        _insights = [];
      });
      return;
    }

    // 集計は StatisticsCalculator に任せる。試合を保存した直後に
    // （統計画面を開いていなくても）AI分析を生成できるよう、画面から
    // 切り離してある。
    final subject = StatsSubject(_selectedView, _selectedPair!);
    final result = await StatisticsCalculator.calculate(subject);
    if (!mounted) return;

    // 次に試合を保存したとき、どの対象の分析を作り直せばよいか覚えておく
    await AiInsightService.rememberSubject(subject);

    setState(() {
      _totalMatches = result.totalMatches;
      _winRate = result.winRate;
      _gameWinRates = result.gameWinRates;
      _deuceWinRate = result.deuceWinRate;
      _deuceWins = result.deuceWins;
      _deuceLosses = result.deuceLosses;
      _serviceWinRate = result.serviceWinRate;
      _receiveWinRate = result.receiveWinRate;
      // 追加統計
      _finalGameWinRate = result.finalGameWinRate;
      _finalGameWins = result.finalGameWins;
      _finalGameTotal = result.finalGameTotal;
      _recentResults = result.recentResults;
      _monthlyWinRates = result.monthlyWinRates;
      _opponentRecords = result.opponentRecords;
      // 詳細統計（ポイント詳細データから）
      _hasPointDetails = result.hasPointDetails;
      _firstServeInRate = result.firstServeInRate;
      _firstServePointRate = result.firstServePointRate;
      _winnerCount = result.winnerCount;
      _myErrorCount = result.myErrorCount;
      _advancedPointStats = result.advancedPointStats;
      // 表示はまずルールベースで確定させる。AI分析は生成済みのときだけ
      // 差し替えるので、統計画面は常に待ち時間なしで開き、生成に失敗して
      // いても「分析が出ない」状態にはならない。
      _insights = InsightEngine.generate(result.insightInput);
    });

    await _applyAiInsights(subject, result.insightInput);
  }

  /// いま見ている対象からペアの2選手を求める
  ///
  /// ペア単位のときは表示名（例「山田・佐藤」）から取れます。
  /// 学校単位・個人単位のときは決まらないので、記録に出てくる選手から
  /// 本数の多い順に使います（[PairReport.build] 側で処理されます）。
  List<String> _pairPlayerNames() {
    if (_selectedView != 0 || _selectedPair == null) return const [];
    return _selectedPair!.split(' (').first.split('・');
  }

  /// AIが生成済みの分析コメントがあれば差し替える
  ///
  /// 生成は試合を保存した直後にバックグラウンドで走ります。ここでは待たずに
  /// キャッシュを見るだけなので、画面が固まることはありません。
  /// 生成が間に合っていないときは予約だけ入れておき、次に開いたときにAI版が出ます。
  Future<void> _applyAiInsights(StatsSubject subject, InsightInput input) async {
    try {
      final aiInsights = await AiInsightService.cachedInsights(subject, input);
      if (!mounted) return;

      if (aiInsights != null && aiInsights.isNotEmpty) {
        setState(() => _insights = aiInsights);
      } else {
        AiInsightService.scheduleGeneration(subject);
      }
    } catch (e) {
      // AI分析が読めなくてもルールベースの分析は出ているので、何もしない
      debugPrint('AI分析の適用に失敗: $e');
    }
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
                              if (!_isSubscribed) UpgradePromptCard(onUpgradePressed: _showSubscriptionDialog),
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
                              TotalStatsCard(totalMatches: _totalMatches, winRate: _winRate),
                              // 勝率の推移（常に表示）
                              if (_recentResults.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                WinRateTrendCard(
                                  recentResults: _recentResults,
                                  monthly: _monthlyWinRates,
                                ),
                              ],
                              // 対戦相手別成績（常に表示）
                              if (_opponentRecords.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                OpponentRecordsCard(opponents: _opponentRecords),
                              ],
                              // 広告表示（サブスクリプション未購入の場合）
                              if (!_isSubscribed) ...[
                                const SizedBox(height: 16),
                                AdBanner(isSubscribed: _isSubscribed),
                              ],
                              // サブスクリプション未購入の場合、他の統計は表示しない
                              if (_isSubscribed) ...[
                                const SizedBox(height: 16),
                                // ゲーム別の得点率
                                GameWinRatesCard(gameWinRates: _gameWinRates),
                                const SizedBox(height: 16),
                                // デュース時取得率
                                DeuceWinRateCard(
                                  deuceWinRate: _deuceWinRate,
                                  deuceWins: _deuceWins,
                                  deuceLosses: _deuceLosses,
                                ),
                                const SizedBox(height: 16),
                                // ファイナルゲームの勝率
                                FinalGameWinRateCard(
                                  finalGameWinRate: _finalGameWinRate,
                                  finalGameWins: _finalGameWins,
                                  finalGameTotal: _finalGameTotal,
                                ),
                                const SizedBox(height: 16),
                                // サーブ・レシーブ別取得率
                                ServiceReceiveCard(
                                  serviceWinRate: _serviceWinRate,
                                  receiveWinRate: _receiveWinRate,
                                ),
                                const SizedBox(height: 16),
                                // 詳細統計（1stサーブ成功率・得点率、レシーブミス率、ウィナー/エラー）
                                DetailedStatisticsCard(
                                  hasPointDetails: _hasPointDetails,
                                  firstServeInRate: _firstServeInRate,
                                  firstServePointRate: _firstServePointRate,
                                  winnerCount: _winnerCount,
                                  myErrorCount: _myErrorCount,
                                ),
                                // サーブ詳細分析・流れ（ポイント詳細データがある場合のみ）
                                if (_hasPointDetails) ...[
                                  const SizedBox(height: 16),
                                  ServeDetailCard(stats: _advancedPointStats),
                                  const SizedBox(height: 16),
                                  MomentumCard(stats: _advancedPointStats),
                                ],
                                if (_hasPointDetails) ...[
                                  const SizedBox(height: 16),
                                  // 選手ごとの良かった点・課題（累計）
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE5E5E5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ペアのまとめ',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        PairReportView(
                                          report: PairReport.build(
                                            _advancedPointStats,
                                            playerNames: _pairPlayerNames(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                // 分析コメント（ローカルのルールベースで生成）
                                AnalysisCommentCard(insights: _insights),
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


  Future<void> _showSubscriptionDialog() async {
    final service = SubscriptionService();
    
    // 購入更新のリスナーを設定
    service.listenToPurchaseUpdates((purchaseDetails) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 購入が完了した場合
        _checkSubscriptionStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プレミアムにアップグレードしました'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // エラーが発生した場合
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('購入に失敗しました: ${purchaseDetails.error?.message ?? "不明なエラー"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
    
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
              
              // プロダクトが利用可能か確認
              final product = await service.getSubscriptionProduct();
              if (product == null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('プロダクトが見つかりません。\nApp Store Connectでプロダクトが承認されているか確認してください。\nまた、サンドボックステストアカウントでログインしているか確認してください。'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
                return;
              }
              
              final success = await service.purchaseSubscription();
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('購入に失敗しました。'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              // 成功した場合は支払いシートが表示され、購入完了はリスナーで処理される
            },
            child: const Text('購入'),
          ),
        ],
      ),
    );
  }

}
