import 'package:sqflite/sqflite.dart';

/// 所属チームマスター関連のCRUD操作を担当するDAOクラス
class ClubDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  ClubDao(this._getDatabase);

  /// 過去の所属名のリストを取得
  ///
  /// データベースに保存されているすべての所属名を重複なしで取得します。
  /// まずclubsテーブルから取得し、なければmatchesテーブルから取得します。
  Future<List<String>> getAllClubs() async {
    final db = await _getDatabase();
    final clubs = <String>{};

    // clubsテーブルから取得
    try {
      final clubRecords = await db.query('clubs', orderBy: 'name ASC');
      for (var record in clubRecords) {
        clubs.add(record['name'] as String);
      }
    } catch (e) {
      // テーブルが存在しない場合は無視
    }

    // matchesテーブルからも取得（後方互換性のため）
    final matches = await db.query('matches');
    for (var match in matches) {
      if (match['team1_club'] != null && (match['team1_club'] as String).isNotEmpty) {
        clubs.add(match['team1_club'] as String);
      }
      if (match['team2_club'] != null && (match['team2_club'] as String).isNotEmpty) {
        clubs.add(match['team2_club'] as String);
      }
    }

    return clubs.toList()..sort();
  }

  /// 新しい所属チームを追加
  Future<int> insertClub({required String name}) async {
    final db = await _getDatabase();
    try {
      return await db.insert('clubs', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // UNIQUE制約違反の場合は既に存在する
      return -1;
    }
  }

  /// すべての所属チームを取得
  Future<List<Map<String, dynamic>>> getAllClubsMaster() async {
    final db = await _getDatabase();
    try {
      return await db.query('clubs', orderBy: 'name ASC');
    } catch (e) {
      return [];
    }
  }

  /// IDで所属チームを取得
  Future<Map<String, dynamic>?> getClub(int id) async {
    final db = await _getDatabase();
    try {
      final result = await db.query(
        'clubs',
        where: 'id = ?',
        whereArgs: [id],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      return null;
    }
  }

  /// 所属チームを更新
  Future<int> updateClub({required int id, required String name}) async {
    final db = await _getDatabase();
    try {
      return await db.update(
        'clubs',
        {'name': name},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      // UNIQUE制約違反の場合は既に存在する
      return -1;
    }
  }

  /// 所属チームを削除
  Future<int> deleteClub(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'clubs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
