import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/screens/official_scoring_screen.dart';
import 'package:intl/intl.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  List<Match> _matches = [];
  List<Match> _filteredMatches = [];
  Map<int, Map<String, int>> _matchScores = {}; // matchId -> {team1Games, team2Games}
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMatches);
    _loadMatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMatches() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredMatches = _matches;
      } else {
        _filteredMatches = _matches.where((match) {
          // 大会名で検索
          if (match.tournamentName.toLowerCase().contains(query)) {
            return true;
          }
          // チーム1の選手名で検索
          if (match.team1Player1.toLowerCase().contains(query) ||
              match.team1Player2.toLowerCase().contains(query) ||
              match.team1DisplayName.toLowerCase().contains(query)) {
            return true;
          }
          // チーム2の選手名で検索
          if (match.team2Player1.toLowerCase().contains(query) ||
              match.team2Player2.toLowerCase().contains(query) ||
              match.team2DisplayName.toLowerCase().contains(query)) {
            return true;
          }
          // 所属で検索
          if (match.team1Club.toLowerCase().contains(query) ||
              match.team2Club.toLowerCase().contains(query)) {
            return true;
          }
          return false;
        }).toList();
      }
    });
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await DatabaseHelper.instance.getAllMatches();
      final scoresMap = <int, Map<String, int>>{};
      
      // 各試合のゲームスコアを取得
      for (var match in matches) {
        if (match.id != null) {
          final gameScores = await DatabaseHelper.instance.getGameScoresByMatchId(match.id!);
          int team1Games = 0;
          int team2Games = 0;
          
          for (var gameScore in gameScores) {
            if (gameScore.winner == 'team1') {
              team1Games++;
            } else if (gameScore.winner == 'team2') {
              team2Games++;
            }
          }
          
          scoresMap[match.id!] = {
            'team1Games': team1Games,
            'team2Games': team2Games,
          };
        }
      }
      
      setState(() {
        _matches = matches;
        _matchScores = scoresMap;
        _filteredMatches = matches;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('試合データの読み込みエラー: $e');
      setState(() {
        _matches = [];
        _filteredMatches = [];
        _matchScores = {};
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

  /// 削除確認ダイアログを表示
  Future<void> _showDeleteDialog(Match match) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('試合を削除しますか？'),
          content: const Text(
            'この試合を削除すると、統計データからも削除されます。\n'
            'この操作は取り消せません。\n'
            '本当に削除してよろしいですか？',
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
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && match.id != null) {
      // 試合を削除（関連するゲームスコアも削除される）
      await DatabaseHelper.instance.deleteMatch(match.id!);
      
      // リストを更新
      if (mounted) {
        _loadMatches();
        
        // 削除完了のスナックバーを表示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('試合を削除しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '過去の試合一覧',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF333333),
              ),
            )
          : Column(
              children: [
                // 検索バー
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '大会名・選手名・所属で検索',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF888888)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              color: const Color(0xFF888888),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                // 検索結果数表示
                if (_searchController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Text(
                          '${_filteredMatches.length}件の試合が見つかりました',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                // 試合一覧
                Expanded(
                  child: _matches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.history,
                                  size: 40,
                                  color: Color(0xFF888888),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '試合履歴がありません',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '新しく試合を始めると、\nここに履歴が表示されます',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredMatches.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '検索結果が見つかりませんでした',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '別のキーワードで検索してください',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadMatches,
                              color: const Color(0xFF333333),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                itemCount: _filteredMatches.length,
                                itemBuilder: (context, index) {
                                  final match = _filteredMatches[index];
                      final isCompleted = match.completedAt != null;
                      final isTeam1Winner = match.winner == 'team1';
                      final isTeam2Winner = match.winner == 'team2';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE8E8E8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      OfficialScoringScreen(matchId: match.id!),
                                ),
                              ).then((_) => _loadMatches());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ヘッダー（大会名とステータス・削除ボタン）
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (match.tournamentName.isNotEmpty)
                                              Text(
                                                match.tournamentName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF666666),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            if (match.tournamentName.isNotEmpty)
                                              const SizedBox(height: 4),
                                            Text(
                                              DateFormat('yyyy年MM月dd日 HH:mm')
                                                  .format(match.createdAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
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
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _showDeleteDialog(match),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFE53935),
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // チーム情報
                                  _buildTeamRow(
                                    match.team1DisplayName,
                                    match.team1Club,
                                    isTeam1Winner && isCompleted,
                                    true,
                                    match.id != null ? (_matchScores[match.id!]?['team1Games'] ?? 0) : 0,
                                    match.id != null ? (_matchScores[match.id!]?['team2Games'] ?? 0) : 0,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 1,
                                    color: const Color(0xFFF0F0F0),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTeamRow(
                                    match.team2DisplayName,
                                    match.team2Club,
                                    isTeam2Winner && isCompleted,
                                    false,
                                    match.id != null ? (_matchScores[match.id!]?['team2Games'] ?? 0) : 0,
                                    match.id != null ? (_matchScores[match.id!]?['team1Games'] ?? 0) : 0,
                                  ),
                                  // フッター（勝者表示）
                                  if (isCompleted && match.winner != null) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.emoji_events,
                                                size: 14,
                                                color: isTeam1Winner
                                                    ? const Color(0xFF4A90E2)
                                                    : const Color(0xFF50C878),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isTeam1Winner
                                                    ? match.team1DisplayName
                                                    : match.team2DisplayName,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ),
              ],
            ),
    );
  }

  Widget _buildTeamRow(
    String teamName,
    String club,
    bool isWinner,
    bool isTeam1,
    int myGames,
    int opponentGames,
  ) {
    final hasScore = myGames > 0 || opponentGames > 0;
    
    return Row(
      children: [
        Container(
          width: 4,
          height: 48,
          decoration: BoxDecoration(
            color: isWinner
                ? (isTeam1 ? const Color(0xFF4A90E2) : const Color(0xFF50C878))
                : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teamName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isWinner ? FontWeight.w600 : FontWeight.w500,
                  color: isWinner ? const Color(0xFF333333) : const Color(0xFF666666),
                  letterSpacing: 0.2,
                ),
              ),
              if (club.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  club,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasScore)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isWinner
                  ? (isTeam1 ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9))
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$myGames',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isWinner
                    ? (isTeam1 ? const Color(0xFF4A90E2) : const Color(0xFF50C878))
                    : const Color(0xFF666666),
              ),
            ),
          ),
        if (isWinner && !hasScore)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isTeam1
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              size: 16,
              color: isTeam1 ? const Color(0xFF4A90E2) : const Color(0xFF50C878),
            ),
          ),
      ],
    );
  }
}
