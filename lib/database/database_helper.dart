import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/match.dart';
import '../models/set_score.dart';
import '../models/game_score.dart';
import '../models/point_detail.dart';

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
      version: 6, // データベースバージョン（スキーマ変更時に増加）
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
    await _createPlayersTable(db);
    await _createClubsTable(db);
    await _createPointDetailsTable(db);
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

  /// playersテーブルを作成
  /// 
  /// 選手マスター情報を保存するテーブル
  /// - id: 主キー（自動増分）
  /// - name: 選手名
  /// - club: 所属（学校・クラブ名）
  /// - display_name: 表示名（識別子付き、例：「山田（太）」）
  /// - created_at: 作成日時
  Future<void> _createPlayersTable(Database db) async {
    await db.execute('''
      CREATE TABLE players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        club TEXT,
        display_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// clubsテーブルを作成
  /// 
  /// 所属チームマスター情報を保存するテーブル
  /// - id: 主キー（自動増分）
  /// - name: 所属名
  /// - created_at: 作成日時
  Future<void> _createClubsTable(Database db) async {
    await db.execute('''
      CREATE TABLE clubs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// point_detailsテーブルを作成
  /// 
  /// ポイントごとの詳細情報を保存するテーブル（詳細入力モード用）
  /// - id: 主キー（自動増分）
  /// - match_id: マッチID（外部キー）
  /// - game_number: ゲーム番号
  /// - point_number: ゲーム内のポイント番号
  /// - server_team: サーブ側チーム（'team1' or 'team2'）
  /// - server_player: サーブを打った選手名
  /// - first_serve_in: 1stサーブが入ったか（1=入った, 0=入らなかった）
  /// - point_winner: ポイント獲得チーム（'team1' or 'team2'）
  /// - point_type: ポイント種類（'ace', 'winner', 'opponent_error'）
  /// - action_player: アクションを起こした選手名
  /// - created_at: 作成日時
  Future<void> _createPointDetailsTable(Database db) async {
    await db.execute('''
      CREATE TABLE point_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_id INTEGER NOT NULL,
        game_number INTEGER NOT NULL,
        point_number INTEGER NOT NULL,
        server_team TEXT NOT NULL,
        server_player TEXT,
        first_serve_in INTEGER NOT NULL,
        point_winner TEXT NOT NULL,
        point_type TEXT NOT NULL,
        action_player TEXT,
        created_at TEXT NOT NULL,
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
    // 選手の名前検索を高速化
    await db.execute('CREATE INDEX idx_player_name ON players(name)');
    // 選手の所属検索を高速化
    await db.execute('CREATE INDEX idx_player_club ON players(club)');
    // ポイント詳細のマッチID検索を高速化
    await db.execute('CREATE INDEX idx_point_details_match_id ON point_details(match_id)');
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
      // 新しいカラムを追加（既に存在する場合はエラーを無視）
      await _addColumnIfNotExists(db, 'matches', 'tournament_name', 'TEXT');
      await _addColumnIfNotExists(db, 'matches', 'team1_club', 'TEXT');
      await _addColumnIfNotExists(db, 'matches', 'team2_club', 'TEXT');
      await _addColumnIfNotExists(db, 'matches', 'game_count', 'INTEGER DEFAULT 7');
      await _addColumnIfNotExists(db, 'matches', 'first_serve', 'TEXT');
      
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
    if (oldVersion < 3) {
      // バージョン2から3へのマイグレーション
      // 選手マスターテーブルの作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS players (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          club TEXT,
          display_name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_player_name ON players(name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_player_club ON players(club)');
      
      // 所属チームマスターテーブルの作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clubs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      // バージョン3から4へのマイグレーション
      // ポイント詳細テーブルの作成（詳細入力モード用）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS point_details (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          match_id INTEGER NOT NULL,
          game_number INTEGER NOT NULL,
          point_number INTEGER NOT NULL,
          server_team TEXT NOT NULL,
          server_player TEXT,
          first_serve_in INTEGER NOT NULL,
          point_winner TEXT NOT NULL,
          point_type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (match_id) REFERENCES matches (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_point_details_match_id ON point_details(match_id)');
    }
    if (oldVersion < 5) {
      // バージョン4から5へのマイグレーション
      // action_playerカラムを追加
      await _addColumnIfNotExists(db, 'point_details', 'action_player', 'TEXT');
    }
    if (oldVersion < 6) {
      // バージョン5から6へのマイグレーション
      // server_playerカラムを追加
      await _addColumnIfNotExists(db, 'point_details', 'server_player', 'TEXT');
    }
    // 将来のバージョンアップグレード処理をここに追加
  }

  /// カラムが存在しない場合のみ追加する
  Future<void> _addColumnIfNotExists(
    Database db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    try {
      // テーブルのスキーマを取得してカラムの存在を確認
      final result = await db.rawQuery(
        "PRAGMA table_info($tableName)",
      );
      final columnExists = result.any((row) => row['name'] == columnName);
      
      if (!columnExists) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
        );
      }
    } catch (e) {
      // エラーが発生した場合も続行（カラムが既に存在する可能性）
      debugPrint('カラム追加エラー（無視）: $tableName.$columnName - $e');
    }
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

  /// 過去の選手名のリストを取得
  /// 
  /// データベースに保存されているすべての選手名を重複なしで取得します。
  Future<List<String>> getAllPlayerNames() async {
    final db = await database;
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

  /// 過去の所属名のリストを取得
  /// 
  /// データベースに保存されているすべての所属名を重複なしで取得します。
  /// まずclubsテーブルから取得し、なければmatchesテーブルから取得します。
  Future<List<String>> getAllClubs() async {
    final db = await database;
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

  // ============================================================================
  // 選手マスター関連のCRUD操作
  // ============================================================================

  /// 名前と所属の組み合わせで重複チェック
  /// 
  /// 同じ名前・同じ所属の選手が既に存在するかチェックします。
  /// [excludeId]が指定されている場合、そのIDの選手はチェックから除外します（編集時用）。
  Future<bool> checkPlayerDuplicate({
    required String name,
    String? club,
    int? excludeId,
  }) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.query('players', orderBy: 'name ASC, club ASC');
  }

  /// IDで選手を取得
  Future<Map<String, dynamic>?> getPlayer(int id) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.delete(
      'players',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // 所属チームマスター関連のCRUD操作
  // ============================================================================

  /// 新しい所属チームを追加
  Future<int> insertClub({required String name}) async {
    final db = await database;
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
    final db = await database;
    try {
      return await db.query('clubs', orderBy: 'name ASC');
    } catch (e) {
      return [];
    }
  }

  /// IDで所属チームを取得
  Future<Map<String, dynamic>?> getClub(int id) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.delete(
      'clubs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // ポイント詳細 CRUD操作
  // ============================================================================

  /// ポイント詳細を挿入
  Future<int> insertPointDetail(PointDetail pointDetail) async {
    final db = await database;
    return await db.insert('point_details', pointDetail.toMap());
  }

  /// 指定したマッチのポイント詳細を全て取得
  Future<List<PointDetail>> getPointDetailsByMatchId(int matchId) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    return await db.update(
      'point_details',
      pointDetail.toMap(),
      where: 'id = ?',
      whereArgs: [pointDetail.id],
    );
  }

  /// ポイント詳細を削除
  Future<int> deletePointDetail(int id) async {
    final db = await database;
    return await db.delete(
      'point_details',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 指定したマッチの最後のポイント詳細を削除（Undo用）
  Future<int> deleteLastPointDetail(int matchId) async {
    final db = await database;
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
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM point_details WHERE match_id = ?',
      [matchId],
    );
    return (result.first['count'] as int) > 0;
  }

  /// データベース接続を閉じる
  /// 
  /// アプリ終了時などに呼び出します。
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
