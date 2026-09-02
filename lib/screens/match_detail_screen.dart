import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/screens/official_scoring_screen.dart';
import 'package:soft_tennis_scoring/utils/game_rules.dart';
import 'package:soft_tennis_scoring/widgets/scoring/scoring_sheet_table.dart';

/// 試合詳細画面（閲覧用）
///
/// 記録済みの試合を公式採点票の形式で振り返るための画面です。
/// スコアの編集はできません。進行中の試合の場合は、
/// 「スコア記録を続ける」ボタンから採点画面に移動できます。
class MatchDetailScreen extends StatefulWidget {
  final int matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  Match? _match;
  List<GameScore> _gameScores = [];
  List<PointDetail> _pointDetails = [];
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
    final pointDetails =
        await DatabaseHelper.instance.getPointDetailsByMatchId(widget.matchId);
    setState(() {
      _match = match;
      _gameScores = gameScores;
      _pointDetails = pointDetails;
      _isLoading = false;
    });
  }

  /// 進行中のゲーム番号を取得（採点表の表示用）
  int get _currentGame {
    for (var score in _gameScores.reversed) {
      if (score.winner == null) return score.gameNumber;
    }
    if (_gameScores.isNotEmpty) return _gameScores.last.gameNumber + 1;
    return 1;
  }

  bool get _isCompleted => _match?.completedAt != null;

  /// 採点画面に移動してスコア記録を続ける
  Future<void> _continueScoring() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficialScoringScreen(matchId: widget.matchId),
      ),
    );
    // 採点画面から戻ってきたら最新のデータを再読み込み
    _loadMatchData();
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
        body: const Center(child: Text('試合が見つかりません')),
      );
    }

    final match = _match!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MATCH RECORD',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 2,
                color: Color(0xFF7F7F7F),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '試合詳細',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchInfoHeader(match),
            const SizedBox(height: 16),
            // 公式採点票（閲覧専用）
            ScoringSheetTable(
              match: match,
              gameScores: _gameScores,
              pointDetails: _pointDetails,
              currentGame: _currentGame,
              isMatchCompleted: _isCompleted,
              isFinalGame: (gameNumber) => GameRules.isFinalGame(
                gameCount: match.gameCount,
                gameScores: _gameScores,
                gameNumber: gameNumber,
              ),
            ),
            const SizedBox(height: 16),
            _buildPointsSummary(),
            const SizedBox(height: 24),
            _buildScoringButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 大会名・日時・結果の表示
  Widget _buildMatchInfoHeader(Match match) {
    final isCompleted = _isCompleted;
    String? resultText;
    if (match.winner == 'team1') {
      resultText = '${match.team1Player1}・${match.team1Player2} の勝利';
    } else if (match.winner == 'team2') {
      resultText = '${match.team2Player1}・${match.team2Player2} の勝利';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                match.tournamentName.isEmpty ? '大会名なし' : match.tournamentName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted ? '終了' : '進行中',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('yyyy年MM月dd日 HH:mm').format(match.createdAt),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        if (resultText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 16,
                color: Color(0xFF333333),
              ),
              const SizedBox(width: 6),
              Text(
                resultText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 総ポイントの集計表示（ポイント詳細がある場合のみ）
  Widget _buildPointsSummary() {
    if (_match == null || _pointDetails.isEmpty) return const SizedBox();

    final team1Points =
        _pointDetails.where((p) => p.pointWinner == 'team1').length;
    final team2Points =
        _pointDetails.where((p) => p.pointWinner == 'team2').length;
    final total = team1Points + team2Points;
    if (total == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '総ポイント',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7F7F7F),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$team1Points',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const Text(
                ' - ',
                style: TextStyle(fontSize: 14, color: Color(0xFF7F7F7F)),
              ),
              Text(
                '$team2Points',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ポイント獲得率のバー
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                if (team1Points > 0)
                  Expanded(
                    flex: team1Points,
                    child: Container(height: 6, color: const Color(0xFF333333)),
                  ),
                if (team2Points > 0)
                  Expanded(
                    flex: team2Points,
                    child: Container(height: 6, color: const Color(0xFFD9D9D9)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 採点画面を開くボタン
  ///
  /// 進行中の試合は記録の続き、終了した試合はスコアの修正
  /// （採点画面の「一つ戻る」でポイントを取り消して修正）ができます。
  Widget _buildScoringButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _continueScoring,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(_isCompleted ? 'スコアを修正する' : 'スコア記録を続ける'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF333333),
          side: const BorderSide(color: Color(0xFF333333)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
