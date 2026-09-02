import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/match.dart';
import '../models/set_score.dart';
import '../models/game_score.dart';
import '../models/point_detail.dart';
import 'database_schema.dart';
import 'dao/match_dao.dart';
import 'dao/set_score_dao.dart';
import 'dao/game_score_dao.dart';
import 'dao/player_dao.dart';
import 'dao/club_dao.dart';
import 'dao/point_detail_dao.dart';
import 'dao/ai_insight_dao.dart';

/// データベースヘルパークラス
///
/// SQLiteデータベースへのアクセスを管理します。
/// シングルトンパターンで実装されており、アプリ全体で1つのインスタンスを共有します。
///
/// テーブル作成・マイグレーションは[DatabaseSchema]、
/// 各テーブルのCRUD操作はテーブルごとのDAOクラス（lib/database/dao/配下）に
/// 分割されており、本クラスは既存の公開APIを維持するファサードとして
/// 各DAOへ処理を委譲します。
///
/// 主な機能:
/// - マッチ（試合）データのCRUD操作
/// - セットスコアのCRUD操作
/// - ゲームスコアのCRUD操作
class DatabaseHelper {
  // シングルトンインスタンス
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // テーブルごとのDAO
  late final MatchDao _matchDao = MatchDao(() => database);
  late final SetScoreDao _setScoreDao = SetScoreDao(() => database);
  late final GameScoreDao _gameScoreDao = GameScoreDao(() => database);
  late final PlayerDao _playerDao = PlayerDao(() => database);
  late final ClubDao _clubDao = ClubDao(() => database);
  late final PointDetailDao _pointDetailDao = PointDetailDao(() => database);
  late final AiInsightDao _aiInsightDao = AiInsightDao(() => database);

