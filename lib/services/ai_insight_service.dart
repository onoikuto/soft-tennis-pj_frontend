import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soft_tennis_scoring/config/ai_config.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/services/advanced_stats.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';
import 'package:soft_tennis_scoring/services/statistics_calculator.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';

/// AIによる分析コメントの生成・キャッシュを担当するサービス
///
/// 設計の要点は3つあります。
///
/// 1. **生成は試合を保存した直後にバックグラウンドで行う**。統計画面を開いた
///    ときに生成すると、開くたびに待ち時間が入り、レート制限がそのまま画面の
///    エラーになります。保存直後はユーザーが画面を閉じる時間なので、生成時間
///    を体感させずに済みます。
/// 2. **生成結果はDBに持ち、画面は必ずキャッシュから読む**。統計画面は今まで
///    どおり即座に開きます。生成が間に合っていなければ、既存のルールベース
///    ([InsightEngine]) の文言が出るので、ユーザーは失敗を目にしません。
/// 3. **課金者のみ**。呼び出し回数が売上に紐づくため、無料ユーザーが増えても
///    費用は増えません。
class AiInsightService {
  AiInsightService._(); // インスタンス化を防ぐ

  /// 通算分析のキャッシュscope
  static const String scopeOverall = 'overall';

  /// 生成回数の記録に使うSharedPreferencesのキー
  static const String _quotaDateKey = 'ai_insight_quota_date';
  static const String _quotaCountKey = 'ai_insight_quota_count';

  /// 最後に統計画面で見ていた対象を覚えておくキー
  ///
  /// 試合を保存した直後は「どの対象の分析を作り直すか」が分からないため、
  /// 直近に見ていた対象（自分のペアであることがほとんど）を使います。
  static const String _lastSubjectViewKey = 'ai_insight_subject_view';
  static const String _lastSubjectNameKey = 'ai_insight_subject_name';

  /// デバウンス用のタイマー
  ///
  /// 大会の日は1人が1日に何試合も記録します。保存のたびに生成すると
  /// ほぼ同じ文章を作っては捨てることになるため、最後の保存から
  /// [AiConfig.generationDelay] 待ってから1回だけ生成します。
  static Timer? _pendingGeneration;

  /// 二重生成の防止
  static bool _generating = false;

  // ============================================================================
  // 公開API
  // ============================================================================

