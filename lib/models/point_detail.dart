/// ポイント詳細モデル
/// 
/// ソフトテニスのポイントごとの詳細情報を表すデータモデルです。
/// 詳細入力モードで使用され、1stサーブ成功率・得点率、
/// レシーブミス率、ウィナー/アンフォーストエラーなどの統計に使用します。
class PointDetail {
  /// データベース上の主キー（自動生成）
  final int? id;

  /// 関連するマッチ（試合）のID
  final int matchId;

  /// ゲーム番号
  final int gameNumber;

  /// ゲーム内のポイント番号（1, 2, 3...）
  final int pointNumber;

  /// サーブ側チーム
  /// 'team1': チーム1がサーブ
  /// 'team2': チーム2がサーブ
  final String serverTeam;

  /// サーブを打った選手名
  /// 例: "山田", "佐藤"
  /// null: 未設定（旧データなど）
  final String? serverPlayer;

  /// 1stサーブが入ったかどうか
  /// true: 1stサーブが入った
  /// false: 1stサーブが入らなかった（2ndサーブへ）
  final bool firstServeIn;

  /// ポイント獲得チーム
  /// 'team1': チーム1がポイント獲得
  /// 'team2': チーム2がポイント獲得
  final String pointWinner;

  /// ポイントの種類
  /// 'winner': ウィナー（攻めて決めた）
  /// 'opponent_error': 相手のミス（アンフォーストエラー）
  /// 'ace': サービスエース
  final String pointType;

  /// アクションを起こした選手名（ウィナーを決めた人、ミスした人など）
  final String? actionPlayer;

  /// ミスの種類（'net'=ネット, 'out'=アウト, 'double_fault'=ダブルフォルト）
  /// pointType が 'opponent_error' のときだけ意味を持つ。null: 未入力
  final String? errorType;

  /// ショットの種類（'forehand'=フォアハンド, 'backhand'=バックハンド,
  /// 'volley'=ボレー, 'smash'=スマッシュ, 'lob'=ロブ, 'twist'=ツイスト,
  /// 'serve'=サーブ, 'receive'=レシーブ）
  /// ウィナー・ミスどちらでも使う（何のショットで決まった/崩れたか）。null: 未入力
  final String? shotType;

  /// 打球のコース（'straight_left'=左ストレート, 'straight_right'=右ストレート,
  /// 'cross'=クロス, 'reverse_cross'=逆クロス）
  ///
  /// 打った人から見た方向で記録します。陣形（雁行陣・ダブル前衛・ダブル後衛）に
  /// 依存しないので、どの陣形でも同じ意味になります。null: 未入力
  final String? courseType;

  /// 作成日時
  final DateTime createdAt;

  PointDetail({
    this.id,
    required this.matchId,
    required this.gameNumber,
    required this.pointNumber,
    required this.serverTeam,
    this.serverPlayer,
    required this.firstServeIn,
    required this.pointWinner,
    required this.pointType,
    this.actionPlayer,
    this.errorType,
    this.shotType,
    this.courseType,
    required this.createdAt,
  });

