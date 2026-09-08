import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// データベーススキーマ管理クラス
///
/// テーブル作成・インデックス作成・マイグレーション処理を担当します。
/// CRUD操作は各DAOクラス（lib/database/dao/配下）を参照してください。
class DatabaseSchema {
  DatabaseSchema._();

  // ============================================================================
  // テーブル作成
  // ============================================================================

  /// データベースの初期作成
  ///
  /// アプリ初回起動時に全テーブルを作成します。
  ///
  /// [db] データベースインスタンス
  /// [version] データベースバージョン
  static Future<void> createDB(Database db, int version) async {
    await _createMatchesTable(db);
    await _createSetScoresTable(db);
    await _createGameScoresTable(db);
    await _createPlayersTable(db);
    await _createClubsTable(db);
    await _createPointDetailsTable(db);
    await _createAiInsightsTable(db);
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
  static Future<void> _createMatchesTable(Database db) async {
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
  static Future<void> _createSetScoresTable(Database db) async {
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
  static Future<void> _createGameScoresTable(Database db) async {
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
  static Future<void> _createPlayersTable(Database db) async {
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
  static Future<void> _createClubsTable(Database db) async {
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
  static Future<void> _createPointDetailsTable(Database db) async {
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
        error_type TEXT,
        shot_type TEXT,
        course_type TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (match_id) REFERENCES matches (id) ON DELETE CASCADE
      )
    ''');
  }

  /// ai_insightsテーブルを作成
  ///
  /// AIが生成した分析コメントを保存するテーブル
  ///
  /// 統計画面を開くたびに生成すると待ち時間と通信費がかかるため、
  /// 生成結果はここに1件だけ持ち、画面は必ずここから読みます。
  /// - scope: 分析の種類（'overall'=通算 / 'match'=試合単体）
  /// - subject: 集計対象（ペア・学校・個人で分析の中身が変わるため分けて持つ）
  /// - match_id: scope='match' のときの対象試合ID（'overall' のときは0）
  /// - stats_hash: 生成元スタッツのハッシュ。現在のスタッツと一致しなければ
  ///   古い分析なので表示せず、ルールベースの分析に戻す
  /// - comments: 生成されたコメントのJSON配列
  static Future<void> _createAiInsightsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ai_insights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scope TEXT NOT NULL,
        subject TEXT NOT NULL DEFAULT '',
        match_id INTEGER NOT NULL DEFAULT 0,
        stats_hash TEXT NOT NULL,
        comments TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (scope, subject, match_id)
      )
    ''');
  }

  /// インデックスを作成
  ///
  /// クエリパフォーマンスを向上させるためのインデックス
  static Future<void> _createIndexes(Database db) async {
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
  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
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
    if (oldVersion < 7) {
      // バージョン6から7へのマイグレーション
      // AI分析コメントのキャッシュテーブルを作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ai_insights (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scope TEXT NOT NULL,
          subject TEXT NOT NULL DEFAULT '',
          match_id INTEGER NOT NULL DEFAULT 0,
          stats_hash TEXT NOT NULL,
          comments TEXT NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE (scope, subject, match_id)
        )
      ''');
    }
    if (oldVersion < 8) {
      // バージョン7から8へのマイグレーション
      // ミスの種類（ネット/アウト/ダブルフォルト）カラムを追加
      await _addColumnIfNotExists(db, 'point_details', 'error_type', 'TEXT');
    }
    if (oldVersion < 9) {
      // バージョン8から9へのマイグレーション
      // ショットの種類（フォアハンド/バックハンド/ボレー等）カラムを追加
      await _addColumnIfNotExists(db, 'point_details', 'shot_type', 'TEXT');
    }
    if (oldVersion < 10) {
      // バージョン9から10へのマイグレーション
      // 打球のコース（左ストレート/右ストレート/クロス/逆クロス）カラムを追加
      await _addColumnIfNotExists(db, 'point_details', 'course_type', 'TEXT');
    }
    // 将来のバージョンアップグレード処理をここに追加
  }

  /// カラムが存在しない場合のみ追加する
  static Future<void> _addColumnIfNotExists(
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
}
