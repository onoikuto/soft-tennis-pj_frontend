import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';

/// 分析コメントの種類
enum InsightType {
  /// 強み（良い傾向）
  good,

  /// 課題（改善ポイント）
  warning,

  /// 情報・アドバイス
  info,
}

/// 分析コメント1件
class Insight {
  final InsightType type;
  final String text;

  /// 表示優先度（大きいほど先に表示）
  final int priority;

  const Insight({
    required this.type,
    required this.text,
    required this.priority,
  });
}

/// 分析コメント生成の入力データ
///
/// 統計画面で計算済みの値をまとめて渡します。
class InsightInput {
  final int totalMatches;
  final double winRate;

  /// 直近の勝敗（古い試合から順）
  final List<bool> recentResults;

  /// サーブ側/レシーブ側のゲーム取得率
  final double serviceWinRate;
  final double receiveWinRate;

  /// その取得率の母数（ゲーム数）
  ///
  /// 取得率は母数0のとき0%として返るので、率だけでは「全部落とした」と
  /// 「そもそも記録が無い」を区別できません。判定には必ずこちらを使います。
  /// 渡し漏れたときは何も言わない側に倒すため、既定値は0にしてあります。
  final int serviceTotal;
  final int receiveTotal;

  final double deuceWinRate;
  final int deuceTotal;

  final double finalGameWinRate;
  final int finalGameTotal;

  /// ポイント詳細データがあるか（分析+で記録された試合）
  final bool hasPointDetails;
  final double firstServeInRate;

  /// 1stサーブ成功率の母数（本人が打ったサーブの本数）
  ///
  /// ポイント詳細があっても、個人単位では本人がサーブを打っていない試合が
  /// ありえます。そのとき成功率は0%として返るので、判定にはこちらを使います。
  final int firstServeTotal;
  final AdvancedPointStats? pointStats;

  final List<OpponentRecord> opponents;

  const InsightInput({
    required this.totalMatches,
    required this.winRate,
    required this.recentResults,
    required this.serviceWinRate,
    required this.receiveWinRate,
    this.serviceTotal = 0,
    this.receiveTotal = 0,
    required this.deuceWinRate,
    required this.deuceTotal,
    required this.finalGameWinRate,
    required this.finalGameTotal,
    required this.hasPointDetails,
    required this.firstServeInRate,
    this.firstServeTotal = 0,
    required this.pointStats,
    required this.opponents,
  });
}

/// 統計データからルールベースで分析コメント（定型文）を生成するエンジン
///
/// LLM等の外部APIは使わず、条件→文言のルールをローカルで評価します。
/// サンプル数が少ない指標はコメントを出さないことで、誤解を招く分析を避けます。
class InsightEngine {
  InsightEngine._(); // インスタンス化を防ぐ

  /// 分析コメントを生成（優先度順・最大 [maxComments] 件）
  static List<Insight> generate(InsightInput input, {int maxComments = 5}) {
    final insights = <Insight>[];

    _addFormInsights(input, insights);
    _addServeReceiveInsights(input, insights);
    _addClutchInsights(input, insights);
    _addPointDetailInsights(input, insights);
    _addShotInsights(input, insights);
    _addOpponentInsights(input, insights);

    if (insights.isEmpty) {
      insights.add(const Insight(
        type: InsightType.info,
        text: '試合数がまだ少ないため、分析できる項目が限られています。試合を記録するほど分析の精度が上がります。',
        priority: 0,
      ));
    }

    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return insights.length > maxComments
        ? insights.sublist(0, maxComments)
        : insights;
  }

