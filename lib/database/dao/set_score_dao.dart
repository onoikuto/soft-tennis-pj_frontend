import 'package:sqflite/sqflite.dart';
import '../../models/set_score.dart';

/// セットスコア関連のCRUD操作を担当するDAOクラス
class SetScoreDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  SetScoreDao(this._getDatabase);

  /// 新しいセットスコアを追加
  ///
  /// [setScore] 追加するセットスコアオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertSetScore(SetScore setScore) async {
    final db = await _getDatabase();
    return await db.insert('set_scores', setScore.toMap());
  }

  /// マッチIDでセットスコアを取得
  ///
  /// [matchId] マッチID
  /// 戻り値: セット番号の昇順でソートされたセットスコアのリスト
  Future<List<SetScore>> getSetScoresByMatchId(int matchId) async {
    final db = await _getDatabase();
    final result = await db.query(
      'set_scores',
      where: 'match_id = ?',
      whereArgs: [matchId],
      orderBy: 'set_number ASC',
    );
    return result.map((map) => SetScore.fromMap(map)).toList();
  }

  /// セットスコアを更新
  ///
  /// [setScore] 更新するセットスコアオブジェクト（idが必須）
  /// 戻り値: 更新された行数
  Future<int> updateSetScore(SetScore setScore) async {
    final db = await _getDatabase();
    return await db.update(
      'set_scores',
      setScore.toMap(),
      where: 'id = ?',
      whereArgs: [setScore.id],
    );
  }

  /// セットスコアを削除
  ///
  /// [id] 削除するセットスコアID
  /// 戻り値: 削除された行数
  Future<int> deleteSetScore(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'set_scores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
