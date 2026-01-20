/// ゲームスコアモデル
/// 
/// ソフトテニスのゲームごとの詳細なスコアを表すデータモデルです。
/// 1つの試合（Match）に対して複数のゲームスコアが存在します。
/// 
/// ゲームのルール:
/// - 4ポイント先取でゲームを獲得（ただし2ポイント差が必要）
/// - デュース（3-3）の場合は、2ポイント差がつくまで継続
class GameScore {
  /// データベース上の主キー（自動生成）
  final int? id;

  /// 関連するマッチ（試合）のID
  /// 外部キー: matchesテーブルを参照
  final int matchId;

  /// ゲーム番号
  /// 1, 2, 3, 4, 5, 6, 7... の順番で付与されます
  final int gameNumber;

  /// チーム1のポイント数
  /// 0, 1, 2, 3, 4... の値
  /// 4ポイント先取（2ポイント差）でゲームを獲得
  final int team1Score;

  /// チーム2のポイント数
  /// 0, 1, 2, 3, 4... の値
  /// 4ポイント先取（2ポイント差）でゲームを獲得
  final int team2Score;

  /// サーブ権を持つチーム
  /// 'team1': チーム1がサーブ権を持つ
  /// 'team2': チーム2がサーブ権を持つ
  /// null: 未設定
  final String? serviceTeam;

  /// ゲームの勝利チーム
  /// 'team1': チーム1がゲームを獲得
  /// 'team2': チーム2がゲームを獲得
  /// null: ゲームが進行中または未完了
  final String? winner;

  GameScore({
    this.id,
    required this.matchId,
    required this.gameNumber,
    required this.team1Score,
    required this.team2Score,
    this.serviceTeam,
    this.winner,
  });

  /// データベース保存用のMapに変換
  /// 
  /// SQLiteのテーブル構造に合わせて、フィールド名をスネークケースに変換します。
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

  /// データベースから取得したMapからGameScoreオブジェクトを生成
  /// 
  /// [map] データベースクエリ結果のMap
  /// 戻り値: GameScoreオブジェクト
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

  /// ゲームが完了しているかどうかを判定
  /// 
  /// 勝利チームが決定している場合にtrueを返します。
  bool get isCompleted => winner != null;

  /// ゲームの勝敗を判定
  /// 
  /// 4ポイント先取かつ2ポイント差でゲームを獲得します。
  /// 戻り値: 勝利チーム（'team1' or 'team2'）またはnull（進行中）
  String? determineWinner() {
    if (team1Score >= 4 && team1Score - team2Score >= 2) {
      return 'team1';
    } else if (team2Score >= 4 && team2Score - team1Score >= 2) {
      return 'team2';
    }
    return null;
  }

  /// スコアの表示形式を取得
  /// 
  /// 例: "4-2" または "デュース (3-3)"
  String get scoreDisplay {
    if (team1Score == team2Score && team1Score >= 3) {
      return 'デュース ($team1Score-$team2Score)';
    }
    return '$team1Score-$team2Score';
  }
}
