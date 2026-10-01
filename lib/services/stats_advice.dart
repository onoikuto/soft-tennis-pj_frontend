import 'package:soft_tennis_scoring/models/point_detail.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';

/// アドバイスの区分
enum StatsAdviceCategory {
  /// 練習で埋められること
  practice,

  /// competitive な場面の勝ち負け（いわゆるメンタル面）
  mental,

  /// 組み立て・相手との相性
  tactics,
}

/// 統計画面に出すアドバイス1件
class StatsAdvice {
  final StatsAdviceCategory category;

  /// 根拠となる事実（数字）
  final String fact;

  /// そこから言える打ち手
  final String action;

  final int priority;

  const StatsAdvice({
    required this.category,
    required this.fact,
    required this.action,
    required this.priority,
  });

  String get text => '$fact$action';

  StatsAdviceLine toLine() => StatsAdviceLine(category: category, text: text);
}

/// 区分の日本語表示
String statsAdviceCategoryLabel(StatsAdviceCategory category) =>
    switch (category) {
      StatsAdviceCategory.practice => '練習',
      StatsAdviceCategory.mental => 'メンタル',
      StatsAdviceCategory.tactics => '組み立て',
    };

/// 画面に出す1行（キャッシュから戻したものを含む）
class StatsAdviceLine {
  final StatsAdviceCategory category;
  final String text;

  const StatsAdviceLine({required this.category, required this.text});
}

/// 統計画面のタブごとにアドバイスを組み立てる
///
/// **試合中の表示とは狙いが違います。** 試合中は事実の指摘だけにしますが、
/// ここは腰を据えて見る画面なので、「次に何をするか」まで出します。
/// ただし打ち手は数字から機械的に選び、LLMには言い回しだけを任せます。
/// 1.5B級に自由に考えさせると、渡していない前提で練習メニューを作り出します。
///
/// タブ（ペア単位／学校・クラブ単位／選手単位）で見るべきものが違うので、
/// 出す内容も変えます。
class StatsAdviceEngine {
  StatsAdviceEngine._(); // インスタンス化を防ぐ

  /// ペア単位
  static const int viewPair = 0;

  /// 学校・クラブ単位
  static const int viewClub = 1;

  /// 選手単位
  static const int viewPlayer = 2;

  /// アドバイスを優先度順に返す
  static List<StatsAdvice> generate(
    int view,
    InsightInput input, {
    int maxCount = 5,
  }) {
    final advices = <StatsAdvice>[];

    _addMental(input, advices);
    _addPractice(input, advices);

    switch (view) {
      case viewClub:
        _addClub(input, advices);
        break;
      case viewPlayer:
        _addPlayer(input, advices);
        break;
      default:
        _addPair(input, advices);
    }

    advices.sort((a, b) => b.priority.compareTo(a.priority));
    return advices.length > maxCount ? advices.sublist(0, maxCount) : advices;
  }

  // ============================================================================
  // 競り合いの場面（メンタル面）
  //
  // 「気持ちで負けている」は数字にしないと確かめようがありません。ここでは
  // **競った場面だけを切り出した勝率**で見ます。通常の場面と競った場面で
  // 差が出ているなら、技術ではなく競り合いの問題として扱えます。
  // ============================================================================

