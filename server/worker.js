/**
 * 分析コメント生成プロキシ（Cloudflare Workers）
 *
 * アプリから匿名化済みのスタッツ（数値のみ）を受け取り、LLMに日本語の
 * コメントを書かせて返します。
 *
 * このプロキシを挟む理由は3つあります。
 *   1. APIキーをアプリに埋めないため。ビルド済みバイナリからは文字列を
 *      簡単に抜けるので、キーを持つのはここだけにします。
 *   2. 1日あたりの呼び出し回数に上限を置くため（課金の暴発を防ぐ安全弁）。
 *   3. モデルや文体を、アプリを再リリースせずに差し替えられるようにするため。
 *
 * デプロイ:
 *   npx wrangler deploy
 *   npx wrangler secret put GEMINI_API_KEY
 */

/** 1端末あたり1日の生成回数の上限（アプリ側にも同じ制限がある） */
const DAILY_LIMIT_PER_CLIENT = 10;

/** 生成に使うモデル */
const MODEL = 'gemini-2.5-flash-lite';

const SYSTEM_PROMPT = `あなたはソフトテニスのコーチです。選手の試合記録から集計した数値だけを渡されます。

制約:
- 出力は必ずJSONのみ。形式は {"comments":[{"type":"good|warning|info","text":"..."}]}
- コメントは3〜5件。1件あたり日本語で60〜120字。
- type は good（強み）/ warning（課題）/ info（助言）から選ぶ。
- 重要なものから順に並べる。
- 渡された数値から言えることだけを書く。打球のコースや球種のデータは渡していないので、それらには言及しない。
- 母数が少ない指標（試合数やポイント数が10未満）を根拠にしない。
- 数値を挙げるときは渡された値をそのまま使い、計算し直さない。
- 「対戦相手A」「選手B」はそのままの表記で使う。実在の人名に置き換えない。
- 精神論ではなく、次の練習で試せる具体的な内容を書く。`;

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'method_not_allowed' }, 405);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'invalid_json' }, 400);
    }

    const stats = body?.stats;
    if (!stats || typeof stats !== 'object') {
      return json({ error: 'missing_stats' }, 400);
    }

    // 実名が混ざっていないかの最終確認はアプリ側で済ませているが、
    // ここでも受け取るのは数値と定型の呼び名だけに保つ（サイズで弾く）。
    const statsText = JSON.stringify(stats);
    if (statsText.length > 8000) {
      return json({ error: 'stats_too_large' }, 413);
    }

    const overLimit = await consumeQuota(request, env);
    if (overLimit) {
      return json({ error: 'rate_limited' }, 429);
    }

    const upstream = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ role: 'user', parts: [{ text: statsText }] }],
          generationConfig: {
            temperature: 0.4,
            maxOutputTokens: 1024,
            responseMimeType: 'application/json',
          },
        }),
      },
    );

    if (!upstream.ok) {
      // 上流の失敗はそのまま伝える。アプリはルールベースの分析へ落ちる。
      return json({ error: 'upstream_error' }, upstream.status === 429 ? 429 : 502);
    }

    const data = await upstream.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return json({ error: 'empty_response' }, 502);
    }

    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      return json({ error: 'unparsable_response' }, 502);
    }

    if (!Array.isArray(parsed?.comments)) {
      return json({ error: 'unexpected_shape' }, 502);
    }

    return json({ comments: parsed.comments });
  },
};

/**
 * 1日あたりの呼び出し回数を数え、上限を超えていたら true を返す。
 *
 * KV名前空間 RATE_LIMIT が結び付けられていないときは制限しない
 * （開発中に KV なしで動かせるようにするため）。
 */
async function consumeQuota(request, env) {
  if (!env.RATE_LIMIT) return false;

  const client = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const today = new Date().toISOString().slice(0, 10);
  const key = `q:${today}:${client}`;

  const used = Number((await env.RATE_LIMIT.get(key)) ?? '0');
  if (used >= DAILY_LIMIT_PER_CLIENT) return true;

  // 日付が変われば別キーになるので、2日で自動的に消えれば十分
  await env.RATE_LIMIT.put(key, String(used + 1), { expirationTtl: 172800 });
  return false;
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
