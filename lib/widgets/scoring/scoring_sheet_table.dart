import 'package:flutter/material.dart';
import 'package:soft_tennis_scoring/models/game_score.dart';
import 'package:soft_tennis_scoring/models/match.dart';
import 'package:soft_tennis_scoring/models/point_detail.dart';

/// 日本ソフトテニス連盟の公式採点票を再現したスコアシート
///
/// 公式の「ダブルス・シングルス採点票」と同じ構造です:
/// - 上部に両ペアの所属・プレーヤー名、中央に試合のゲームカウント（スコア）
/// - 各ゲームは1行。左ペア・右ペアが左右に向かい合う
/// - 各ポイントは各ペアの視点で ○（取得）／✕（失点）のマークで記録
/// - 行頭の S／R はそのゲームのサーブ側／レシーブ側（丸囲み）
/// - 中央の列に各ゲームの得点（勝者側を丸囲み）
///
/// デュースが続いてマークが1行に収まらない場合は、そのゲームの行内で
/// マークを折り返して表示します（行の高さが伸び、横幅は変わりません）。
///
/// この採点表は表示専用です。ポイントの入力は採点画面下部のボタンから行います。
///
/// ポイントの時系列データ（PointDetail）が存在しないゲーム
/// （旧バージョンで記録された試合など）は、中央の得点のみを表示します。
class ScoringSheetTable extends StatelessWidget {
  final Match match;
  final List<GameScore> gameScores;
  final List<PointDetail> pointDetails;

  /// 現在進行中のゲーム番号
  final int currentGame;

  final bool isMatchCompleted;

  /// 指定したゲーム番号がファイナルゲームかどうかを判定するコールバック
  final bool Function(int gameNumber) isFinalGame;

  const ScoringSheetTable({
    super.key,
    required this.match,
    required this.gameScores,
    required this.pointDetails,
    required this.currentGame,
    required this.isMatchCompleted,
    required this.isFinalGame,
  });

  static const double _srColWidth = 16;
  static const double _centerColWidth = 60;
  static const double _minRowHeight = 34;
  static const double _markHeight = 20;

  /// 1行に並べるマークの基準数（これを超えた分は折り返す）
  static const int _marksPerLine = 7;

  static const Color _ink = Color(0xFF333333);
  static const Color _inkLight = Color(0xFF7F7F7F);
  static const Color _inkFaint = Color(0xFFBBBBBB);
  static const Color _lineLight = Color(0xFFDDDDDD);
  static const Color _currentGameBg = Color(0xFFFDFBF0);

  /// ゲームごとのポイント詳細（pointNumber順）
  Map<int, List<PointDetail>> get _pointsByGame {
    final map = <int, List<PointDetail>>{};
    for (var point in pointDetails) {
      map.putIfAbsent(point.gameNumber, () => []).add(point);
    }
    for (var points in map.values) {
      points.sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    }
    return map;
  }

  /// 表示するゲーム行数（マッチ設定のゲーム数と実際の進行のうち大きい方）
  int get _totalGameRows {
    var maxGame = match.gameCount;
    if (currentGame > maxGame) maxGame = currentGame;
    for (var score in gameScores) {
      if (score.gameNumber > maxGame) maxGame = score.gameNumber;
    }
    return maxGame;
  }

  /// ポイント時系列と合計スコアが一致しているか（○✕マークでの表示が可能か）
  bool _isConsistent(GameScore? score, List<PointDetail> points) {
    if (score == null) return true;
    final team1Points = points.where((p) => p.pointWinner == 'team1').length;
    final team2Points = points.where((p) => p.pointWinner == 'team2').length;
    return team1Points == score.team1Score && team2Points == score.team2Score;
  }

