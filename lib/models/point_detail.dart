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

  /// 作成日時
  final DateTime createdAt;

  PointDetail({
    this.id,
    required this.matchId,
    required this.gameNumber,
    required this.pointNumber,
    required this.serverTeam,
    required this.firstServeIn,
    required this.pointWinner,
    required this.pointType,
    this.actionPlayer,
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
      'first_serve_in': firstServeIn ? 1 : 0,
      'point_winner': pointWinner,
      'point_type': pointType,
      'action_player': actionPlayer,
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
      firstServeIn: (map['first_serve_in'] as int) == 1,
      pointWinner: map['point_winner'] as String,
      pointType: map['point_type'] as String,
      actionPlayer: map['action_player'] as String?,
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
    bool? firstServeIn,
    String? pointWinner,
    String? pointType,
    String? actionPlayer,
    DateTime? createdAt,
  }) {
    return PointDetail(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      gameNumber: gameNumber ?? this.gameNumber,
      pointNumber: pointNumber ?? this.pointNumber,
      serverTeam: serverTeam ?? this.serverTeam,
      firstServeIn: firstServeIn ?? this.firstServeIn,
      pointWinner: pointWinner ?? this.pointWinner,
      pointType: pointType ?? this.pointType,
      actionPlayer: actionPlayer ?? this.actionPlayer,
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
