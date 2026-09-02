/// AI分析（LLM）の接続設定
///
/// APIキーはアプリに埋め込みません。ビルド済みバイナリからは文字列を
/// 簡単に取り出せるため、キーを持つのは自前のプロキシ（server/worker.js）だけです。
/// アプリはプロキシのURLしか知りません。
class AiConfig {
  AiConfig._(); // インスタンス化を防ぐ

  /// 分析文生成プロキシのエンドポイント
  ///
  /// `--dart-define=AI_INSIGHT_ENDPOINT=https://...` で差し替えられます。
  /// 空文字のままビルドするとAI分析は無効になり、ルールベースの分析だけが動きます。
  static const String endpoint =
      String.fromEnvironment('AI_INSIGHT_ENDPOINT', defaultValue: '');

  /// AI分析が利用可能な構成でビルドされているか
  static bool get isConfigured => endpoint.isNotEmpty;

  /// 動作確認用に、課金していなくてもAI分析を有効にする
  ///
  /// `--dart-define=AI_FORCE_PREMIUM=true` で立ちます。**デバッグビルドでしか
  /// 効きません**（[AiInsightService] 側で `kDebugMode` と併せて判定します）。
  /// リリースビルドに紛れ込んでも課金の迂回にはなりません。
  static const bool forcePremium =
      bool.fromEnvironment('AI_FORCE_PREMIUM', defaultValue: false);

  /// 試合を保存してから生成を始めるまでの待ち時間
  ///
  /// 大会の日は1人が1日に何試合も記録します。保存のたびに生成すると
  /// ほぼ同じ文章を作っては捨てることになるため、最後の保存から
  /// この時間が経ってから1回だけ生成します。
  static const Duration generationDelay = Duration(seconds: 60);

  /// 1端末あたり1日の生成回数の上限
  ///
  /// 不具合や連打で課金が跳ねるのを防ぐための安全弁です。
  /// サーバー側にも同じ制限を置いてあります（多重防御）。
  static const int maxGenerationsPerDay = 10;

  /// プロキシの応答を待つ上限
  static const Duration requestTimeout = Duration(seconds: 30);
}