  /// 調子（直近の勝敗）に関するコメント
  static void _addFormInsights(InsightInput input, List<Insight> insights) {
    if (input.recentResults.length >= 5) {
      final recent5 = input.recentResults
          .sublist(input.recentResults.length - 5)
          .where((won) => won)
          .length;
      if (recent5 >= 4) {
        insights.add(Insight(
          type: InsightType.good,
          text: '直近5試合で$recent5勝と好調です。今の戦い方を継続しつつ、勝ち試合の共通点を意識してみましょう。',
          priority: 70,
        ));
      } else if (recent5 <= 1) {
        insights.add(Insight(
          type: InsightType.warning,
          text: '直近5試合で$recent5勝と調子を落としています。連敗中は戦術を大きく変えるより、サーブとレシーブの基本の確率を整えるのが近道です。',
          priority: 80,
        ));
      }
    }

    if (input.totalMatches >= 10 && input.winRate >= 70) {
      insights.add(Insight(
        type: InsightType.good,
        text: '通算勝率${input.winRate.toStringAsFixed(0)}%と安定して勝てています。格上相手の試合を増やすと、さらに伸びる時期です。',
        priority: 40,
      ));
    }
  }

  /// サーブ・レシーブのバランスに関するコメント
  static void _addServeReceiveInsights(InsightInput input, List<Insight> insights) {
    if (input.totalMatches < 5) return;
    // 片方でも母数が無ければ、差は0%との比較になってしまう
    if (input.serviceTotal < 10 || input.receiveTotal < 10) return;

    final gap = input.serviceWinRate - input.receiveWinRate;
    if (gap >= 15) {
      insights.add(Insight(
        type: InsightType.warning,
        text: 'サーブ時のゲーム取得率(${input.serviceWinRate.toStringAsFixed(0)}%)に比べて、レシーブ時(${input.receiveWinRate.toStringAsFixed(0)}%)が低めです。相手の2ndサーブを積極的に攻めてブレークの機会を増やしましょう。',
        priority: 60,
      ));
    } else if (gap <= -15) {
      insights.add(Insight(
        type: InsightType.warning,
        text: 'レシーブ時のゲーム取得率(${input.receiveWinRate.toStringAsFixed(0)}%)に比べて、サーブ時(${input.serviceWinRate.toStringAsFixed(0)}%)が低めです。サービスゲームのキープ率を上げることが勝率アップに直結します。',
        priority: 60,
      ));
    }
  }

  /// 競り合い（デュース・ファイナルゲーム）に関するコメント
  static void _addClutchInsights(InsightInput input, List<Insight> insights) {
    if (input.deuceTotal >= 5) {
      if (input.deuceWinRate >= 60) {
        insights.add(Insight(
          type: InsightType.good,
          text: 'デュースの取得率が${input.deuceWinRate.toStringAsFixed(0)}%と、競り合いに強いのが持ち味です。',
          priority: 30,
        ));
      } else if (input.deuceWinRate <= 40) {
        insights.add(Insight(
          type: InsightType.warning,
          text: 'デュースの取得率が${input.deuceWinRate.toStringAsFixed(0)}%と低めです。デュースでは最初の1本の入り方（配球を決めておく）が効きます。',
          priority: 50,
        ));
      }
    }

    if (input.finalGameTotal >= 3) {
      if (input.finalGameWinRate >= 60) {
        insights.add(Insight(
          type: InsightType.good,
          text: 'ファイナルゲームの勝率が${input.finalGameWinRate.toStringAsFixed(0)}%。接戦の最終盤で力を発揮できています。',
          priority: 30,
        ));
      } else if (input.finalGameWinRate <= 40) {
        insights.add(Insight(
          type: InsightType.warning,
          text: 'ファイナルゲームの勝率が${input.finalGameWinRate.toStringAsFixed(0)}%と苦手傾向です。ファイナルはサーブ順の作戦（誰から打つか）を事前に決めておきましょう。',
          priority: 50,
        ));
      }
    }
  }