  /// 生成元スタッツのハッシュ
  ///
  /// このハッシュが一致するキャッシュだけを表示に使うことで、
  /// 画面に出ている数値と食い違う分析が出るのを防ぎます。
  static String statsHash(InsightInput input) {
    final payload = jsonEncode(_toPayload(input, anonymize: false));
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// キャッシュ済みのAI分析コメントを取得
  ///
  /// 未生成・古い・非課金・未設定のいずれかならnullを返します。
  /// 呼び出し側は null のときルールベースの分析を表示してください。
  static Future<List<Insight>?> cachedInsights(
    StatsSubject subject,
    InsightInput input,
  ) async {
    if (!AiConfig.isConfigured) return null;
    if (!await _isEntitled()) return null;

    final json = await DatabaseHelper.instance.aiInsights.find(
      scope: scopeOverall,
      subject: _subjectKey(subject),
      statsHash: statsHash(input),
    );
    if (json == null) return null;

    try {
      return _decodeComments(json, input);
    } catch (e) {
      debugPrint('AI分析の読み込みに失敗（キャッシュを無視）: $e');
      return null;
    }
  }

  /// 統計画面で見ている対象を覚えておく
  ///
  /// 試合を保存した直後は「どの対象の分析を作り直すか」の手がかりが
  /// ないため、直近に見ていた対象を使います。
  static Future<void> rememberSubject(StatsSubject subject) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSubjectViewKey, subject.view);
    await prefs.setString(_lastSubjectNameKey, subject.name);
  }

  /// 直近に統計画面で見ていた対象を取り出す
  ///
  /// 試合中のアドバイスで「どちらのチームが自分か」を決めるのに使います。
  /// 一度も統計画面を開いていない場合はnullです。
  static Future<StatsSubject?> lastViewedSubject() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_lastSubjectNameKey);
    if (name == null || name.isEmpty) return null;
    return StatsSubject(prefs.getInt(_lastSubjectViewKey) ?? 0, name);
  }

  /// 試合を保存した直後に呼ぶ
  ///
  /// 直近に統計画面で見ていた対象の分析を作り直します。統計画面を一度も
  /// 開いていない場合は、作り直す対象が分からないので何もしません
  /// （その場合は次に統計画面を開いたときに予約が入ります）。
  static Future<void> scheduleGenerationAfterMatchSaved() async {
    if (!AiConfig.isConfigured) return;

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_lastSubjectNameKey);
    if (name == null || name.isEmpty) return;
    final view = prefs.getInt(_lastSubjectViewKey) ?? 0;

    scheduleGeneration(StatsSubject(view, name));
  }

  /// 分析コメントの生成を予約する
  ///
  /// すぐには走らず、最後の呼び出しから [AiConfig.generationDelay] 経ってから
  /// 1回だけ生成します。大会の日は1人が1日に何試合も記録するので、保存の
  /// たびに生成するとほぼ同じ文章を作っては捨てることになるためです。
  /// 生成の成否は呼び出し側に返しません（失敗してもルールベースが出るため）。
  static void scheduleGeneration(StatsSubject subject) {
    if (!AiConfig.isConfigured) return;

    _pendingGeneration?.cancel();
    _pendingGeneration = Timer(AiConfig.generationDelay, () async {
      try {
        // 待っている間に試合が追加されている可能性があるので、
        // 生成の直前に集計し直す
        final result = await StatisticsCalculator.calculate(subject);
        await generateNow(subject, result.insightInput);
      } catch (e) {
        // 生成できなくてもアプリの動作には影響しない
        debugPrint('AI分析の生成に失敗: $e');
      }
    });
  }

  /// 予約済みの生成を取り消す
  static void cancelScheduledGeneration() {
    _pendingGeneration?.cancel();
    _pendingGeneration = null;
  }

  /// 分析コメントを生成してキャッシュに保存する
  ///
  /// 生成した場合はtrue、条件を満たさず何もしなかった場合はfalseを返します。
  static Future<bool> generateNow(
    StatsSubject subject,
    InsightInput input,
  ) async {
    if (!AiConfig.isConfigured) return false;
    if (_generating) return false;
    if (!await _isEntitled()) return false;

    final hash = statsHash(input);
    final subjectKey = _subjectKey(subject);

    // 同じスタッツの結果が既にあるなら生成しない（最大の節約はこれ）
    final existing = await DatabaseHelper.instance.aiInsights.find(
      scope: scopeOverall,
      subject: subjectKey,
      statsHash: hash,
    );
    if (existing != null) return false;

    if (!await _consumeDailyQuota()) {
      debugPrint('AI分析の生成をスキップ（本日の上限に到達）');
      return false;
    }

    _generating = true;
    try {
      final anonymized = _toPayload(input, anonymize: true);
      final response = await http
          .post(
            Uri.parse(AiConfig.endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'stats': anonymized}),
          )
          .timeout(AiConfig.requestTimeout);

      if (response.statusCode != 200) {
        // 429（レート制限）を含め、失敗は握りつぶす。
        // 画面にはルールベースの分析が出るので、ユーザーには何も起きない。
        debugPrint('AI分析の生成に失敗: HTTP ${response.statusCode}');
        return false;
      }

      // 生成された本文の妥当性をここで確認しておく（壊れた結果を保存しない）
      final body = utf8.decode(response.bodyBytes);
      final comments = _extractComments(body);
      if (comments.isEmpty) return false;

      await DatabaseHelper.instance.aiInsights.save(
        scope: scopeOverall,
        subject: subjectKey,
        statsHash: hash,
        commentsJson: jsonEncode(comments),
      );
      return true;
    } finally {
      _generating = false;
    }
  }

  /// AI分析を使ってよい状態か（課金しているか）
  ///
  /// 動作確認のときだけ、デバッグビルドに限り課金判定を飛ばせます。
  /// リリースビルドでは [AiConfig.forcePremium] が立っていても無視されます。
  static Future<bool> _isEntitled() async {
    if (kDebugMode && AiConfig.forcePremium) return true;
    return SubscriptionService.isSubscribed();
  }

  /// キャッシュを引くときの対象キー
  ///
  /// ペア・学校・個人で分析の中身が変わるため、対象ごとに別の行に保存します。
  /// これを分けないと、統計画面で対象を切り替えるたびに互いの分析を
  /// 上書きし合ってしまいます。
  static String _subjectKey(StatsSubject subject) =>
      '${subject.view}:${subject.name}';

  // ============================================================================
  // 送信データの組み立て
  // ============================================================================

  /// スタッツを送信用のMapに変換する
  ///
  /// [anonymize] がtrueのとき、選手名・対戦相手名を「選手A」「対戦相手A」に
  /// 置き換えます。**実名を外部APIへ送らないための処理で、必須です。**
  /// 返ってきた文章は [_decodeComments] で実名に戻します。
  ///
  /// 数値は小数第1位に丸めます。丸めないと、ごく僅かな違いでハッシュが変わり、
  /// 中身がほぼ同じ分析を作り直してしまいます。
  static Map<String, dynamic> _toPayload(
    InsightInput input, {
    required bool anonymize,
  }) {
    double round1(double v) => (v * 10).roundToDouble() / 10;

    final opponents = <Map<String, dynamic>>[];
    for (var i = 0; i < input.opponents.length; i++) {
      final o = input.opponents[i];
      opponents.add({
        'label': anonymize ? _opponentAlias(i) : o.label,
        'wins': o.wins,
        'losses': o.losses,
      });
    }

    final payload = <String, dynamic>{
      'totalMatches': input.totalMatches,
      'winRate': round1(input.winRate),
      'recentResults': input.recentResults,
      'serviceWinRate': round1(input.serviceWinRate),
      'receiveWinRate': round1(input.receiveWinRate),
      'deuceWinRate': round1(input.deuceWinRate),
      'deuceTotal': input.deuceTotal,
      'finalGameWinRate': round1(input.finalGameWinRate),
      'finalGameTotal': input.finalGameTotal,
      'hasPointDetails': input.hasPointDetails,
      'firstServeInRate': round1(input.firstServeInRate),
      'opponents': opponents,
    };

    final stats = input.pointStats;
    if (input.hasPointDetails && stats != null) {
      payload['pointStats'] = {
        'matchCount': stats.matchCount,
        'firstServePointTotal': stats.firstServePointTotal,
        'firstServePointWon': stats.firstServePointWon,
        'secondServePointTotal': stats.secondServePointTotal,
        'secondServePointWon': stats.secondServePointWon,
        'overallPointTotal': stats.overallPointTotal,
        'overallPointWon': stats.overallPointWon,
        'afterLossTotal': stats.afterLossTotal,
        'afterLossWon': stats.afterLossWon,
        'lossStreak3Count': stats.lossStreak3Count,
        'gamePointTotal': stats.gamePointTotal,
        'gamePointWon': stats.gamePointWon,
        'servers': _serverStats(stats, anonymize: anonymize),
      };
    }

    return payload;
  }

  /// 選手別サーブ成績（選手名は匿名化の対象）
  static List<Map<String, dynamic>> _serverStats(
    AdvancedPointStats stats, {
    required bool anonymize,
  }) {
    final names = stats.serverStats.keys.toList()..sort();
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < names.length; i++) {
      final stat = stats.serverStats[names[i]];
      if (stat == null) continue;
      result.add({
        'name': anonymize ? _playerAlias(i) : names[i],
        'total': stat.total,
        'won': stat.won,
      });
    }
    return result;
  }

  /// 匿名化に使う対戦相手の呼び名（対戦相手A, B, ...）
  static String _opponentAlias(int index) => '対戦相手${_alphabet(index)}';

  /// 匿名化に使う選手の呼び名（選手A, B, ...）
  static String _playerAlias(int index) => '選手${_alphabet(index)}';

  /// 0→A, 1→B ... 25→Z, 26以降は数字を添える
  static String _alphabet(int index) {
    if (index < 26) return String.fromCharCode(65 + index);
    return '${String.fromCharCode(65 + index % 26)}${index ~/ 26 + 1}';
  }

  // ============================================================================
  // 受信データの解釈
  // ============================================================================

  /// プロキシの応答からコメント配列を取り出す
  ///
  /// 期待する形は `{"comments": [{"type": "good", "text": "..."}]}` です。
  /// 想定外の形・空文字のコメントは捨てます（壊れた分析を保存しないため）。
  static List<Map<String, String>> _extractComments(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final raw = decoded['comments'];
    if (raw is! List) return const [];

    const allowedTypes = {'good', 'warning', 'info'};
    final comments = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final text = (item['text'] as Object?)?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      final type = (item['type'] as Object?)?.toString() ?? 'info';
      comments.add({
        'type': allowedTypes.contains(type) ? type : 'info',
        'text': text,
      });
    }
    return comments;
  }

  /// キャッシュのJSONを[Insight]のリストへ戻す
  ///
  /// 匿名化した呼び名（対戦相手A・選手A）を実名へ復元します。
  static List<Insight> _decodeComments(String json, InsightInput input) {
    final restore = _restoreMap(input);

    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];

    final insights = <Insight>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) continue;
      var text = (item['text'] as Object?)?.toString() ?? '';
      if (text.isEmpty) continue;
      restore.forEach((alias, real) {
        text = text.replaceAll(alias, real);
      });

      insights.add(Insight(
        type: switch (item['type']) {
          'good' => InsightType.good,
          'warning' => InsightType.warning,
          _ => InsightType.info,
        },
        // 生成された順をそのまま表示順にする（AI側に優先度を決めさせる）
        priority: decoded.length - i,
        text: text,
      ));
    }
    return insights;
  }

  /// 匿名の呼び名 → 実名の対応表
  static Map<String, String> _restoreMap(InsightInput input) {
    final map = <String, String>{};
    for (var i = 0; i < input.opponents.length; i++) {
      map[_opponentAlias(i)] = input.opponents[i].label;
    }
    final stats = input.pointStats;
    if (stats != null) {
      final names = stats.serverStats.keys.toList()..sort();
      for (var i = 0; i < names.length; i++) {
        map[_playerAlias(i)] = names[i];
      }
    }
    return map;
  }

  // ============================================================================
  // 1日の生成回数の上限
  // ============================================================================

  /// 本日ぶんの生成枠を1つ使う
  ///
  /// 上限に達していればfalseを返します。不具合や連打で課金が跳ねるのを
  /// 防ぐための安全弁で、サーバー側にも同じ制限を置いてあります。
  static Future<bool> _consumeDailyQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final savedDate = prefs.getString(_quotaDateKey);
    final count = savedDate == today ? (prefs.getInt(_quotaCountKey) ?? 0) : 0;
    if (count >= AiConfig.maxGenerationsPerDay) return false;

    await prefs.setString(_quotaDateKey, today);
    await prefs.setInt(_quotaCountKey, count + 1);
    return true;
  }
}
