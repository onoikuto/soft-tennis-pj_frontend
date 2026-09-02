import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';

/// 分析+入力ダイアログ
///
/// ポイントごとの詳細情報を入力するダイアログです。
/// 選手名をタップして選択すると自動で保存されます。
class PointDetailDialog extends StatefulWidget {
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
  final bool initialFirstServeIn; // メイン画面で選択された1stサーブの状態

  const PointDetailDialog({
    super.key,
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
    required this.initialFirstServeIn,
  });

  @override
  State<PointDetailDialog> createState() => _PointDetailDialogState();
}

class _PointDetailDialogState extends State<PointDetailDialog> {
  late bool _firstServeIn;

  @override
  void initState() {
    super.initState();
    _firstServeIn = widget.initialFirstServeIn; // メイン画面の選択値で初期化
  }

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
