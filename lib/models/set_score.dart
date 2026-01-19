class SetScore {
  final int? id;
  final int matchId;
  final int setNumber; // 1, 2, 3...
  final int team1Score;
  final int team2Score;
  final String? winner; // 'team1' or 'team2' or null

  SetScore({
    this.id,
    required this.matchId,
    required this.setNumber,
    required this.team1Score,
    required this.team2Score,
    this.winner,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'match_id': matchId,
      'set_number': setNumber,
      'team1_score': team1Score,
      'team2_score': team2Score,
      'winner': winner,
    };
  }

  factory SetScore.fromMap(Map<String, dynamic> map) {
    return SetScore(
      id: map['id'] as int?,
      matchId: map['match_id'] as int,
      setNumber: map['set_number'] as int,
      team1Score: map['team1_score'] as int,
      team2Score: map['team2_score'] as int,
      winner: map['winner'] as String?,
    );
  }
}
