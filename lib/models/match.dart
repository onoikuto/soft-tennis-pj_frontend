class Match {
  final int? id;
  final String team1Player1;
  final String team1Player2;
  final String team2Player1;
  final String team2Player2;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? winner; // 'team1' or 'team2' or null

  Match({
    this.id,
    required this.team1Player1,
    required this.team1Player2,
    required this.team2Player1,
    required this.team2Player2,
    required this.createdAt,
    this.completedAt,
    this.winner,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team1_player1': team1Player1,
      'team1_player2': team1Player2,
      'team2_player1': team2Player1,
      'team2_player2': team2Player2,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'winner': winner,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map) {
    return Match(
      id: map['id'] as int?,
      team1Player1: map['team1_player1'] as String,
      team1Player2: map['team1_player2'] as String,
      team2Player1: map['team2_player1'] as String,
      team2Player2: map['team2_player2'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      winner: map['winner'] as String?,
    );
  }
}
