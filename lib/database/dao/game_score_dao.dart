import 'package:sqflite/sqflite.dart';
import '../../models/game_score.dart';

/// ゲームスコア関連のCRUD操作を担当するDAOクラス
class GameScoreDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  GameScoreDao(this._getDatabase);

  /// 新しいゲームスコアを追加
  ///
  /// [gameScore] 追加するゲームスコアオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertGameScore(GameScore gameScore) async {
    final db = await _getDatabase();
    return await db.insert('game_scores', gameScore.toMap());
  }

  /// マッチIDでゲームスコアを取得
  ///
  /// [matchId] マッチID
  /// 戻り値: ゲーム番号の昇順でソートされたゲームスコアのリスト
  Future<List<GameScore>> getGameScoresByMatchId(int matchId) async {
    final db = await _getDatabase();
    final result = await db.query(
      'game_scores',
      where: 'match_id = ?',
      whereArgs: [matchId],
      orderBy: 'game_number ASC',
    );
    return result.map((map) => GameScore.fromMap(map)).toList();
  }

  /// ゲームスコアを更新
  ///
  /// [gameScore] 更新するゲームスコアオブジェクト（idが必須）
  /// 戻り値: 更新された行数
  Future<int> updateGameScore(GameScore gameScore) async {
    final db = await _getDatabase();
    return await db.update(
      'game_scores',
      gameScore.toMap(),
      where: 'id = ?',
      whereArgs: [gameScore.id],
    );
  }

  /// ゲームスコアを削除
  ///
  /// [id] 削除するゲームスコアID
  /// 戻り値: 削除された行数
  Future<int> deleteGameScore(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'game_scores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
