import 'package:sqflite/sqflite.dart';

/// 選手マスター関連のCRUD操作を担当するDAOクラス
class PlayerDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  PlayerDao(this._getDatabase);

  /// 名前と所属の組み合わせで重複チェック
  ///
  /// 同じ名前・同じ所属の選手が既に存在するかチェックします。
  /// [excludeId]が指定されている場合、そのIDの選手はチェックから除外します（編集時用）。
  Future<bool> checkPlayerDuplicate({
    required String name,
    String? club,
    int? excludeId,
  }) async {
    final db = await _getDatabase();
    final clubValue = club?.trim() ?? '';
    final List<Map<String, dynamic>> result;

    if (excludeId != null) {
      result = await db.query(
        'players',
        where: 'name = ? AND club = ? AND id != ?',
        whereArgs: [name.trim(), clubValue, excludeId],
      );
    } else {
      result = await db.query(
        'players',
        where: 'name = ? AND club = ?',
        whereArgs: [name.trim(), clubValue],
      );
    }

    return result.isNotEmpty;
  }

  /// 新しい選手を追加
  Future<int> insertPlayer({
    required String name,
    String? club,
  }) async {
    final db = await _getDatabase();
    final clubValue = club?.trim() ?? '';
    return await db.insert('players', {
      'name': name.trim(),
      'club': clubValue,
      'display_name': name.trim(), // 後方互換性のため残すが、nameと同じ値を設定
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// すべての選手を取得
  Future<List<Map<String, dynamic>>> getAllPlayers() async {
    final db = await _getDatabase();
    return await db.query('players', orderBy: 'name ASC, club ASC');
  }

  /// IDで選手を取得
  Future<Map<String, dynamic>?> getPlayer(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'players',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// 選手を更新
  Future<int> updatePlayer({
    required int id,
    required String name,
    String? club,
  }) async {
    final db = await _getDatabase();
    final clubValue = club?.trim() ?? '';
    return await db.update(
      'players',
      {
        'name': name.trim(),
        'club': clubValue,
        'display_name': name.trim(), // 後方互換性のため残すが、nameと同じ値を設定
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 選手を削除
  Future<int> deletePlayer(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'players',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