  /// ポイント詳細データ（分析+）に基づくコメント
  static void _addPointDetailInsights(InsightInput input, List<Insight> insights) {
    final stats = input.pointStats;
    if (!input.hasPointDetails || stats == null) return;

    // 1stサーブ成功率
    // 母数は本人（個人タブ）のサーブ本数で見ます。ポイント詳細の集計は
    // チーム単位なので、そちらを条件にすると本人が一度も打っていなくても
    // 「成功率0%」と断定してしまいます。
    if (input.firstServeTotal >= 20 && input.firstServeInRate < 60) {
      insights.add(Insight(
        type: InsightType.warning,
        text: '1stサーブの成功率が${input.firstServeInRate.toStringAsFixed(0)}%と低めです。まずは8割の力で確実に入れて、2ndサーブの場面自体を減らしましょう。',
        priority: 65,
      ));
    }

    // 1st vs 2nd サーブの得点率差
    if (stats.firstServePointTotal >= 30 && stats.secondServePointTotal >= 15) {
      final gap = stats.firstServePointRate - stats.secondServePointRate;
      if (gap >= 20) {
        insights.add(Insight(
          type: InsightType.warning,
          text: '1stサーブ時の得点率(${stats.firstServePointRate.toStringAsFixed(0)}%)と2ndサーブ時(${stats.secondServePointRate.toStringAsFixed(0)}%)の差が${gap.toStringAsFixed(0)}ポイントあります。2ndサーブになると失点しやすいので、1stの確率か2ndの質のどちらかを強化しましょう。',
          priority: 55,
        ));
      }
    }

    // 選手別サーブ（狙われている選手）
    final servers = stats.serverStatsList.where((s) => s.total >= 20).toList();
    if (servers.length >= 2) {
      servers.sort((a, b) => a.rate.compareTo(b.rate));
      final weakest = servers.first;
      final strongest = servers.last;
      if (strongest.rate - weakest.rate >= 15) {
        insights.add(Insight(
          type: InsightType.warning,
          text: '${weakest.player}選手のサーブ時得点率(${weakest.rate.toStringAsFixed(0)}%)が${strongest.player}選手(${strongest.rate.toStringAsFixed(0)}%)より大きく低く、相手に狙われている可能性があります。サーブの配球やサーブ後のポジションを見直しましょう。',
          priority: 55,
        ));
      }
    }

    // ゲームポイントの決定率
    if (stats.gamePointTotal >= 10) {
      if (stats.gamePointRate <= 50) {
        insights.add(Insight(
          type: InsightType.warning,
          text: 'ゲームポイントでの決定率が${stats.gamePointRate.toStringAsFixed(0)}%です。あと1本の場面で攻め急ぐ傾向がないか振り返り、決めパターンを1つ用意しておきましょう。',
          priority: 55,
        ));
      } else if (stats.gamePointRate >= 70) {
        insights.add(Insight(
          type: InsightType.good,
          text: 'ゲームポイントの決定率が${stats.gamePointRate.toStringAsFixed(0)}%と高く、チャンスを確実にものにできています。',
          priority: 30,
        ));
      }
    }

    // 連続失点（流れを渡しやすい）
    if (stats.matchCount >= 3 && stats.lossStreak3PerMatch >= 2.0) {
      insights.add(Insight(
        type: InsightType.warning,
        text: '1試合あたり平均${stats.lossStreak3PerMatch.toStringAsFixed(1)}回、3連続以上の失点が発生しています。2連続で失点したら一度間を取って、流れを切る習慣をつけましょう。',
        priority: 45,
      ));
    }

    // 失点直後の切り替え力
    if (stats.afterLossTotal >= 30 && stats.overallPointTotal >= 60) {
      final gap = stats.overallPointRate - stats.afterLossRate;
      if (gap >= 10) {
        insights.add(Insight(
          type: InsightType.warning,
          text: '失点直後のポイント取得率(${stats.afterLossRate.toStringAsFixed(0)}%)が全体(${stats.overallPointRate.toStringAsFixed(0)}%)より${gap.toStringAsFixed(0)}ポイント低く、ミスを引きずる傾向があります。失点後こそ確率の高いプレーを選びましょう。',
          priority: 45,
        ));
      } else if (gap <= -5) {
        insights.add(Insight(
          type: InsightType.good,
          text: '失点直後のポイント取得率(${stats.afterLossRate.toStringAsFixed(0)}%)が全体平均を上回っており、切り替えの早さが強みです。',
          priority: 25,
        ));
      }
    }
  }

