/// マッチ（試合）モデル
/// 
/// ソフトテニスの試合情報を表すデータモデルです。
/// 2つのチーム（ペア）の情報、大会情報、試合の進行状況などを保持します。
class Match {
  /// データベース上の主キー（自動生成）
  final int? id;

  /// 大会名
  /// 例: "夏季市民ソフトテニス大会"
  final String tournamentName;

  /// チーム1（ペアA）のプレイヤー1の名前
  final String team1Player1;

  /// チーム1（ペアA）のプレイヤー2の名前
  final String team1Player2;

  /// チーム1（ペアA）の所属（学校・クラブ名など）
  /// ペア共通の所属名を設定
  final String team1Club;

  /// チーム2（ペアB）のプレイヤー1の名前
  final String team2Player1;

  /// チーム2（ペアB）のプレイヤー2の名前
  final String team2Player2;

  /// チーム2（ペアB）の所属（学校・クラブ名など）
  /// ペア共通の所属名を設定
  final String team2Club;

  /// ゲーム数設定
  /// デフォルト: 7
  /// 有効な値: 5, 7, 9
  final int gameCount;

  /// 先サーブチーム
  /// 'team1': チーム1が先サーブ
  /// 'team2': チーム2が先サーブ
  /// null: 未設定
  final String? firstServe;

  /// 試合作成日時
  final DateTime createdAt;

  /// 試合完了日時
  /// null: 試合が進行中
  final DateTime? completedAt;

  /// 勝利チーム
  /// 'team1': チーム1の勝利
  /// 'team2': チーム2の勝利
  /// null: 試合が進行中または未完了
  final String? winner;

  Match({
    this.id,
    required this.tournamentName,
    required this.team1Player1,
    required this.team1Player2,
    required this.team1Club,
    required this.team2Player1,
    required this.team2Player2,
    required this.team2Club,
    this.gameCount = 7,
    this.firstServe,
    required this.createdAt,
    this.completedAt,
    this.winner,
  });

  /// データベース保存用のMapに変換
  /// 
  /// SQLiteのテーブル構造に合わせて、フィールド名をスネークケースに変換します。
  /// DateTimeはISO8601形式の文字列に変換されます。
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

  /// データベースから取得したMapからMatchオブジェクトを生成
  /// 
  /// [map] データベースクエリ結果のMap
  /// 戻り値: Matchオブジェクト
  factory Match.fromMap(Map<String, dynamic> map) {
    return Match(
      id: map['id'] as int?,
      tournamentName: map['tournament_name'] as String? ?? '',
      team1Player1: map['team1_player1'] as String,
      team1Player2: map['team1_player2'] as String,
      team1Club: map['team1_club'] as String? ?? '',
      team2Player1: map['team2_player1'] as String,
      team2Player2: map['team2_player2'] as String,
      team2Club: map['team2_club'] as String? ?? '',
      gameCount: map['game_count'] as int? ?? 7,
      firstServe: map['first_serve'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      winner: map['winner'] as String?,
    );
  }

  /// チーム1の表示名を取得
  /// 
  /// プレイヤー名と所属を組み合わせた文字列を返します。
  /// 例: "田中・佐藤 (早稲田大学)"
  String get team1DisplayName {
    final players = '$team1Player1・$team1Player2';
    return team1Club.isNotEmpty ? '$players ($team1Club)' : players;
  }

  /// チーム2の表示名を取得
  /// 
  /// プレイヤー名と所属を組み合わせた文字列を返します。
  /// 例: "伊藤・鈴木 (慶應大学)"
  String get team2DisplayName {
    final players = '$team2Player1・$team2Player2';
    return team2Club.isNotEmpty ? '$players ($team2Club)' : players;
  }

  /// 試合が完了しているかどうかを判定
  bool get isCompleted => completedAt != null && winner != null;
}
