import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_gemma/flutter_gemma.dart';

import 'package:soft_tennis_scoring/config/local_ai_config.dart';

/// 端末内LLMの状態
enum LocalLlmState {
  /// このビルド・この端末では使えない
  unavailable,

  /// 使える構成だが、モデルがまだ端末にない
  notInstalled,

  /// ダウンロード中
  installing,

  /// 使える
  ready,
}

/// 端末内LLM（flutter_gemma）への唯一の窓口
///
/// **flutter_gemmaに触れるのはこのファイルだけ**にしています。推論まわりは
/// 変化が速く、モデルもランタイムも差し替える前提なので、呼び出し側は
/// 「文字列を渡すと文字列が返る（返らないこともある）」だけを知っていれば
/// いいようにしています。
///
/// 生成に失敗しても例外は投げず、nullを返します。呼び出し側は必ず
/// ルールベースの定型文を用意しておいてください。
class LocalLlm {
  LocalLlm._(); // インスタンス化を防ぐ

  static bool _initialized = false;
  static InferenceModel? _model;

  /// 生成の直列化
  ///
  /// 端末内推論は同時に走らせるとメモリを食い潰して落ちます。
  /// 走っている間は新しい依頼を受けません（試合中は最新の助言だけが要る）。
  static bool _busy = false;

  /// この端末で端末内推論を試せるか
  ///
  /// Web・デスクトップにもプラグイン自体は対応していますが、動作確認をして
  /// いないため、いまはモバイルだけに限定します。
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// 端末内LLMが今すぐ使える状態か
  static Future<bool> isReady() async {
    if (!LocalAiConfig.isConfigured || !isSupported) return false;
    try {
      await _ensureInitialized();
      // ファイルを直接読む構成では、参照を張った時点で使える状態になる
      if (LocalAiConfig.usesLocalFile) return FlutterGemma.hasActiveModel();
      return FlutterGemma.isModelInstalled(LocalAiConfig.modelFileName);
    } catch (e) {
      debugPrint('端末内LLMの状態を確認できませんでした: $e');
      return false;
    }
  }

  /// 現在の状態を返す（設定画面の表示用）
  static Future<LocalLlmState> state() async {
    if (!LocalAiConfig.isConfigured || !isSupported) {
      return LocalLlmState.unavailable;
    }
    return await isReady() ? LocalLlmState.ready : LocalLlmState.notInstalled;
  }

  /// モデルを端末にダウンロードする
  ///
  /// 数百MB〜数GBあるため、**利用者に確認してから**呼んでください。
  /// [onProgress] には0〜100が渡ります。
  /// 成功したらtrueを返します。
  static Future<bool> install({void Function(int percent)? onProgress}) async {
    if (!LocalAiConfig.isConfigured || !isSupported) return false;

    try {
      await _ensureInitialized();
      var builder = FlutterGemma.installModel(
        modelType: _modelType,
        fileType: _fileType,
      );
      if (LocalAiConfig.usesLocalFile) {
        // 端末に置いたファイルをそのまま使う（動作確認用）
        builder = builder.fromFile(LocalAiConfig.modelFilePath);
      } else {
        builder = builder.fromNetwork(
          LocalAiConfig.modelUrl,
          token:
              LocalAiConfig.modelToken.isEmpty ? null : LocalAiConfig.modelToken,
        );
      }
      if (onProgress != null) builder.withProgress(onProgress);
      await builder.install();
      return true;
    } catch (e) {
      debugPrint('端末内LLMのダウンロードに失敗: $e');
      return false;
    }
  }

  /// モデルを端末から削除する（容量を空けたいとき）
  static Future<void> uninstall() async {
    if (!isSupported) return;
    try {
      await _closeModel();
      await FlutterGemma.uninstallModel(LocalAiConfig.modelFileName);
    } catch (e) {
      debugPrint('端末内LLMの削除に失敗: $e');
    }
  }

  /// 文章を1つ生成する
  ///
  /// 失敗・タイムアウト・多重呼び出しのときはnullを返します。
  /// **nullが返るのは異常ではありません。** 呼び出し側は定型文へ倒してください。
  static Future<String?> generate(
    String prompt, {
    String? systemInstruction,
    required Duration timeout,
    required int maxTokens,
  }) async {
    if (_busy) return null;
    if (!await isReady()) {
      debugPrint('端末内LLM: まだ使えない'
          '（設定=${LocalAiConfig.isConfigured} / 対応端末=$isSupported）');
      return null;
    }

    _busy = true;
    InferenceModelSession? session;
    try {
      final model = await _ensureModel(maxTokens: maxTokens);
      session = await model.createSession(
        // 試合中の助言は毎回違う言い回しにする必要がないので、低めにして
        // ぶれを減らします。
        temperature: 0.4,
        topK: 40,
        systemInstruction: systemInstruction,
      );
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await session.getResponse().timeout(timeout);
      final text = response.trim();
      return text.isEmpty ? null : text;
    } on TimeoutException {
      debugPrint('端末内LLMの生成がタイムアウトしました');
      // 途中まで動いている推論を残すと次の生成が詰まるので閉じ切る
      await _closeModel();
      return null;
    } catch (e) {
      debugPrint('端末内LLMの生成に失敗: $e');
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {
        // 閉じられなくても呼び出し側にできることはない
      }
      _busy = false;
    }
  }

  /// 読み込んだモデルを解放する（試合画面を離れるときなど）
  static Future<void> release() => _closeModel();

  // ============================================================================
  // 内部
  // ============================================================================

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken:
          LocalAiConfig.modelToken.isEmpty ? null : LocalAiConfig.modelToken,
    );
    _initialized = true;
  }

  /// モデルを読み込む（読み込み済みなら使い回す）
  ///
  /// 読み込みには数秒かかるため、1ポイントごとに読み直さないよう保持します。
  static Future<InferenceModel> _ensureModel({required int maxTokens}) async {
    final existing = _model;
    if (existing != null) return existing;

    final model = await FlutterGemma.getActiveModel(
      // 助言に必要な文脈は短いので、小さく取って読み込みを軽くします。
      maxTokens: maxTokens + 512,
      preferredBackend: PreferredBackend.gpu,
    );
    _model = model;
    return model;
  }

  static Future<void> _closeModel() async {
    final model = _model;
    _model = null;
    if (model == null) return;
    try {
      await model.close();
    } catch (e) {
      debugPrint('端末内LLMの解放に失敗: $e');
    }
  }

  /// 設定で指定されたモデル種別
  ///
  /// 種別を間違えるとプロンプトの整形（チャットテンプレート）がずれて、
  /// 出力が壊れます。
  static ModelType get _modelType {
    switch (const String.fromEnvironment('LOCAL_AI_MODEL_TYPE',
        defaultValue: 'gemma')) {
      case 'qwen':
        return ModelType.qwen;
      case 'qwen3':
        return ModelType.qwen3;
      case 'deepseek':
        return ModelType.deepSeek;
      case 'phi':
        return ModelType.phi;
      case 'llama':
        return ModelType.llama;
      default:
        return ModelType.gemmaIt;
    }
  }

  /// ファイル名の拡張子から形式を判定する
  static ModelFileType get _fileType {
    final name = LocalAiConfig.modelFileName;
    if (name.endsWith('.litertlm')) return ModelFileType.litertlm;
    if (name.endsWith('.bin') || name.endsWith('.tflite')) {
      return ModelFileType.binary;
    }
    return ModelFileType.task;
  }
}