  static void _addMental(InsightInput input, List<StatsAdvice> out) {
    if (input.deuceTotal >= 10 && input.deuceWinRate < 40) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.mental,
        fact: 'デュースでの取得率が${input.deuceWinRate.round()}%'
            '（${input.deuceTotal}回）。',
        action: '競り合いで先に崩れています。'
            '練習でも3-3から始めるゲームを混ぜて、その状況に慣れてください。',
        priority: 90,
      ));
    }

    if (input.finalGameTotal >= 5 && input.finalGameWinRate < 40) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.mental,
        fact: 'ファイナルゲームの勝率が${input.finalGameWinRate.round()}%'
            '（${input.finalGameTotal}回）。',
        action: '最後まで持たない試合が続いています。'
            'ファイナルだけを繰り返す形式の練習が効きます。',
        priority: 85,
      ));
    }

    final stats = input.pointStats;
    if (stats == null) return;

    if (stats.afterLossTotal >= 20 && stats.afterLossRate < 40) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.mental,
        fact: '失点直後のポイント取得率が${stats.afterLossRate.round()}%'
            '（${stats.afterLossTotal}本）。',
        action: '1本落とすと続けて落としています。'
            'ポイント間で決めごと（構え直す手順）を1つ作ってください。',
        priority: 80,
      ));
    }

    if (stats.matchCount >= 5 && stats.lossStreak3PerMatch >= 1.5) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.mental,
        fact: '3連続失点が1試合あたり'
            '${stats.lossStreak3PerMatch.toStringAsFixed(1)}回。',
        action: '崩れ出すと止まっていません。'
            '2本続けて落とした時点で必ず間を取る、と決めておくのが有効です。',
        priority: 70,
      ));
    }

    if (stats.gamePointTotal >= 10 && stats.gamePointRate < 50) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.mental,
        fact: 'ゲームポイントからの決定率が${stats.gamePointRate.round()}%'
            '（${stats.gamePointTotal}回）。',
        action: 'あと1本が取り切れていません。'
            'その場面で何を打つかを決めておくと、迷いが減ります。',
        priority: 65,
      ));
    }
  }

  // ============================================================================
  // 練習で埋められること
  // ============================================================================

  static void _addPractice(InsightInput input, List<StatsAdvice> out) {
    // ポイント詳細があることと、本人のサーブが記録されていることは別です。
    // 本数で見ないと、一度もサーブを打っていない人に「成功率0%」と言ってしまいます。
    if (input.hasPointDetails &&
        input.firstServeTotal >= 20 &&
        input.firstServeInRate < 60) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.practice,
        fact: '1stサーブの成功率が${input.firstServeInRate.round()}%。',
        action: '確率がそのまま失点につながっています。'
            '入る強さを見つける練習（10本連続で入るまで続ける等）を入れてください。',
        priority: 75,
      ));
    }

    // ゲーム数で材料の有無を見ます。取得率そのものを条件にすると、
    // サーブ側を全部落としている（0%）一番ひどい状態が抜け落ちます。
    // 逆に試合数で見ると、ゲーム単位の記録が無い試合でも0%と断定してしまいます。
    if (input.serviceTotal >= 10 && input.serviceWinRate < 45) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.practice,
        fact: 'サーブ側でのゲーム取得率が${input.serviceWinRate.round()}%。',
        action: 'サーブ権のあるゲームを落としています。'
            'サーブから3球目までを固定した形で反復してください。',
        priority: 60,
      ));
    }

    if (input.receiveTotal >= 10 && input.receiveWinRate < 35) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.practice,
        fact: 'レシーブ側でのゲーム取得率が${input.receiveWinRate.round()}%。',
        action: 'ブレイクできていません。'
            'レシーブの返球コースを2つに絞って練習すると安定します。',
        priority: 55,
      ));
    }

    final stats = input.pointStats;
    if (stats == null) return;

    final topError = AdvancedPointStats.topOf(stats.errorShots);
    if (topError != null &&
        stats.errorShotTotal >= 10 &&
        topError.value * 10 >= stats.errorShotTotal * 4) {
      final label = ShotType.getDisplay(topError.key);
      out.add(StatsAdvice(
        category: StatsAdviceCategory.practice,
        fact: 'ミス${stats.errorShotTotal}本のうち${topError.value}本が$label。',
        action: '$labelだけを続ける反復と、'
            '$labelを避ける組み立ての両方を試す価値があります。',
        priority: 72,
      ));
    }
  }

  // ============================================================================
  // タブごとの上乗せ
  // ============================================================================

  /// ペア単位：ふたりの役割の偏り
  static void _addPair(InsightInput input, List<StatsAdvice> out) {
    final stats = input.pointStats;
    if (stats == null) return;

    final errors = _sum(stats.playerErrors);
    final topError = AdvancedPointStats.topOf(stats.playerErrors);
    if (topError != null && errors >= 20 && topError.value * 3 >= errors * 2) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.tactics,
        fact: 'ミス$errors本のうち${topError.value}本が${topError.key}選手。',
        action: 'ペアの一方に負担が寄っています。'
            '球を集められている可能性があるので、陣形と立ち位置を見直してください。',
        priority: 68,
      ));
    }

    final winners = _sum(stats.playerWinners);
    final topWinner = AdvancedPointStats.topOf(stats.playerWinners);
    if (topWinner != null &&
        winners >= 20 &&
        topWinner.value * 3 >= winners * 2) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.tactics,
        fact: 'ウィナー$winners本のうち${topWinner.value}本が${topWinner.key}選手。',
        action: '得点源がはっきりしています。'
            'その形に持ち込む球出しを、練習の型として決めておくと再現できます。',
        priority: 45,
      ));
    }
  }

  /// 学校・クラブ単位：どの相手に勝てていないか
  static void _addClub(InsightInput input, List<StatsAdvice> out) {
    final losing = input.opponents
        .where((o) => o.total >= 3 && o.winRate < 40)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (losing.isNotEmpty) {
      final worst = losing.first;
      out.add(StatsAdvice(
        category: StatsAdviceCategory.tactics,
        fact: '${worst.label}に${worst.wins}勝${worst.losses}敗。',
        action: '苦手が特定の相手に偏っています。'
            'その相手の試合だけを見返して、失点の入り口を洗い出してください。',
        priority: 78,
      ));
    }

    if (input.totalMatches >= 20 && input.winRate >= 60) {
      out.add(StatsAdvice(
        category: StatsAdviceCategory.tactics,
        fact: '通算勝率${input.winRate.round()}%（${input.totalMatches}試合）。',
        action: '団体として安定しています。'
            '格上との練習試合を増やす時期です。',
        priority: 30,
      ));
    }
  }

  /// 選手単位：その選手のサーブ
  static void _addPlayer(InsightInput input, List<StatsAdvice> out) {
    final stats = input.pointStats;
    if (stats == null) return;

    for (final serve in stats.serverStatsList) {
      if (serve.total < 20) continue;
      final rate = (serve.won / serve.total * 100).round();
      if (rate < 45) {
        out.add(StatsAdvice(
          category: StatsAdviceCategory.practice,
          fact: '${serve.player}選手のサーブ時ポイント取得率が$rate%'
              '（${serve.total}本）。',
          action: 'サーブから主導権を取れていません。'
              'コースを2つに絞り、そこだけを反復してください。',
          priority: 74,
        ));
      }
      break;
    }
  }

  static int _sum(Map<String, int> counts) =>
      counts.values.fold(0, (a, b) => a + b);
}
