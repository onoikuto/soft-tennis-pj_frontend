import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:soft_tennis_scoring/config/local_ai_config.dart';
import 'package:soft_tennis_scoring/services/local_llm.dart';
import 'package:soft_tennis_scoring/services/pair_report.dart';

/// 画面に出す、ここまでの傾向
class GameReportMessage {
  final PairReport report;

  /// 一言を端末内LLMで整えたか（AIバッジの出し分け）
  final bool phrasedByAi;

  const GameReportMessage({required this.report, required this.phrasedByAi});
}

/// ゲームが終わるたびに出す振り返りの取りまとめ役
///
/// 段取りは次のとおりです。
///
/// 1. **何を言うかは [PairReport] が決める**。数値の判断を小さなモデルに
///    任せると、根拠のない話が出ます。
/// 2. 端末内LLMが使えるなら、**一言だけ**言い回しを整える。
///    クラウドは使いません。体育館は電波が悪いことが多く、試合中に通信の
///    失敗を待たされるのが一番困るためです。費用もかかりません。
/// 3. 失敗したらルールが作った文をそのまま出す。利用者には何も起きません。
///
/// 課金の有無に関わらず出します（課金対象は統計画面だけです）。
class LiveCoachService {
  LiveCoachService._(); // インスタンス化を防ぐ

  /// LLMに与える役割の説明
  ///
  /// 「新しい情報を足さない」ことを最優先で指示します。1B級のモデルは
  /// 放っておくと、渡していない数値やもっともらしい対策を作り出します。
  static const String _systemInstruction = 'あなたはソフトテニスの記録係です。'
      '渡された事実を、試合中の選手がひと目で読める日本語に整えます。'
      '与えられた事実以外は絶対に書かないでください。'
      '励ましや指示は書かないでください（「頑張りましょう」「意識しましょう」など）。'
      '出力は60文字以内で、前置きも記号も付けないでください。';

  /// 生成した文章として受け付ける上限（これを超えたら元の文に戻す）
  static const int _maxTextLength = 120;

  /// ゲームが終わったところで呼ぶ
  ///
  /// 出せるものが無ければnullを返します（呼び出し側は表示を消してください）。
  static Future<GameReportMessage?> report(PairReport report) async {
    if (!report.hasContent) {
      debugPrint('ゲームごとの振り返り: 出せる材料がない');
      return null;
    }

    final phrased = await _phrase(report.summary);
    debugPrint('ゲームごとの振り返り: ${report.summary}'
        '${phrased == null ? '' : ' → $phrased'}');

    if (phrased == null) {
      return GameReportMessage(report: report, phrasedByAi: false);
    }
    return GameReportMessage(
      report: report.copyWith(summary: phrased),
      phrasedByAi: true,
    );
  }

  /// 試合画面を離れるときに呼ぶ
  ///
  /// 読み込んだモデルはメモリを大きく使うため、試合が終わったら解放します。
  static Future<void> onLeaveMatch() => LocalLlm.release();

  /// 一言を端末内LLMで整える（使えないときはnull）
  static Future<String?> _phrase(String? summary) async {
    if (summary == null) return null;
    if (!LocalAiConfig.isConfigured) return null;

    try {
      final generated = await LocalLlm.generate(
        buildPrompt(summary),
        systemInstruction: _systemInstruction,
        timeout: LocalAiConfig.liveTimeout,
        maxTokens: LocalAiConfig.liveMaxTokens,
      );
      debugPrint('ゲームごとの振り返り: LLM出力=${generated ?? "(なし)"}');
      return sanitize(generated);
    } catch (e) {
      debugPrint('ゲームごとの振り返りの言い換えに失敗: $e');
      return null;
    }
  }

  /// LLMへ渡す本文を組み立てる
  ///
  /// 渡すのは「ルールが選んだ一言」だけです。生のスタッツを全部渡すと、
  /// モデルが勝手に別の結論を出し始めます。
  static String buildPrompt(String summary) {
    return '次の事実を、言い回しだけ整えてください。\n'
        '事実: $summary\n'
        '整えた文だけを出力してください。対策や励ましは書かないでください。';
  }

  /// 生成結果を表示に使ってよいか確かめる
  ///
  /// 小さなモデルは、前置き・箇条書き・英語・途中で切れた文を返すことが
  /// あります。怪しいものは捨てて元の文に戻します。
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
}
