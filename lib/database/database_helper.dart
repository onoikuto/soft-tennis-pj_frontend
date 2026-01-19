import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/match.dart';
import '../models/set_score.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('soft_tennis.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (kIsWeb) {
      // Web版
      path = filePath;
    } else {
      // デスクトップ・モバイル版
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // マッチテーブル
    await db.execute('''
      CREATE TABLE matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        team1_player1 TEXT NOT NULL,
        team1_player2 TEXT NOT NULL,
        team2_player1 TEXT NOT NULL,
        team2_player2 TEXT NOT NULL,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        winner TEXT
      )
    ''');

    // セットスコアテーブル
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

    // インデックスの作成
    await db.execute('CREATE INDEX idx_match_id ON set_scores(match_id)');
  }

  // マッチ関連のメソッド
  Future<int> insertMatch(Match match) async {
    final db = await database;
    return await db.insert('matches', match.toMap());
  }

  Future<List<Match>> getAllMatches() async {
    final db = await database;
    final result = await db.query('matches', orderBy: 'created_at DESC');
    return result.map((map) => Match.fromMap(map)).toList();
  }

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

  Future<int> updateMatch(Match match) async {
    final db = await database;
    return await db.update(
      'matches',
      match.toMap(),
      where: 'id = ?',
      whereArgs: [match.id],
    );
  }

  Future<int> deleteMatch(int id) async {
    final db = await database;
    return await db.delete(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // セットスコア関連のメソッド
  Future<int> insertSetScore(SetScore setScore) async {
    final db = await database;
    return await db.insert('set_scores', setScore.toMap());
  }

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

  Future<int> updateSetScore(SetScore setScore) async {
    final db = await database;
    return await db.update(
      'set_scores',
      setScore.toMap(),
      where: 'id = ?',
      whereArgs: [setScore.id],
    );
  }

  Future<int> deleteSetScore(int id) async {
    final db = await database;
    return await db.delete(
      'set_scores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
