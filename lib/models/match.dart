class Match {
  final int? id;
  final String? tournamentName; // 大会名
  final String team1Player1;
  final String team1Player2;
  final String? team1Club; // ペアAの所属
  final String team2Player1;
  final String team2Player2;
  final String? team2Club; // ペアBの所属
  final int gameCount; // ゲーム数（5, 7, 9）
  final String? firstServe; // 'team1' or 'team2' - 先サーブ
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? winner; // 'team1' or 'team2' or null

  Match({
    this.id,
    this.tournamentName,
    required this.team1Player1,
    required this.team1Player2,
    this.team1Club,
    required this.team2Player1,
    required this.team2Player2,
    this.team2Club,
    this.gameCount = 7,
    this.firstServe,
    required this.createdAt,
    this.completedAt,
    this.winner,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournament_name': tournamentName,
      'team1_player1': team1Player1,
      'team1_player2': team1Player2,
      'team1_club': team1Club,
      'team2_player1': team2Player1,
      'team2_player2': team2Player2,
      'team2_club': team2Club,
      'game_count': gameCount,
      'first_serve': firstServe,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'winner': winner,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map) {
    return Match(
      id: map['id'] as int?,
      tournamentName: map['tournament_name'] as String?,
      team1Player1: map['team1_player1'] as String,
      team1Player2: map['team1_player2'] as String,
      team1Club: map['team1_club'] as String?,
      team2Player1: map['team2_player1'] as String,
      team2Player2: map['team2_player2'] as String,
      team2Club: map['team2_club'] as String?,
      gameCount: map['game_count'] as int? ?? 7,
      firstServe: map['first_serve'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      winner: map['winner'] as String?,
    );
  }
}
