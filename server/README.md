# AI分析プロキシ

統計画面のコメントをLLMに書かせるための中継サーバーです。Cloudflare Workers の無料枠（1日10万リクエスト）で動きます。

## なぜアプリから直接LLMを呼ばないのか

APIキーをFlutterアプリに埋め込むと、ビルド済みバイナリから簡単に抜き取れます。抜かれた瞬間に他人が無料枠を使い切るため、**キーを持つのはこのWorkerだけ**にしています。あわせて、呼び出し回数の上限とモデルの差し替えもここに集約しています。

## セットアップ

```bash
cd server
npx wrangler kv namespace create RATE_LIMIT   # 回数制限を使う場合
# 出力された id を wrangler.toml の kv_namespaces に記入し、コメントを外す

npx wrangler secret put GEMINI_API_KEY        # Google AI Studio で取得したキー
npx wrangler deploy
```

デプロイすると `https://soft-tennis-ai-insight.<account>.workers.dev` が発行されます。これをアプリのビルド時に渡します。

```bash
flutter build ipa --dart-define=AI_INSIGHT_ENDPOINT=https://soft-tennis-ai-insight.<account>.workers.dev
```

`--dart-define` を付けずにビルドすると AI分析は無効になり、従来どおりルールベースの分析だけが動きます。

## 手元で動作確認する

AI分析はプレミアム限定です。課金せずに確認したいときは、**デバッグ実行に限り**課金判定を飛ばせます。

```bash
flutter run \
  --dart-define=AI_INSIGHT_ENDPOINT=https://soft-tennis-ai-insight.<account>.workers.dev \
  --dart-define=AI_FORCE_PREMIUM=true
```

`AI_FORCE_PREMIUM` はデバッグビルドでしか効きません（リリースビルドでは無視されます）。

確認の手順は次のとおりです。

1. 試合を1つ記録して終了させる（統計画面を一度も開いていない場合は、先に統計画面を開いて対象を選んでおく）
2. 60秒待つ（最後の保存からこの時間が経ってから生成が走ります）
3. 統計画面を開く → 分析コメントがAIの文章に変わっている

生成はバックグラウンドなので、待っている間もアプリは普通に使えます。失敗したときはルールベースの文章のままになり、ログに理由が出ます。

## 費用の上限を必ず設定してください

想定は外れるものなので、Google Cloud（AI Studio）側で**予算アラートと上限**を設定してください。Worker 側の1日10回制限とアプリ側の10回制限に加えて、これが最後の安全弁になります。

## 送っているデータ

数値と、`対戦相手A` `選手B` のような匿名の呼び名だけです。**選手の実名はアプリ側で置換してから送っており、Workerにも届きません。** 返ってきた文章に含まれる呼び名は、アプリ側で実名に戻して表示します。
