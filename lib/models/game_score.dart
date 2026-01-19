class GameScore {
  final int? id;
  final int matchId;
  final int gameNumber; // 1, 2, 3, 4, 5, 6, 7...
  final int team1Score;
  final int team2Score;
  final String? serviceTeam; // 'team1' or 'team2' - サーブ権
  final String? winner; // 'team1' or 'team2' or null

  GameScore({
    this.id,
    required this.matchId,
    required this.gameNumber,
    required this.team1Score,
    required this.team2Score,
    this.serviceTeam,
    this.winner,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'match_id': matchId,
      'game_number': gameNumber,
      'team1_score': team1Score,
      'team2_score': team2Score,
      'service_team': serviceTeam,
      'winner': winner,
    };
  }

  factory GameScore.fromMap(Map<String, dynamic> map) {
    return GameScore(
      id: map['id'] as int?,
      matchId: map['match_id'] as int,
      gameNumber: map['game_number'] as int,
      team1Score: map['team1_score'] as int,
      team2Score: map['team2_score'] as int,
      serviceTeam: map['service_team'] as String?,
      winner: map['winner'] as String?,
    );
  }
}
