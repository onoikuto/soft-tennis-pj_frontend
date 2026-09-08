import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soft_tennis_scoring/config/ai_config.dart';
import 'package:soft_tennis_scoring/config/local_ai_config.dart';
import 'package:soft_tennis_scoring/database/database_helper.dart';
import 'package:soft_tennis_scoring/services/insight_engine.dart';
import 'package:soft_tennis_scoring/services/stats_advice.dart';
import 'package:soft_tennis_scoring/services/local_llm.dart';
import 'package:soft_tennis_scoring/services/statistics_calculator.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';

/// AIによる分析コメントの生成・キャッシュを担当するサービス
///
/// 設計の要点は3つあります。
///
/// 1. **生成は試合を保存した直後にバックグラウンドで行う**。統計画面を開いた
///    ときに生成すると、開くたびに待ち時間が入ります。保存直後はユーザーが
///    画面を閉じる時間なので、生成時間を体感させずに済みます。
/// 2. **生成結果はDBに持ち、画面は必ずキャッシュから読む**。統計画面は今まで
///    どおり即座に開きます。生成が間に合っていなければ、既存のルールベース
///    ([InsightEngine]) の文言が出るので、ユーザーは失敗を目にしません。
/// 3. **何を言うかはルールベース（[InsightEngine]）が決め切る**。端末内LLM
///    ([LocalLlm]) の役割は、選ばれたコメントの言い回しを整えることだけです。
///    小さなモデルに数値の判断まで任せると、根拠のない分析が出てしまいます。
///    生成は端末内で完結するため、選手名や成績が外部に送られることはありません。
/// 4. **課金者のみ**。無料ユーザーが増えても端末の処理が増えるだけで、
///    クラウド費用は発生しません。
class AiInsightService {
  AiInsightService._(); // インスタンス化を防ぐ

  /// 通算分析のキャッシュscope
  static const String scopeOverall = 'overall';

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
    final payload = jsonEncode(_toPayload(input));
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// キャッシュ済みのAI分析コメントを取得
  ///
  /// 未生成・古い・非課金・未設定のいずれかならnullを返します。
  /// 呼び出し側は null のときルールベースの分析を表示してください。
  static Future<List<StatsAdviceLine>?> cachedInsights(
    StatsSubject subject,
    InsightInput input,
  ) async {
    if (!LocalAiConfig.isConfigured) return null;
    if (!await _isEntitled()) return null;

    final json = await DatabaseHelper.instance.aiInsights.find(
      scope: scopeOverall,
      subject: _subjectKey(subject),
      statsHash: statsHash(input),
    );
    if (json == null) return null;

    try {
      return _decodeComments(json);
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
    if (!LocalAiConfig.isConfigured) return;

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
    if (!LocalAiConfig.isConfigured) return;

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
    if (!LocalAiConfig.isConfigured) return false;
    if (_generating) return false;
    if (!await _isEntitled()) return false;

    final hash = statsHash(input);
    final subjectKey = _subjectKey(subject);

    // 同じスタッツの結果が既にあるなら生成しない（作り直す必要がない）
    final existing = await DatabaseHelper.instance.aiInsights.find(
      scope: scopeOverall,
      subject: subjectKey,
      statsHash: hash,
    );
    if (existing != null) return false;

    _generating = true;
    try {
      // 何を言うかはルールベースが決め切る。LLMには言い回しだけを頼む。
      // タブ（ペア/学校・クラブ/選手）で見るべきものが違うので、
      // 対象の種別をそのまま渡す。
      final base = StatsAdviceEngine.generate(subject.view, input);
      final comments = <Map<String, String>>[];
      for (final advice in base) {
        final phrased = await _phrase(advice.text);
        comments.add({
          'type': _categoryKey(advice.category),
          'text': phrased ?? advice.text,
        });
      }
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

  /// LLMに与える役割の説明
  ///
  /// 「新しい情報を足さない」ことを最優先で指示します。小さなモデルは
  /// 放っておくと、渡していない数値やもっともらしい理由を作り出します。
  static const String _systemInstruction = 'あなたはソフトテニスの分析コーチです。'
      '渡されたコメントを、選手が読みやすい自然な日本語に整えます。'
      '与えられた事実・数値以外は絶対に書き足さないでください。'
      '出力は120文字以内の1文だけで、前置きも記号も付けないでください。';

  /// 生成結果を表示に使ってよいか確かめる上限（超えたら元の文言に戻す）
  static const int _maxTextLength = 160;

  /// ルールベースのコメントを、端末内LLMで言い回しだけ整える
  ///
  /// 失敗・未設定・タイムアウトのときはnullを返し、呼び出し側は
  /// [Insight.text]（ルールベースの定型文）をそのまま使います。
  static Future<String?> _phrase(String text) async {
    if (!LocalAiConfig.isConfigured) return null;

    try {
      final generated = await LocalLlm.generate(
        '次のコメントを、言い回しだけ整えてください。\n'
        'コメント: $text\n'
        '整えた1文だけを出力してください。',
        systemInstruction: _systemInstruction,
        timeout: LocalAiConfig.reviewTimeout,
        maxTokens: LocalAiConfig.liveMaxTokens,
      );
      return _sanitize(generated);
    } catch (e) {
      debugPrint('AI分析の言い換えに失敗: $e');
      return null;
    }
  }

  /// 小さなモデルが返しがちな前置き・箇条書き・崩れた出力を弾く
  static String? _sanitize(String? generated) {
    if (generated == null) return null;

    var text = generated
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    text = text.replaceAll(RegExp(r'^[-*・>「」\s]+'), '').trim();
    if (text.isEmpty) return null;
    if (text.length > _maxTextLength) return null;
    if (!RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(text)) return null;

    return text;
  }

  /// アドバイスの区分を保存用のキーにする
  static String _categoryKey(StatsAdviceCategory category) =>
      switch (category) {
        StatsAdviceCategory.practice => 'practice',
        StatsAdviceCategory.mental => 'mental',
        StatsAdviceCategory.tactics => 'tactics',
      };


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

  /// スタッツをハッシュ計算用のMapに変換する
  ///
  /// 数値は小数第1位に丸めます。丸めないと、ごく僅かな違いでハッシュが変わり、
  /// 中身がほぼ同じ分析を作り直してしまいます。
  static Map<String, dynamic> _toPayload(InsightInput input) {
    double round1(double v) => (v * 10).roundToDouble() / 10;

    final opponents = <Map<String, dynamic>>[
      for (final o in input.opponents)
        {'label': o.label, 'wins': o.wins, 'losses': o.losses},
    ];

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
        'servers': [
          for (final entry in (stats.serverStats.keys.toList()..sort()))
            {
              'name': entry,
              'total': stats.serverStats[entry]!.total,
              'won': stats.serverStats[entry]!.won,
            },
        ],
      };
    }

    return payload;
  }

  // ============================================================================
  // 受信データの解釈
  // ============================================================================

  /// キャッシュのJSONを表示用の行に戻す
  static List<StatsAdviceLine> _decodeComments(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];

    final lines = <StatsAdviceLine>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final text = (item['text'] as Object?)?.toString() ?? '';
      if (text.isEmpty) continue;

      lines.add(StatsAdviceLine(
        category: switch (item['type']) {
          'practice' => StatsAdviceCategory.practice,
          'mental' => StatsAdviceCategory.mental,
          _ => StatsAdviceCategory.tactics,
        },
        text: text,
      ));
    }
    return lines;
  }
}
