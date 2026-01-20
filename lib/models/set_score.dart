/// セットスコアモデル
/// 
/// ソフトテニスのセットごとのスコアを表すデータモデルです。
/// 1つの試合（Match）に対して複数のセットスコアが存在します。
class SetScore {
  /// データベース上の主キー（自動生成）
  final int? id;

  /// 関連するマッチ（試合）のID
  /// 外部キー: matchesテーブルを参照
  final int matchId;

  /// セット番号
  /// 1, 2, 3... の順番で付与されます
  final int setNumber;

  /// チーム1のセットスコア
  /// セットを獲得したゲーム数
  final int team1Score;

  /// チーム2のセットスコア
  /// セットを獲得したゲーム数
  final int team2Score;

  /// セットの勝利チーム
  /// 'team1': チーム1がセットを獲得
  /// 'team2': チーム2がセットを獲得
  /// null: セットが進行中または未完了
  final String? winner;

  SetScore({
    this.id,
    required this.matchId,
    required this.setNumber,
    required this.team1Score,
    required this.team2Score,
    this.winner,
  });

  /// データベース保存用のMapに変換
  /// 
  /// SQLiteのテーブル構造に合わせて、フィールド名をスネークケースに変換します。
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

  /// データベースから取得したMapからSetScoreオブジェクトを生成
  /// 
  /// [map] データベースクエリ結果のMap
  /// 戻り値: SetScoreオブジェクト
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

  /// セットが完了しているかどうかを判定
  bool get isCompleted => winner != null;

  /// スコアの表示形式を取得
  /// 
  /// 例: "6-4" または "進行中"
  String get scoreDisplay {
    if (isCompleted) {
      return '$team1Score-$team2Score';
    }
    return '$team1Score-$team2Score (進行中)';
  }
}
