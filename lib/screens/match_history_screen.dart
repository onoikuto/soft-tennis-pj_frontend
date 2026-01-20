import 'package:flutter/material.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    final matches = await DatabaseHelper.instance.getAllMatches();
    setState(() {
      _matches = matches;
      _isLoading = false;
    });
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
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '試合履歴がありません',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMatches,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      final match = _matches[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            match.tournamentName.isNotEmpty ? match.tournamentName : '試合',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                match.team1DisplayName,
                              ),
                              Text(
                                'vs',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                match.team2DisplayName,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('yyyy/MM/dd HH:mm')
                                    .format(match.createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              match.completedAt != null
                                  ? Chip(
                                      label: Text(
                                        match.winner != null
                                            ? (match.winner == 'team1' ? 'チーム1勝利' : 'チーム2勝利')
                                            : '終了',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.green[100],
                                    )
                                  : Chip(
                                      label: const Text(
                                        '進行中',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.orange[100],
                                    ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _showDeleteDialog(match),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    OfficialScoringScreen(matchId: match.id!),
                              ),
                            ).then((_) => _loadMatches());
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
