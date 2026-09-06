import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'package:soft_tennis_scoring/config/ai_config.dart';
import 'package:soft_tennis_scoring/config/local_ai_config.dart';
import 'package:soft_tennis_scoring/services/live_coach_engine.dart';
import 'package:soft_tennis_scoring/services/local_llm.dart';
import 'package:soft_tennis_scoring/services/subscription_service.dart';

/// 画面に出す試合中アドバイス
class LiveCoachMessage {
  /// 助言の種類（[LiveAdvice.key]と同じ）
  final String key;

  /// 見出し
  final String headline;

  /// 本文
  final String text;

  /// 端末内LLMで言い回しを作ったか（falseなら定型文）
  final bool phrasedByAi;

  const LiveCoachMessage({
    required this.key,
    required this.headline,
    required this.text,
    required this.phrasedByAi,
  });
}

/// 助言を取り直した結果
///
/// 「出す助言がない」と「まだ出し直さない」は分けて扱う必要があります。
/// 前者で表示を消さないと、状況が変わったのに古い助言が画面に残り続けます。
class LiveCoachUpdate {
  /// 新しく表示する助言（nullなら新しいものはない）
  final LiveCoachMessage? message;

  /// いま出ている助言をそのまま残すか
  ///
  /// 間隔を空けている最中はtrueです。falseのときは表示を消してください。
  final bool keepCurrent;

  const LiveCoachUpdate._(this.message, this.keepCurrent);

  /// 新しい助言を出す
  const LiveCoachUpdate.show(LiveCoachMessage message) : this._(message, false);

  /// いまは出す助言がない（表示は消す）
  const LiveCoachUpdate.none() : this._(null, false);

  /// 表示はそのまま（出し直しの間隔を空けている最中）
  const LiveCoachUpdate.unchanged() : this._(null, true);
}

/// 試合中アドバイスの取りまとめ役
///
/// 段取りは次のとおりです。
///
/// 1. **何を言うかは [LiveCoachEngine] が決める**。数値の判断を小さなモデルに
///    任せると、根拠のない助言が出ます。
/// 2. 端末内LLMが使えるなら、選んだ助言の**言い回しだけ**作り直す。
///    クラウドは使いません。体育館は電波が悪いことが多く、試合中に通信の
///    失敗を待たされるのが一番困るためです。費用もかかりません。
/// 3. 失敗したら定型文をそのまま出す。利用者には何も起きません。
///
/// プレミアム限定です。
class LiveCoachService {
  LiveCoachService._(); // インスタンス化を防ぐ

  /// 最後に助言を出した時刻（出し過ぎを防ぐ）
  static DateTime? _lastShownAt;

  /// 最後に出した助言の種類
  static String? _lastKey;

  /// LLMに与える役割の説明
  ///
  /// 「新しい情報を足さない」ことを最優先で指示します。1B級のモデルは
  /// 放っておくと、渡していない数値やもっともらしい戦術を作り出します。
  static const String _systemInstruction = 'あなたはソフトテニスのコーチです。'
      '渡された助言を、試合中の選手がひと目で読める日本語に整えます。'
      '与えられた事実以外は絶対に書かないでください。'
      '出力は60文字以内の1文だけで、前置きも記号も付けないでください。';

  /// 生成した文章として受け付ける上限（これを超えたら定型文に戻す）
  static const int _maxTextLength = 120;

  /// いま出すべき助言を求める（無いときはnull）
  ///
  /// [force] がtrueのときは間隔の制限を無視します（利用者が自分で
  /// 「アドバイス」を押したとき用）。
  static Future<LiveCoachUpdate> advise(
    LiveCoachInput input, {
    bool force = false,
  }) async {
    if (!await isEntitled()) return const LiveCoachUpdate.none();

    final advice = LiveCoachEngine.advise(input);
    if (advice == null) return const LiveCoachUpdate.none();

    if (!force && !_shouldShow(advice)) return const LiveCoachUpdate.unchanged();
    _lastShownAt = DateTime.now();
    _lastKey = advice.key;

    final phrased = await _phrase(advice);
    return LiveCoachUpdate.show(LiveCoachMessage(
      key: advice.key,
      headline: advice.headline,
      text: phrased ?? advice.template,
      phrasedByAi: phrased != null,
    ));
  }

  /// 試合画面を離れるときに呼ぶ
  ///
  /// 読み込んだモデルはメモリを大きく使うため、試合が終わったら解放します。
  static Future<void> onLeaveMatch() async {
    _lastShownAt = null;
    _lastKey = null;
    await LocalLlm.release();
  }

  /// 試合中アドバイスを使ってよい状態か（課金しているか）
  ///
  /// 動作確認のときだけ、デバッグビルドに限り課金判定を飛ばせます。
  static Future<bool> isEntitled() async {
    if (kDebugMode && AiConfig.forcePremium) return true;
    return SubscriptionService.isSubscribed();
  }

  /// 直前と同じ助言を出し続けたり、短い間隔で出し直したりしないか
  static bool _shouldShow(LiveAdvice advice) {
    final last = _lastShownAt;
    if (last == null) return true;

    final elapsed = DateTime.now().difference(last);
    // 種類が変わったなら、状況が変わったということなのですぐ出す
    if (advice.key != _lastKey) return true;
    return elapsed >= LocalAiConfig.liveCooldown;
  }

  /// 端末内LLMで言い回しを整える（使えないときはnull）
  static Future<String?> _phrase(LiveAdvice advice) async {
    if (!LocalAiConfig.isConfigured) return null;

    try {
      final generated = await LocalLlm.generate(
        buildPrompt(advice),
        systemInstruction: _systemInstruction,
        timeout: LocalAiConfig.liveTimeout,
        maxTokens: LocalAiConfig.liveMaxTokens,
      );
      return sanitize(generated);
    } catch (e) {
      debugPrint('試合中アドバイスの言い換えに失敗: $e');
      return null;
    }
  }

  /// LLMへ渡す本文を組み立てる
  ///
  /// 渡すのは「選んだ助言」と「その根拠の数値」だけです。生のスタッツを
  /// 全部渡すと、モデルが勝手に別の結論を出し始めます。
  static String buildPrompt(LiveAdvice advice) {
    final buffer = StringBuffer()
      ..writeln('次の助言を、言い回しだけ整えてください。')
      ..writeln('助言: ${advice.template}');
    if (advice.facts.isNotEmpty) {
      buffer.writeln('根拠:');
      advice.facts.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
    }
    buffer.write('整えた1文だけを出力してください。');
    return buffer.toString();
  }

  /// 生成結果を表示に使ってよいか確かめる
  ///
  /// 小さなモデルは、前置き・箇条書き・英語・途中で切れた文を返すことが
  /// あります。怪しいものは捨てて定型文に戻します。
  static String? sanitize(String? generated) {
    if (generated == null) return null;

    // 前置きや箇条書きが付いてきたときは最初の1行だけ使う
    var text = generated
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    text = text.replaceAll(RegExp(r'^[-*・>「」\s]+'), '').trim();
    if (text.isEmpty) return null;
    if (text.length > _maxTextLength) return null;

    // 日本語が1文字も含まれないなら、指示を無視した出力とみなす
    if (!RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(text)) return null;

    return text;
  }

  /// テスト用に内部状態を戻す
  static void resetForTest() {
    _lastShownAt = null;
    _lastKey = null;
  }
}