  /// データベース保存用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'match_id': matchId,
      'game_number': gameNumber,
      'point_number': pointNumber,
      'server_team': serverTeam,
      'server_player': serverPlayer,
      'first_serve_in': firstServeIn ? 1 : 0,
      'point_winner': pointWinner,
      'point_type': pointType,
      'action_player': actionPlayer,
      'error_type': errorType,
      'shot_type': shotType,
      'course_type': courseType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// データベースから取得したMapからPointDetailオブジェクトを生成
  factory PointDetail.fromMap(Map<String, dynamic> map) {
    return PointDetail(
      id: map['id'] as int?,
      matchId: map['match_id'] as int,
      gameNumber: map['game_number'] as int,
      pointNumber: map['point_number'] as int,
      serverTeam: map['server_team'] as String,
      serverPlayer: map['server_player'] as String?,
      firstServeIn: (map['first_serve_in'] as int) == 1,
      pointWinner: map['point_winner'] as String,
      pointType: map['point_type'] as String,
      actionPlayer: map['action_player'] as String?,
      errorType: map['error_type'] as String?,
      shotType: map['shot_type'] as String?,
      courseType: map['course_type'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// サーブ側がポイントを取ったかどうか
  bool get serverWon => serverTeam == pointWinner;

  /// レシーブ側がポイントを取ったかどうか
  bool get receiverWon => serverTeam != pointWinner;

  /// レシーブ側チームを取得
  String get receiverTeam => serverTeam == 'team1' ? 'team2' : 'team1';

  /// ポイント種類の日本語表示
  String get pointTypeDisplay {
    switch (pointType) {
      case 'winner':
        return 'ウィナー';
      case 'opponent_error':
        return '相手のミス';
      case 'ace':
        return 'サービスエース';
      default:
        return pointType;
    }
  }

  /// コピーを作成（一部フィールドを変更可能）
  PointDetail copyWith({
    int? id,
    int? matchId,
    int? gameNumber,
    int? pointNumber,
    String? serverTeam,
    String? serverPlayer,
    bool? firstServeIn,
    String? pointWinner,
    String? pointType,
    String? actionPlayer,
    String? errorType,
    String? shotType,
    String? courseType,
    DateTime? createdAt,
  }) {
    return PointDetail(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      gameNumber: gameNumber ?? this.gameNumber,
      pointNumber: pointNumber ?? this.pointNumber,
      serverTeam: serverTeam ?? this.serverTeam,
      serverPlayer: serverPlayer ?? this.serverPlayer,
      firstServeIn: firstServeIn ?? this.firstServeIn,
      pointWinner: pointWinner ?? this.pointWinner,
      pointType: pointType ?? this.pointType,
      actionPlayer: actionPlayer ?? this.actionPlayer,
      errorType: errorType ?? this.errorType,
      shotType: shotType ?? this.shotType,
      courseType: courseType ?? this.courseType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// ポイント種類の定数
class PointType {
  static const String winner = 'winner';
  static const String opponentError = 'opponent_error';

  /// 全てのポイント種類
  static const List<String> all = [
    winner,
    opponentError,
  ];

  /// 日本語表示を取得
  static String getDisplay(String type) {
    switch (type) {
      case winner:
        return 'ウィナー';
      case opponentError:
        return '相手のミス';
      default:
        return type;
    }
  }

  /// 説明を取得
  static String getDescription(String type) {
    switch (type) {
      case winner:
        return '攻めて決めたポイント';
      case opponentError:
        return '相手のエラーで得点';
      default:
        return '';
    }
  }
}

/// ミスの種類の定数（pointType が 'opponent_error' のときに使う）
class ErrorType {
  static const String net = 'net';
  static const String out = 'out';
  static const String doubleFault = 'double_fault';

  /// 全てのミス種類
  static const List<String> all = [net, out, doubleFault];

  /// 日本語表示を取得
  static String getDisplay(String type) {
    switch (type) {
      case net:
        return 'ネット';
      case out:
        return 'アウト';
      case doubleFault:
        return 'ダブルフォルト';
      default:
        return type;
    }
  }
}

/// ショットの種類の定数（ウィナー・ミスどちらにも使う）
class ShotType {
  static const String forehand = 'forehand';
  static const String backhand = 'backhand';
  static const String volley = 'volley';
  static const String smash = 'smash';
  static const String lob = 'lob';
  static const String twist = 'twist';
  static const String serve = 'serve';
  static const String receive = 'receive';

  /// 全てのショット種類
  ///
  /// サーブ・レシーブは同じ場面の表裏なので、入力画面では
  /// サーブ側の選手なら「サーブ」、レシーブ側の選手なら「レシーブ」だけを
  /// 出します（[servingSide] / [receivingSide] を使ってください）。
  static const List<String> all = [
    forehand,
    backhand,
    volley,
    smash,
    lob,
    twist,
    serve,
    receive,
  ];

  /// サーブ側の選手に見せる選択肢
  static const List<String> servingSide = [
    forehand,
    backhand,
    volley,
    smash,
    lob,
    twist,
    serve,
  ];

  /// レシーブ側の選手に見せる選択肢
  static const List<String> receivingSide = [
    forehand,
    backhand,
    volley,
    smash,
    lob,
    twist,
    receive,
  ];

  /// 日本語表示を取得
  static String getDisplay(String type) {
    switch (type) {
      case forehand:
        return 'フォアハンド';
      case backhand:
        return 'バックハンド';
      case volley:
        return 'ボレー';
      case smash:
        return 'スマッシュ';
      case lob:
        return 'ロブ';
      case twist:
        return 'ツイスト';
      case serve:
        return 'サーブ';
      case receive:
        return 'レシーブ';
      default:
        return type;
    }
  }
}

/// 打球のコースの定数
///
/// 打った人から見た方向で記録します。陣形（雁行陣・ダブル前衛・ダブル後衛）に
/// 依存しないので、どの陣形でも同じ意味になります。
class CourseType {
  static const String straightLeft = 'straight_left';
  static const String straightRight = 'straight_right';
  static const String cross = 'cross';
  static const String reverseCross = 'reverse_cross';

  /// 全てのコース
  static const List<String> all = [
    straightLeft,
    straightRight,
    cross,
    reverseCross,
  ];

  /// 日本語表示を取得
  static String getDisplay(String type) {
    switch (type) {
      case straightLeft:
        return '左ストレート';
      case straightRight:
        return '右ストレート';
      case cross:
        return 'クロス';
      case reverseCross:
        return '逆クロス';
      default:
        return type;
    }
  }
}
