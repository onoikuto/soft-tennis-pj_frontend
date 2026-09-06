/// 端末内LLM（オンデバイス推論）の設定
///
/// クラウドのプロキシ（[AiConfig]）と違い、こちらは**呼び出し回数に費用が
/// かからない**代わりに、モデルファイル（数百MB〜数GB）を端末に置く必要が
/// あります。同梱するとストアの配信サイズ制限に引っかかるため、
/// **初回に利用者がダウンロードする**方式にしています。
class LocalAiConfig {
  LocalAiConfig._(); // インスタンス化を防ぐ

  /// 端末内LLMを使う構成でビルドされているか
  ///
  /// `--dart-define=LOCAL_AI_ENABLED=true` で有効になります。既定では無効で、
  /// その場合はこれまでどおりルールベース＋クラウドだけが動きます。
  static const bool enabled =
      bool.fromEnvironment('LOCAL_AI_ENABLED', defaultValue: false);

  /// モデルの配布元URL
  ///
  /// `--dart-define=LOCAL_AI_MODEL_URL=https://...` で差し替えます。
  /// 空のままだと、端末内LLMは「未設定」として扱われます。
  static const String modelUrl =
      String.fromEnvironment('LOCAL_AI_MODEL_URL', defaultValue: '');

  /// 端末に保存するときのファイル名
  ///
  /// モデルを差し替えたらこの名前も変えてください。同じ名前のまま中身を
  /// 変えると、古いファイルがダウンロード済みと判定されてしまいます。
  static const String modelFileName = String.fromEnvironment(
    'LOCAL_AI_MODEL_FILE',
    defaultValue: 'gemma3-1b-it-int4.task',
  );

  /// 利用者に見せるモデルのおおよそのサイズ（MB）
  ///
  /// ダウンロードの確認ダイアログで「約○○MB」と出すためだけに使います。
  static const int modelSizeMb =
      int.fromEnvironment('LOCAL_AI_MODEL_SIZE_MB', defaultValue: 555);

  /// 非公開モデルを取得するためのトークン（HuggingFace等）
  static const String modelToken =
      String.fromEnvironment('LOCAL_AI_MODEL_TOKEN', defaultValue: '');

  /// 端末内LLMを使える構成か（有効かつ配布元が指定されている）
  static bool get isConfigured => enabled && modelUrl.isNotEmpty;

  /// 生成の待ち時間の上限
  ///
  /// 試合中のアドバイスは「すぐ出ないなら要らない」ので短めにします。
  /// 超えた場合はルールベースの定型文をそのまま出します。
  static const Duration liveTimeout = Duration(seconds: 8);

  /// 試合後のまとめ生成の待ち時間の上限（画面を閉じたあとに動くので長めでよい）
  static const Duration reviewTimeout = Duration(seconds: 60);

  /// 1回の生成で許す最大トークン数
  ///
  /// 試合中に長文を出しても読めないため、短く切ります。
  static const int liveMaxTokens = 120;

  /// 試合中アドバイスを出し直す最短間隔
  ///
  /// ポイントが入るたびに文章を作り直すと、端末が熱を持つうえ画面が
  /// ちらつきます。同じ助言を出し続けても意味がないので間隔を空けます。
  static const Duration liveCooldown = Duration(seconds: 45);
}
