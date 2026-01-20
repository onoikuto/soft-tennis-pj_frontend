import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/match.dart';
import '../models/set_score.dart';
import '../models/game_score.dart';

/// データベースヘルパークラス
/// 
/// SQLiteデータベースへのアクセスを管理します。
/// シングルトンパターンで実装されており、アプリ全体で1つのインスタンスを共有します。
/// 
/// 主な機能:
/// - マッチ（試合）データのCRUD操作
/// - セットスコアのCRUD操作
/// - ゲームスコアのCRUD操作
class DatabaseHelper {
  // シングルトンインスタンス
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// データベースインスタンスを取得
  /// 
  /// 初回呼び出し時にデータベースを初期化し、
  /// 2回目以降はキャッシュされたインスタンスを返します。
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('soft_tennis.db');
    return _database!;
  }

  // ============================================================================
  // データベース初期化
  // ============================================================================

  /// データベースを初期化
  /// 
  /// Web版とデスクトップ/モバイル版で異なるパス処理を行います。
  /// 
  /// [filePath] データベースファイル名
  /// 戻り値: 初期化されたDatabaseインスタンス
  Future<Database> _initDB(String filePath) async {
    String path;
    if (kIsWeb) {
      // Web版: ファイル名をそのまま使用
      path = filePath;
    } else {
      // デスクトップ・モバイル版: アプリのデータディレクトリに配置
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 2, // データベースバージョン（スキーマ変更時に増加）
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ============================================================================
  // テーブル作成
  // ============================================================================

  /// データベースの初期作成
  /// 
  /// アプリ初回起動時に全テーブルを作成します。
  /// 
  /// [db] データベースインスタンス
  /// [version] データベースバージョン
  Future<void> _createDB(Database db, int version) async {
    await _createMatchesTable(db);
    await _createSetScoresTable(db);
    await _createGameScoresTable(db);
    await _createIndexes(db);
  }

  /// matchesテーブルを作成
  /// 
  /// 試合情報を保存するテーブル
  /// - id: 主キー（自動増分）
  /// - tournament_name: 大会名（オプション）
  /// - team1_player1, team1_player2: チーム1のプレイヤー名
  /// - team1_club: チーム1の所属（オプション）
  /// - team2_player1, team2_player2: チーム2のプレイヤー名
  /// - team2_club: チーム2の所属（オプション）
  /// - game_count: ゲーム数（デフォルト: 7）
  /// - first_serve: 先サーブチーム（'team1' or 'team2'）
  /// - created_at: 作成日時
  /// - completed_at: 完了日時（オプション）
  /// - winner: 勝利チーム（'team1' or 'team2'）
  Future<void> _createMatchesTable(Database db) async {
    await db.execute('''
      CREATE TABLE matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tournament_name TEXT,
        team1_player1 TEXT NOT NULL,
        team1_player2 TEXT NOT NULL,
        team1_club TEXT,
        team2_player1 TEXT NOT NULL,
        team2_player2 TEXT NOT NULL,
        team2_club TEXT,
        game_count INTEGER DEFAULT 7,
        first_serve TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        winner TEXT
      )
    ''');
  }

  /// set_scoresテーブルを作成
  /// 
  /// セットごとのスコアを保存するテーブル
  /// - id: 主キー（自動増分）
  /// - match_id: マッチID（外部キー、matchesテーブル参照）
  /// - set_number: セット番号（1, 2, 3...）
  /// - team1_score: チーム1のスコア
  /// - team2_score: チーム2のスコア
  /// - winner: セットの勝利チーム（'team1' or 'team2'）
  Future<void> _createSetScoresTable(Database db) async {
    await db.execute('''
      CREATE TABLE set_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        team1_score INTEGER NOT NULL,
        team2_score INTEGER NOT NULL,
        winner TEXT,
        FOREIGN KEY (match_id) REFERENCES matches (id) ON DELETE CASCADE
      )
    ''');
  }

  /// game_scoresテーブルを作成
  /// 
  /// ゲームごとの詳細なスコアを保存するテーブル
  /// - id: 主キー（自動増分）
  /// - match_id: マッチID（外部キー、matchesテーブル参照）
  /// - game_number: ゲーム番号（1, 2, 3...）
  /// - team1_score: チーム1のポイント数
  /// - team2_score: チーム2のポイント数
  /// - service_team: サーブ権を持つチーム（'team1' or 'team2'）
  /// - winner: ゲームの勝利チーム（'team1' or 'team2'）
  Future<void> _createGameScoresTable(Database db) async {
    await db.execute('''
      CREATE TABLE game_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id INTEGER NOT NULL,
        game_number INTEGER NOT NULL,
        team1_score INTEGER NOT NULL,
        team2_score INTEGER NOT NULL,
        service_team TEXT,
        winner TEXT,
        FOREIGN KEY (match_id) REFERENCES matches (id) ON DELETE CASCADE
      )
    ''');
  }

  /// インデックスを作成
  /// 
  /// クエリパフォーマンスを向上させるためのインデックス
  Future<void> _createIndexes(Database db) async {
    // セットスコアのマッチID検索を高速化
    await db.execute('CREATE INDEX idx_match_id ON set_scores(match_id)');
    // ゲームスコアのマッチID検索を高速化
    await db.execute('CREATE INDEX idx_game_match_id ON game_scores(match_id)');
  }

  // ============================================================================
  // データベースマイグレーション
  // ============================================================================

  /// データベースのバージョンアップグレード処理
  /// 
  /// 既存のデータベースを新しいスキーマに移行します。
  /// 
  /// [db] データベースインスタンス
  /// [oldVersion] 現在のバージョン
  /// [newVersion] 新しいバージョン
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // バージョン1から2へのマイグレーション
      // 新しいカラムを追加
      await db.execute('ALTER TABLE matches ADD COLUMN tournament_name TEXT');
      await db.execute('ALTER TABLE matches ADD COLUMN team1_club TEXT');
      await db.execute('ALTER TABLE matches ADD COLUMN team2_club TEXT');
      await db.execute('ALTER TABLE matches ADD COLUMN game_count INTEGER DEFAULT 7');
      await db.execute('ALTER TABLE matches ADD COLUMN first_serve TEXT');
      
      // ゲームスコアテーブルの作成（新機能）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS game_scores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          match_id INTEGER NOT NULL,
          game_number INTEGER NOT NULL,
          team1_score INTEGER NOT NULL,
          team2_score INTEGER NOT NULL,
          service_team TEXT,
          winner TEXT,
          FOREIGN KEY (match_id) REFERENCES matches (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_game_match_id ON game_scores(match_id)');
    }
    // 将来のバージョンアップグレード処理をここに追加
  }

  // ============================================================================
  // マッチ（試合）関連のCRUD操作
  // ============================================================================

  /// 新しいマッチを追加
  /// 
  /// [match] 追加するマッチオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertMatch(Match match) async {
    final db = await database;
    return await db.insert('matches', match.toMap());
  }

  /// すべてのマッチを取得
  /// 
  /// 作成日時の降順（新しい順）でソートされます。
  /// 戻り値: マッチのリスト
  Future<List<Match>> getAllMatches() async {
    final db = await database;
    final result = await db.query('matches', orderBy: 'created_at DESC');
    return result.map((map) => Match.fromMap(map)).toList();
  }

  /// IDでマッチを取得
  /// 
  /// [id] マッチID
  /// 戻り値: マッチオブジェクト（見つからない場合はnull）
  Future<Match?> getMatch(int id) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.delete(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // セットスコア関連のCRUD操作
  // ============================================================================

  /// 新しいセットスコアを追加
  /// 
  /// [setScore] 追加するセットスコアオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertSetScore(SetScore setScore) async {
    final db = await database;
    return await db.insert('set_scores', setScore.toMap());
  }

  /// マッチIDでセットスコアを取得
  /// 
  /// [matchId] マッチID
  /// 戻り値: セット番号の昇順でソートされたセットスコアのリスト
  Future<List<SetScore>> getSetScoresByMatchId(int matchId) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.delete(
      'set_scores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // ゲームスコア関連のCRUD操作
  // ============================================================================

  /// 新しいゲームスコアを追加
  /// 
  /// [gameScore] 追加するゲームスコアオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertGameScore(GameScore gameScore) async {
    final db = await database;
    return await db.insert('game_scores', gameScore.toMap());
  }

  /// マッチIDでゲームスコアを取得
  /// 
  /// [matchId] マッチID
  /// 戻り値: ゲーム番号の昇順でソートされたゲームスコアのリスト
  Future<List<GameScore>> getGameScoresByMatchId(int matchId) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.delete(
      'game_scores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // ユーティリティ
  // ============================================================================

  /// データベース接続を閉じる
  /// 
  /// アプリ終了時などに呼び出します。
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