  /// AI分析コメントのキャッシュ
  AiInsightDao get aiInsights => _aiInsightDao;

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
      version: 7, // データベースバージョン（スキーマ変更時に増加）
      onCreate: DatabaseSchema.createDB,
      onUpgrade: DatabaseSchema.onUpgrade,
    );
  }

  // ============================================================================
  // マッチ（試合）関連のCRUD操作
  // ============================================================================

  /// 新しいマッチを追加
  ///
  /// [match] 追加するマッチオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertMatch(Match match) => _matchDao.insertMatch(match);

  /// すべてのマッチを取得
  ///
  /// 作成日時の降順（新しい順）でソートされます。
  /// 戻り値: マッチのリスト
  Future<List<Match>> getAllMatches() => _matchDao.getAllMatches();

  /// IDでマッチを取得
  ///
  /// [id] マッチID
  /// 戻り値: マッチオブジェクト（見つからない場合はnull）
  Future<Match?> getMatch(int id) => _matchDao.getMatch(id);

  /// マッチを更新
  ///
  /// [match] 更新するマッチオブジェクト（idが必須）
  /// 戻り値: 更新された行数
  Future<int> updateMatch(Match match) => _matchDao.updateMatch(match);

  /// マッチを削除
  ///
  /// 外部キー制約により、関連するセットスコアとゲームスコアも自動的に削除されます。
  ///
  /// [id] 削除するマッチID
  /// 戻り値: 削除された行数
  Future<int> deleteMatch(int id) => _matchDao.deleteMatch(id);

  // ============================================================================
  // セットスコア関連のCRUD操作
  // ============================================================================

  /// 新しいセットスコアを追加
  ///
  /// [setScore] 追加するセットスコアオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertSetScore(SetScore setScore) =>
      _setScoreDao.insertSetScore(setScore);

  /// マッチIDでセットスコアを取得
  ///
  /// [matchId] マッチID
  /// 戻り値: セット番号の昇順でソートされたセットスコアのリスト
  Future<List<SetScore>> getSetScoresByMatchId(int matchId) =>
      _setScoreDao.getSetScoresByMatchId(matchId);

  /// セットスコアを更新
  ///
  /// [setScore] 更新するセットスコアオブジェクト（idが必須）
  /// 戻り値: 更新された行数
  Future<int> updateSetScore(SetScore setScore) =>
      _setScoreDao.updateSetScore(setScore);

  /// セットスコアを削除
  ///
  /// [id] 削除するセットスコアID
  /// 戻り値: 削除された行数
  Future<int> deleteSetScore(int id) => _setScoreDao.deleteSetScore(id);

  // ============================================================================
  // ゲームスコア関連のCRUD操作
  // ============================================================================

  /// 新しいゲームスコアを追加
  ///
  /// [gameScore] 追加するゲームスコアオブジェクト
  /// 戻り値: 挿入されたレコードのID
  Future<int> insertGameScore(GameScore gameScore) =>
      _gameScoreDao.insertGameScore(gameScore);

  /// マッチIDでゲームスコアを取得
  ///
  /// [matchId] マッチID
  /// 戻り値: ゲーム番号の昇順でソートされたゲームスコアのリスト
  Future<List<GameScore>> getGameScoresByMatchId(int matchId) =>
      _gameScoreDao.getGameScoresByMatchId(matchId);

  /// ゲームスコアを更新
  ///
  /// [gameScore] 更新するゲームスコアオブジェクト（idが必須）
  /// 戻り値: 更新された行数
  Future<int> updateGameScore(GameScore gameScore) =>
      _gameScoreDao.updateGameScore(gameScore);

  /// ゲームスコアを削除
  ///
  /// [id] 削除するゲームスコアID
  /// 戻り値: 削除された行数
  Future<int> deleteGameScore(int id) => _gameScoreDao.deleteGameScore(id);

  // ============================================================================
  // ユーティリティ
  // ============================================================================

  /// 過去の選手名のリストを取得
  ///
  /// データベースに保存されているすべての選手名を重複なしで取得します。
  Future<List<String>> getAllPlayerNames() => _matchDao.getAllPlayerNames();

  /// 過去の所属名のリストを取得
  ///
  /// データベースに保存されているすべての所属名を重複なしで取得します。
  /// まずclubsテーブルから取得し、なければmatchesテーブルから取得します。
  Future<List<String>> getAllClubs() => _clubDao.getAllClubs();

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
  }) =>
      _playerDao.checkPlayerDuplicate(
        name: name,
        club: club,
        excludeId: excludeId,
      );

  /// 新しい選手を追加
  Future<int> insertPlayer({
    required String name,
    String? club,
  }) =>
      _playerDao.insertPlayer(name: name, club: club);

  /// すべての選手を取得
  Future<List<Map<String, dynamic>>> getAllPlayers() =>
      _playerDao.getAllPlayers();

  /// IDで選手を取得
  Future<Map<String, dynamic>?> getPlayer(int id) => _playerDao.getPlayer(id);

  /// 選手を更新
  Future<int> updatePlayer({
    required int id,
    required String name,
    String? club,
  }) =>
      _playerDao.updatePlayer(id: id, name: name, club: club);

  /// 選手を削除
  Future<int> deletePlayer(int id) => _playerDao.deletePlayer(id);

  // ============================================================================
  // 所属チームマスター関連のCRUD操作
  // ============================================================================

  /// 新しい所属チームを追加
  Future<int> insertClub({required String name}) =>
      _clubDao.insertClub(name: name);

  /// すべての所属チームを取得
  Future<List<Map<String, dynamic>>> getAllClubsMaster() =>
      _clubDao.getAllClubsMaster();

  /// IDで所属チームを取得
  Future<Map<String, dynamic>?> getClub(int id) => _clubDao.getClub(id);

  /// 所属チームを更新
  Future<int> updateClub({required int id, required String name}) =>
      _clubDao.updateClub(id: id, name: name);

  /// 所属チームを削除
  Future<int> deleteClub(int id) => _clubDao.deleteClub(id);

  // ============================================================================
  // ポイント詳細 CRUD操作
  // ============================================================================

  /// ポイント詳細を挿入
  Future<int> insertPointDetail(PointDetail pointDetail) =>
      _pointDetailDao.insertPointDetail(pointDetail);

  /// 指定したマッチのポイント詳細を全て取得
  Future<List<PointDetail>> getPointDetailsByMatchId(int matchId) =>
      _pointDetailDao.getPointDetailsByMatchId(matchId);

  /// 指定したマッチ・ゲームのポイント詳細を取得
  Future<List<PointDetail>> getPointDetailsByGameNumber(int matchId, int gameNumber) =>
      _pointDetailDao.getPointDetailsByGameNumber(matchId, gameNumber);

  /// ポイント詳細を更新
  Future<int> updatePointDetail(PointDetail pointDetail) =>
      _pointDetailDao.updatePointDetail(pointDetail);

  /// ポイント詳細を削除
  Future<int> deletePointDetail(int id) => _pointDetailDao.deletePointDetail(id);

  /// 指定したマッチの最後のポイント詳細を削除（Undo用）
  Future<int> deleteLastPointDetail(int matchId) =>
      _pointDetailDao.deleteLastPointDetail(matchId);

  /// 指定したマッチにポイント詳細が存在するか確認
  Future<bool> hasPointDetails(int matchId) =>
      _pointDetailDao.hasPointDetails(matchId);

  /// point_detailsの選手名を一括更新
  ///
  /// 試合設定で選手名を変更した際に、その試合のpoint_detailsも更新します。
  /// [matchId] マッチID
  /// [oldName] 変更前の選手名
  /// [newName] 変更後の選手名
  Future<void> updatePlayerNameInPointDetails(int matchId, String oldName, String newName) =>
      _pointDetailDao.updatePlayerNameInPointDetails(matchId, oldName, newName);

  /// データベース接続を閉じる
  ///
  /// アプリ終了時などに呼び出します。
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
