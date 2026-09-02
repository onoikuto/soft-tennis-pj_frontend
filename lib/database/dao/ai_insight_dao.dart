import 'package:sqflite/sqflite.dart';

/// AI分析コメントのキャッシュを担当するDAOクラス
///
/// 生成結果は scope（'overall' or 'match'）ごとに最新1件だけを持ちます。
class AiInsightDao {
  /// データベースインスタンスを取得する関数
  final Future<Database> Function() _getDatabase;

  AiInsightDao(this._getDatabase);

  /// 分析コメントを保存（同じ対象の古い結果は置き換える）
  ///
  /// [scope] 'overall'（通算）または 'match'（試合単体）
  /// [subject] 集計対象のキー（ペア・学校・個人で別々に持つ）
  /// [matchId] scope='match' のときの対象試合ID
  /// [statsHash] 生成元スタッツのハッシュ
  /// [commentsJson] 生成されたコメントのJSON配列文字列
  Future<void> save({
    required String scope,
    required String subject,
    int matchId = 0,
    required String statsHash,
    required String commentsJson,
  }) async {
    final db = await _getDatabase();
    await db.insert(
      'ai_insights',
      {
        'scope': scope,
        'subject': subject,
        'match_id': matchId,
        'stats_hash': statsHash,
        'comments': commentsJson,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 保存済みの分析コメントを取得
  ///
  /// [statsHash] を渡すと、生成元スタッツが一致するものだけを返します。
  /// 一致しない（＝その後に試合を記録した）場合はnullを返すので、
  /// 呼び出し側は画面の数値と食い違う分析を表示せずに済みます。
  Future<String?> find({
    required String scope,
    required String subject,
    int matchId = 0,
    required String statsHash,
  }) async {
    final db = await _getDatabase();
    try {
      final result = await db.query(
        'ai_insights',
        columns: ['comments'],
        where: 'scope = ? AND subject = ? AND match_id = ? AND stats_hash = ?',
        whereArgs: [scope, subject, matchId, statsHash],
        limit: 1,
      );
      return result.isNotEmpty ? result.first['comments'] as String : null;
    } catch (e) {
      // テーブルが無い等の場合はキャッシュ無しとして扱う
      return null;
    }
  }
}