  /// 球種・コース・ミスの種類に関するコメント
  ///
  /// どれも分析+の任意入力なので、**入力済みの本数だけ**を母数にします。
  /// 入力をスキップしたぶんを0として扱うと、傾向が薄まって読めなくなります。
  static void _addShotInsights(InsightInput input, List<Insight> insights) {
    final stats = input.pointStats;
    if (!input.hasPointDetails || stats == null) return;

    // 決まっている球種
    final winnerShot = AdvancedPointStats.topOf(stats.winnerShots);
    if (winnerShot != null && stats.winnerShotTotal >= 10) {
      final percent = (winnerShot.value / stats.winnerShotTotal * 100).round();
      insights.add(Insight(
        type: InsightType.good,
        text: 'ウィナー${stats.winnerShotTotal}本のうち${winnerShot.value}本（$percent%）が'
            '${ShotType.getDisplay(winnerShot.key)}です。',
        priority: 55,
      ));
    }

    // 崩れている球種
    final errorShot = AdvancedPointStats.topOf(stats.errorShots);
    if (errorShot != null && stats.errorShotTotal >= 10) {
      final percent = (errorShot.value / stats.errorShotTotal * 100).round();
      insights.add(Insight(
        type: InsightType.warning,
        text: 'ミス${stats.errorShotTotal}本のうち${errorShot.value}本（$percent%）が'
            '${ShotType.getDisplay(errorShot.key)}です。',
        priority: 75,
      ));
    }

    // 得点しやすい展開・失点しやすい展開
    final winnerCourse = AdvancedPointStats.topOf(stats.winnerCourses);
    if (winnerCourse != null && _sum(stats.winnerCourses) >= 10) {
      insights.add(Insight(
        type: InsightType.good,
        text: '${CourseType.getDisplay(winnerCourse.key)}展開での得点が'
            '${winnerCourse.value}本と最も多いです。',
        priority: 50,
      ));
    }

    final errorCourse = AdvancedPointStats.topOf(stats.errorCourses);
    if (errorCourse != null && _sum(stats.errorCourses) >= 10) {
      insights.add(Insight(
        type: InsightType.warning,
        text: '${CourseType.getDisplay(errorCourse.key)}展開での失点が'
            '${errorCourse.value}本と最も多いです。',
        priority: 60,
      ));
    }

    // 選手別（ダブルスなので、どちらの傾向かが分かると打ち手が変わる）
    final topErrorPlayer = AdvancedPointStats.topOf(stats.playerErrors);
    final errorPlayerTotal = _sum(stats.playerErrors);
    if (topErrorPlayer != null &&
        errorPlayerTotal >= 12 &&
        topErrorPlayer.value * 3 >= errorPlayerTotal * 2) {
      insights.add(Insight(
        type: InsightType.info,
        text: 'ミス$errorPlayerTotal本のうち${topErrorPlayer.value}本が'
            '${topErrorPlayer.key}選手のものです。',
        priority: 45,
      ));
    }

    final topWinnerPlayer = AdvancedPointStats.topOf(stats.playerWinners);
    final winnerPlayerTotal = _sum(stats.playerWinners);
    if (topWinnerPlayer != null &&
        winnerPlayerTotal >= 12 &&
        topWinnerPlayer.value * 3 >= winnerPlayerTotal * 2) {
      insights.add(Insight(
        type: InsightType.info,
        text: 'ウィナー$winnerPlayerTotal本のうち${topWinnerPlayer.value}本が'
            '${topWinnerPlayer.key}選手のものです。',
        priority: 35,
      ));
    }
  }

  static int _sum(Map<String, int> counts) =>
      counts.values.fold(0, (a, b) => a + b);

  /// 対戦相手に関するコメント
  static void _addOpponentInsights(InsightInput input, List<Insight> insights) {
    for (var opponent in input.opponents) {
      if (opponent.total >= 3 && opponent.winRate <= 40) {
        insights.add(Insight(
          type: InsightType.info,
          text: '${opponent.label}には${opponent.wins}勝${opponent.losses}敗と苦戦しています。過去の試合の採点表を見返して、失点パターンを確認してみましょう。',
          priority: 35,
        ));
        break; // 最も対戦数の多い苦手相手1組のみ
      }
    }
  }
}
