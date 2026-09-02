import 'package:sqflite/sqflite.dart';
import '../../models/point_detail.dart';

/// ポイント詳細関連のCRUD操作を担当するDAOクラス
class PointDetailDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  PointDetailDao(this._getDatabase);

  /// ポイント詳細を挿入
  Future<int> insertPointDetail(PointDetail pointDetail) async {
    final db = await _getDatabase();
    return await db.insert('point_details', pointDetail.toMap());
  }

  /// 指定したマッチのポイント詳細を全て取得
  Future<List<PointDetail>> getPointDetailsByMatchId(int matchId) async {
    final db = await _getDatabase();
    final result = await db.query(
      'point_details',
      where: 'match_id = ?',
      whereArgs: [matchId],
      orderBy: 'game_number ASC, point_number ASC',
    );
    return result.map((map) => PointDetail.fromMap(map)).toList();
  }

  /// 指定したマッチ・ゲームのポイント詳細を取得
  Future<List<PointDetail>> getPointDetailsByGameNumber(int matchId, int gameNumber) async {
    final db = await _getDatabase();
    final result = await db.query(
      'point_details',
      where: 'match_id = ? AND game_number = ?',
      whereArgs: [matchId, gameNumber],
      orderBy: 'point_number ASC',
    );
    return result.map((map) => PointDetail.fromMap(map)).toList();
  }

  /// ポイント詳細を更新
  Future<int> updatePointDetail(PointDetail pointDetail) async {
    final db = await _getDatabase();
    return await db.update(
      'point_details',
      pointDetail.toMap(),
      where: 'id = ?',
      whereArgs: [pointDetail.id],
    );
  }

  /// ポイント詳細を削除
  Future<int> deletePointDetail(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'point_details',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 指定したマッチの最後のポイント詳細を削除（Undo用）
  Future<int> deleteLastPointDetail(int matchId) async {
    final db = await _getDatabase();
    // 最後のポイント詳細を取得
    final result = await db.query(
      'point_details',
      where: 'match_id = ?',
      whereArgs: [matchId],
      orderBy: 'game_number DESC, point_number DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return await db.delete(
        'point_details',
        where: 'id = ?',
        whereArgs: [result.first['id']],
      );
    }
    return 0;
  }

  /// 指定したマッチにポイント詳細が存在するか確認
  Future<bool> hasPointDetails(int matchId) async {
    final db = await _getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM point_details WHERE match_id = ?',
      [matchId],
    );
    return (result.first['count'] as int) > 0;
  }

  /// point_detailsの選手名を一括更新
  ///
  /// 試合設定で選手名を変更した際に、その試合のpoint_detailsも更新します。
  /// [matchId] マッチID
  /// [oldName] 変更前の選手名
  /// [newName] 変更後の選手名
  Future<void> updatePlayerNameInPointDetails(int matchId, String oldName, String newName) async {
    final db = await _getDatabase();

    // server_playerの更新
    await db.rawUpdate(
      'UPDATE point_details SET server_player = ? WHERE match_id = ? AND server_player = ?',
      [newName, matchId, oldName],
    );

    // action_playerの更新
    await db.rawUpdate(
      'UPDATE point_details SET action_player = ? WHERE match_id = ? AND action_player = ?',
      [newName, matchId, oldName],
    );
  }
}
