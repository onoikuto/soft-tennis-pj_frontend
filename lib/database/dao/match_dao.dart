import 'package:sqflite/sqflite.dart';
import '../../models/match.dart';

/// マッチ（試合）関連のCRUD操作を担当するDAOクラス
class MatchDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  MatchDao(this._getDatabase);

  /// 新しいマッチを追加
  ///
  /// [match] 追加するマッチオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertMatch(Match match) async {
    final db = await _getDatabase();
    return await db.insert('matches', match.toMap());
  }

  /// すべてのマッチを取得
  ///
  /// 作成日時の降順（新しい順）でソートされます。
  /// 戻り値: マッチのリスト
  Future<List<Match>> getAllMatches() async {
    final db = await _getDatabase();
    final result = await db.query('matches', orderBy: 'created_at DESC');
    return result.map((map) => Match.fromMap(map)).toList();
  }

  /// IDでマッチを取得
  ///
  /// [id] マッチID
  /// 戻り値: マッチオブジェクト（見つからない場合はnull）
  Future<Match?> getMatch(int id) async {
    final db = await _getDatabase();
    final result = await db.query(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Match.fromMap(result.first);
    }
    return null;
  }

  /// マッチを更新
  ///
  /// [match] 更新するマッチオブジェクト（idが必須）
  /// 戻り値: 更新された行数
  Future<int> updateMatch(Match match) async {
    final db = await _getDatabase();
    return await db.update(
      'matches',
      match.toMap(),
      where: 'id = ?',
      whereArgs: [match.id],
    );
  }

  /// マッチを削除
  ///
  /// 外部キー制約により、関連するセットスコアとゲームスコアも自動的に削除されます。
  ///
  /// [id] 削除するマッチID
  /// 戻り値: 削除された行数
  Future<int> deleteMatch(int id) async {
    final db = await _getDatabase();
    return await db.delete(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 過去の選手名のリストを取得
  ///
  /// データベースに保存されているすべての選手名を重複なしで取得します。
  Future<List<String>> getAllPlayerNames() async {
    final db = await _getDatabase();
    final matches = await db.query('matches');
    final playerNames = <String>{};

    for (var match in matches) {
      if (match['team1_player1'] != null) {
        playerNames.add(match['team1_player1'] as String);
      }
      if (match['team1_player2'] != null) {
        playerNames.add(match['team1_player2'] as String);
      }
      if (match['team2_player1'] != null) {
        playerNames.add(match['team2_player1'] as String);
      }
      if (match['team2_player2'] != null) {
        playerNames.add(match['team2_player2'] as String);
      }
    }

    return playerNames.toList()..sort();
  }
}