  /// 指定ゲームの先サーブチームを取得
  String _serveTeamForGame(int gameNumber, Map<int, GameScore> scoresMap) {
    final score = scoresMap[gameNumber];
    if (score?.serviceTeam != null) return score!.serviceTeam!;

    if (gameNumber == 1) return match.firstServe ?? 'team1';

    // 直前の完了ゲームのサーブ権と逆
    for (var g = gameNumber - 1; g >= 1; g--) {
      final prev = scoresMap[g];
      if (prev != null && prev.winner != null && prev.serviceTeam != null) {
        return prev.serviceTeam == 'team1' ? 'team2' : 'team1';
      }
    }
    return match.firstServe ?? 'team1';
  }

  @override
  Widget build(BuildContext context) {
    final scoresMap = <int, GameScore>{};
    for (var score in gameScores) {
      scoresMap[score.gameNumber] = score;
    }
    final pointsByGame = _pointsByGame;

    // 現在のゲームカウント
    var team1Games = 0;
    var team2Games = 0;
    for (var score in gameScores) {
      if (score.winner == 'team1') {
        team1Games++;
      } else if (score.winner == 'team2') {
        team2Games++;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // マークの幅を画面幅に合わせて決定
        // 1行に _marksPerLine 個並ぶサイズを基準にし、超えた分は折り返す
        const fixedWidth = _srColWidth * 2 + _centerColWidth + 2;
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final available =
            (hasBoundedWidth ? constraints.maxWidth : 390.0) - fixedWidth;
        var markWidth = available / (_marksPerLine * 2);
        markWidth = markWidth.clamp(12.0, 20.0);
        final tableWidth = fixedWidth + markWidth * _marksPerLine * 2;

        return Container(
          width: tableWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _ink),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderBand(team1Games, team2Games),
              for (var g = 1; g <= _totalGameRows; g++)
                _buildGameRow(
                  g,
                  scoresMap,
                  pointsByGame,
                  markWidth,
                  isLast: g == _totalGameRows,
                ),
            ],
          ),
        );
      },
    );
  }

  /// 上部バンド（所属・プレーヤー名・試合のゲームカウント）
  Widget _buildHeaderBand(int team1Games, int team2Games) {
    Widget pairInfo(String club, String player1, String player2,
        {required CrossAxisAlignment align}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            Text(
              club.isEmpty ? '　' : club,
              style: const TextStyle(fontSize: 8, color: _inkLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              player1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              player2,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final matchWinner = isMatchCompleted
        ? (team1Games > team2Games
            ? 'team1'
            : (team2Games > team1Games ? 'team2' : null))
        : null;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ink, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: pairInfo(
              match.team1Club,
              match.team1Player1,
              match.team1Player2,
              align: CrossAxisAlignment.start,
            ),
          ),
          // 試合のゲームカウント（スコア）
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'スコア',
                style: TextStyle(fontSize: 7, color: _inkLight, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _scoreNumber(team1Games,
                      circled: matchWinner == 'team1', large: true),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('-',
                        style: TextStyle(fontSize: 14, color: _ink)),
                  ),
                  _scoreNumber(team2Games,
                      circled: matchWinner == 'team2', large: true),
                ],
              ),
            ],
          ),
          Expanded(
            child: pairInfo(
              match.team2Club,
              match.team2Player1,
              match.team2Player2,
              align: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }

  /// 1ゲーム分の行を構築
  ///
  /// マークが多い場合（デュース続き）は行内で折り返し、行の高さが伸びます。
  Widget _buildGameRow(
    int gameNumber,
    Map<int, GameScore> scoresMap,
    Map<int, List<PointDetail>> pointsByGame,
    double markWidth, {
    required bool isLast,
  }) {
    final score = scoresMap[gameNumber];
    final points = pointsByGame[gameNumber] ?? const <PointDetail>[];
    final isCurrent = gameNumber == currentGame && !isMatchCompleted;
    final isFinal = isFinalGame(gameNumber);
    final consistent = _isConsistent(score, points);
    final started = score != null || isCurrent;
    final serveTeam = started ? _serveTeamForGame(gameNumber, scoresMap) : null;

    // 左右のマーク列（各ペアの視点で ○=取得 / ✕=失点）
    List<Widget> marksFor(String team) {
      if (!consistent) {
        // 旧データなどポイント時系列が使えない場合はマークなし
        return const [];
      }
      final marks = <Widget>[];
      for (var i = 0; i < points.length; i++) {
        final won = points[i].pointWinner == team;
        marks.add(SizedBox(
          width: markWidth,
          height: _markHeight,
          child: Center(
            child: Text(
              won ? '○' : '✕',
              style: TextStyle(
                fontSize: markWidth < 16 ? 10 : 12,
                fontWeight: won ? FontWeight.w600 : FontWeight.normal,
                color: won ? _ink : _inkLight,
              ),
            ),
          ),
        ));
      }
      return marks;
    }

    // サーブ／レシーブ表示（S または R を丸囲み）
    Widget srCell(String team) {
      if (serveTeam == null) return const SizedBox(width: _srColWidth);
      final label = serveTeam == team ? 'S' : 'R';
      return SizedBox(
        width: _srColWidth,
        child: Center(
          child: Container(
            width: 13,
            height: 13,
            alignment: Alignment.center,
            decoration: serveTeam == team
                ? BoxDecoration(
                    border: Border.all(color: _ink, width: 0.8),
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: serveTeam == team ? _ink : _inkFaint,
              ),
            ),
          ),
        ),
      );
    }

    // 左右の半分
    // マークは Wrap で折り返すため、デュースが続いても横幅は崩れない
    Widget half(String team, {required bool isLeft}) {
      final marksWrap = Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          runSpacing: 2,
          children: marksFor(team),
        ),
      );
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: isLeft
                ? [srCell(team), Expanded(child: marksWrap)]
                : [Expanded(child: marksWrap), srCell(team)],
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: _minRowHeight),
      decoration: BoxDecoration(
        color: isCurrent ? _currentGameBg : null,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _lineLight, width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            half('team1', isLeft: true),
            _buildCenterCell(gameNumber, score, points, isCurrent, isFinal),
            half('team2', isLeft: false),
          ],
        ),
      ),
    );
  }

  /// 中央の（スコア）セル
  ///
  /// 完了したゲーム: 得点（勝者側を丸囲み）
  /// 進行中のゲーム: 現在の得点
  /// 未開始のゲーム: ゲーム番号（ファイナルゲームは F）
  Widget _buildCenterCell(
    int gameNumber,
    GameScore? score,
    List<PointDetail> points,
    bool isCurrent,
    bool isFinal,
  ) {
    Widget child;
    if (score != null && score.winner != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scoreNumber(score.team1Score, circled: score.winner == 'team1'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text('-', style: TextStyle(fontSize: 11, color: _ink)),
          ),
          _scoreNumber(score.team2Score, circled: score.winner == 'team2'),
        ],
      );
    } else if (score != null || (isCurrent && points.isNotEmpty)) {
      // 進行中: 現在の得点
      child = Text(
        '${score?.team1Score ?? 0} - ${score?.team2Score ?? 0}',
        style: const TextStyle(fontSize: 11, color: _inkLight),
      );
    } else {
      // 未開始: ゲーム番号
      child = Text(
        isFinal ? 'F' : '$gameNumber',
        style: TextStyle(
          fontSize: 9,
          color: isCurrent ? _ink : _inkFaint,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return Container(
      width: _centerColWidth,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: _ink, width: 0.5),
          right: BorderSide(color: _ink, width: 0.5),
        ),
      ),
      child: child,
    );
  }

  /// 得点の数字（勝者側は丸囲み）
  Widget _scoreNumber(int number, {required bool circled, bool large = false}) {
    final size = large ? 18.0 : 16.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: circled
          ? BoxDecoration(
              border: Border.all(color: _ink, width: 1.2),
              shape: BoxShape.circle,
            )
          : null,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: large ? 13 : 11,
          fontWeight: circled ? FontWeight.bold : FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }
}
