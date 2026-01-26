# データベース設計書

## 1. 概要

- **データベース名**: `soft_tennis.db`
- **データベースバージョン**: 6
- **データベースエンジン**: SQLite
- **文字エンコーディング**: UTF-8

## 2. テーブル一覧

| テーブル名 | 説明 | 主キー |
|-----------|------|--------|
| `matches` | 試合情報 | `id` |
| `set_scores` | セットスコア（現在未使用） | `id` |
| `game_scores` | ゲームスコア | `id` |
| `players` | 選手マスター情報 | `id` |
| `clubs` | 所属チームマスター情報 | `id` |
| `point_details` | ポイント詳細情報（詳細入力モード用） | `id` |

## 3. テーブル詳細

### 3.1 matches テーブル

試合の基本情報を保存するテーブル。

| カラム名 | データ型 | 制約 | デフォルト値 | 説明 |
|---------|---------|------|------------|------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | - | 主キー（自動採番） |
| `tournament_name` | TEXT | - | NULL | 大会・イベント名 |
| `team1_player1` | TEXT | NOT NULL | - | チーム1のプレイヤー1名 |
| `team1_player2` | TEXT | NOT NULL | - | チーム1のプレイヤー2名 |
| `team1_club` | TEXT | - | NULL | チーム1の所属（学校・クラブ名） |
| `team2_player1` | TEXT | NOT NULL | - | チーム2のプレイヤー1名 |
| `team2_player2` | TEXT | NOT NULL | - | チーム2のプレイヤー2名 |
| `team2_club` | TEXT | - | NULL | チーム2の所属（学校・クラブ名） |
| `game_count` | INTEGER | - | 7 | ゲーム数（5, 7, 9など） |
| `first_serve` | TEXT | - | NULL | 先サーブチーム（'team1' または 'team2'） |
| `created_at` | TEXT | NOT NULL | - | 作成日時（ISO8601形式） |
| `completed_at` | TEXT | - | NULL | 完了日時（ISO8601形式、NULL=進行中） |
| `winner` | TEXT | - | NULL | 勝利チーム（'team1' または 'team2'、NULL=未完了） |

**インデックス**: なし

**備考**:
- `completed_at` と `winner` が両方設定されている場合、試合は完了とみなされます
- `first_serve` は1ゲーム目のサーブ権を決定します

---

### 3.2 set_scores テーブル

セットごとのスコアを保存するテーブル（現在のアプリでは未使用）。

| カラム名 | データ型 | 制約 | デフォルト値 | 説明 |
|---------|---------|------|------------|------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | - | 主キー（自動採番） |
| `match_id` | INTEGER | NOT NULL, FOREIGN KEY | - | マッチID（matches.id参照） |
| `set_number` | INTEGER | NOT NULL | - | セット番号（1, 2, 3...） |
| `team1_score` | INTEGER | NOT NULL | - | チーム1のスコア |
| `team2_score` | INTEGER | NOT NULL | - | チーム2のスコア |
| `winner` | TEXT | - | NULL | セットの勝利チーム（'team1' または 'team2'） |

**外部キー制約**:
- `match_id` → `matches.id` ON DELETE CASCADE

**インデックス**:
- `idx_match_id` on `match_id`

**備考**: 現在のアプリでは使用されていない（将来の拡張用）

---

### 3.3 game_scores テーブル

ゲームごとの詳細なスコアを保存するテーブル。

| カラム名 | データ型 | 制約 | デフォルト値 | 説明 |
|---------|---------|------|------------|------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | - | 主キー（自動採番） |
| `match_id` | INTEGER | NOT NULL, FOREIGN KEY | - | マッチID（matches.id参照） |
| `game_number` | INTEGER | NOT NULL | - | ゲーム番号（1, 2, 3...） |
| `team1_score` | INTEGER | NOT NULL | - | チーム1のポイント数（0-7） |
| `team2_score` | INTEGER | NOT NULL | - | チーム2のポイント数（0-7） |
| `service_team` | TEXT | - | NULL | サーブ権を持つチーム（'team1' または 'team2'） |
| `winner` | TEXT | - | NULL | ゲームの勝利チーム（'team1' または 'team2'、NULL=進行中） |

**外部キー制約**:
- `match_id` → `matches.id` ON DELETE CASCADE

**インデックス**:
- `idx_game_match_id` on `match_id`

**備考**:
- 通常ゲーム: 4ポイント先取で勝利（2ポイント差が必要）
- ファイナルゲーム: 7ポイント先取で勝利（2ポイント差が必要）
- `winner` が NULL の場合、ゲームは進行中です

---

### 3.4 players テーブル

選手マスター情報を保存するテーブル。

| カラム名 | データ型 | 制約 | デフォルト値 | 説明 |
|---------|---------|------|------------|------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | - | 主キー（自動採番） |
| `name` | TEXT | NOT NULL | - | 選手名 |
| `club` | TEXT | - | NULL | 所属（学校・クラブ名） |
| `display_name` | TEXT | NOT NULL | - | 表示名（識別子付き、例：「山田（太）」） |
| `created_at` | TEXT | NOT NULL | - | 作成日時（ISO8601形式） |

**インデックス**:
- `idx_player_name` on `name`
- `idx_player_club` on `club`

**備考**:
- 同じ名前・同じ所属の選手は重複チェックが行われます
- `display_name` は後方互換性のため残していますが、現在は `name` と同じ値を設定します

---

### 3.5 clubs テーブル

所属チームマスター情報を保存するテーブル。

| カラム名 | データ型 | 制約 | デフォルト値 | 説明 |
|---------|---------|------|------------|------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | - | 主キー（自動採番） |
| `name` | TEXT | NOT NULL, UNIQUE | - | 所属名 |
| `created_at` | TEXT | NOT NULL | - | 作成日時（ISO8601形式） |

**インデックス**: なし（UNIQUE制約により自動的にインデックスが作成されます）

**備考**:
- 同じ名前の所属は重複できません（UNIQUE制約）

---

### 3.6 point_details テーブル

ポイントごとの詳細情報を保存するテーブル（詳細入力モード用）。

| カラム名 | データ型 | 制約 | デフォルト値 | 説明 |
|---------|---------|------|------------|------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | - | 主キー（自動採番） |
| `match_id` | INTEGER | NOT NULL, FOREIGN KEY | - | マッチID（matches.id参照） |
| `game_number` | INTEGER | NOT NULL | - | ゲーム番号 |
| `point_number` | INTEGER | NOT NULL | - | ゲーム内のポイント番号 |
| `server_team` | TEXT | NOT NULL | - | サーブ側チーム（'team1' または 'team2'） |
| `server_player` | TEXT | - | NULL | サーブを打った選手名 |
| `first_serve_in` | INTEGER | NOT NULL | - | 1stサーブが入ったか（1=入った, 0=入らなかった） |
| `point_winner` | TEXT | NOT NULL | - | ポイント獲得チーム（'team1' または 'team2'） |
| `point_type` | TEXT | NOT NULL | - | ポイント種類（'ace', 'winner', 'opponent_error'） |
| `action_player` | TEXT | - | NULL | アクションを起こした選手名 |
| `created_at` | TEXT | NOT NULL | - | 作成日時（ISO8601形式） |

**外部キー制約**:
- `match_id` → `matches.id` ON DELETE CASCADE

**インデックス**:
- `idx_point_details_match_id` on `match_id`

**備考**:
- 詳細入力モードが有効な場合のみ使用されます
- プレミアム機能（サブスクリプション）が必要です
- `point_type` の値:
  - `'ace'`: エース（サーブで直接ポイント）
  - `'winner'`: ウィナー（ショットで直接ポイント）
  - `'opponent_error'`: 相手のミス

---

## 4. リレーションシップ

```
matches (1) ──< (N) game_scores
matches (1) ──< (N) set_scores
matches (1) ──< (N) point_details
```

- 1つの試合に対して複数のゲームスコアが存在します
- 1つの試合に対して複数のセットスコアが存在します（現在未使用）
- 1つの試合に対して複数のポイント詳細が存在します（詳細入力モード時）
- `matches` を削除すると、関連する `game_scores`、`set_scores`、`point_details` も自動削除されます（CASCADE）

---

## 5. データ型の詳細

### 5.1 TEXT型の値

- `first_serve`, `service_team`, `winner`, `server_team`, `point_winner`: `'team1'` または `'team2'`
- `created_at`, `completed_at`: ISO8601形式の文字列（例: `"2024-01-15T10:30:00.000Z"`）
- `point_type`: `'ace'`, `'winner'`, `'opponent_error'` のいずれか

### 5.2 INTEGER型の値

- `game_count`: 5, 7, 9 のいずれか
- `game_number`: 1以上の整数
- `team1_score`, `team2_score`: 0以上の整数（通常ゲーム: 0-4、ファイナルゲーム: 0-7）
- `first_serve_in`: 0（入らなかった）または 1（入った）

---

## 6. データベースマイグレーション

### バージョン1 → バージョン2

以下のカラムが `matches` テーブルに追加されました：
- `tournament_name`
- `team1_club`
- `team2_club`
- `game_count`
- `first_serve`

`game_scores` テーブルが新規作成されました。

### バージョン2 → バージョン3

以下のテーブルが新規作成されました：
- `players` テーブル（選手マスター）
- `clubs` テーブル（所属チームマスター）

### バージョン3 → バージョン4

以下のテーブルが新規作成されました：
- `point_details` テーブル（ポイント詳細情報）

### バージョン4 → バージョン5

`point_details` テーブルに以下のカラムが追加されました：
- `action_player`（アクションを起こした選手名）

### バージョン5 → バージョン6

`point_details` テーブルに以下のカラムが追加されました：
- `server_player`（サーブを打った選手名）

---

## 7. パフォーマンス最適化

### インデックス

- `idx_match_id`: `set_scores.match_id` に対する検索を高速化
- `idx_game_match_id`: `game_scores.match_id` に対する検索を高速化
- `idx_player_name`: `players.name` に対する検索を高速化
- `idx_player_club`: `players.club` に対する検索を高速化
- `idx_point_details_match_id`: `point_details.match_id` に対する検索を高速化

### クエリパターン

主なクエリパターン：
1. 全試合の取得（`matches` テーブル、`created_at DESC` でソート）
2. 特定試合のゲームスコア取得（`game_scores` テーブル、`match_id` でフィルタ、`game_number ASC` でソート）
3. 特定試合のポイント詳細取得（`point_details` テーブル、`match_id` でフィルタ、`game_number ASC, point_number ASC` でソート）
4. 試合の削除（CASCADE削除により関連データも自動削除）

---

## 8. ER図

```
┌─────────────────┐
│     matches      │
├─────────────────┤
│ id (PK)         │
│ tournament_name │
│ team1_player1   │
│ team1_player2   │
│ team1_club      │
│ team2_player1   │
│ team2_player2   │
│ team2_club      │
│ game_count      │
│ first_serve     │
│ created_at      │
│ completed_at    │
│ winner          │
└────────┬────────┘
         │
         │ 1
         │
         ├─── N ───┐
         │         │
         │         │
┌────────▼────────┐ │ ┌──────────────┐
│  game_scores    │ │ │ point_details│
├─────────────────┤ │ ├──────────────┤
│ id (PK)        │ │ │ id (PK)      │
│ match_id (FK)  │ │ │ match_id (FK)│
│ game_number    │ │ │ game_number  │
│ team1_score    │ │ │ point_number │
│ team2_score    │ │ │ server_team  │
│ service_team   │ │ │ server_player│
│ winner         │ │ │ first_serve_ │
└─────────────────┘ │ │   in         │
                    │ │ point_winner │
┌─────────────────┐ │ │ point_type  │
│   set_scores     │ │ │ action_play │
├─────────────────┤ │ │   er         │
│ id (PK)         │ │ │ created_at  │
│ match_id (FK)   │ │ └──────────────┘
│ set_number      │ │
│ team1_score     │ │
│ team2_score     │ │
│ winner          │ │
└─────────────────┘ │
                    │
                    │
         ┌──────────┘
         │
         │
┌────────▼────────┐
│    players      │
├─────────────────┤
│ id (PK)         │
│ name            │
│ club            │
│ display_name    │
│ created_at      │
└─────────────────┘

┌─────────────────┐
│     clubs       │
├─────────────────┤
│ id (PK)         │
│ name (UNIQUE)   │
│ created_at      │
└─────────────────┘
```

---

## 9. データ整合性

### 9.1 外部キー制約

- `game_scores.match_id` → `matches.id` (CASCADE削除)
- `set_scores.match_id` → `matches.id` (CASCADE削除)
- `point_details.match_id` → `matches.id` (CASCADE削除)

### 9.2 ビジネスルール

1. **試合の完了条件**
   - `completed_at` が設定されている
   - `winner` が設定されている
   - ゲーム数に応じた勝利条件を満たしている

2. **ゲームの完了条件**
   - 通常ゲーム: 4ポイント先取かつ2ポイント差
   - ファイナルゲーム: 7ポイント先取かつ2ポイント差

3. **サーブ権のルール**
   - 通常ゲーム: ゲームごとに交代
   - ファイナルゲーム: 2ポイントごとに交代

4. **選手マスターの重複チェック**
   - 同じ名前・同じ所属の選手は重複できません

5. **所属マスターの重複チェック**
   - 同じ名前の所属は重複できません（UNIQUE制約）

---

## 10. データベースアクセスパターン

### 10.1 試合データの操作

```dart
// 試合の作成
final match = Match(...);
final matchId = await DatabaseHelper.instance.insertMatch(match);

// 試合の取得
final match = await DatabaseHelper.instance.getMatch(matchId);

// 全試合の取得
final matches = await DatabaseHelper.instance.getAllMatches();

// 試合の更新
await DatabaseHelper.instance.updateMatch(match);

// 試合の削除（関連データも自動削除）
await DatabaseHelper.instance.deleteMatch(matchId);
```

### 10.2 ゲームスコアの操作

```dart
// ゲームスコアの追加
final gameScore = GameScore(...);
await DatabaseHelper.instance.insertGameScore(gameScore);

// 試合の全ゲームスコア取得
final gameScores = await DatabaseHelper.instance.getGameScoresByMatchId(matchId);

// ゲームスコアの更新
await DatabaseHelper.instance.updateGameScore(gameScore);
```

### 10.3 ポイント詳細の操作

```dart
// ポイント詳細の追加
final pointDetail = PointDetail(...);
await DatabaseHelper.instance.insertPointDetail(pointDetail);

// 試合の全ポイント詳細取得
final pointDetails = await DatabaseHelper.instance.getPointDetailsByMatchId(matchId);

// 最後のポイント詳細を削除（Undo用）
await DatabaseHelper.instance.deleteLastPointDetail(matchId);
```

---

## 11. バックアップと復元

データベースファイル（`soft_tennis.db`）を直接コピーすることで、全データのバックアップと復元が可能です。

- **バックアップ**: データベースファイルを別の場所にコピー
- **復元**: バックアップファイルを元の場所にコピー

**注意**: データベースファイルの場所はプラットフォームによって異なります：
- Android/iOS: アプリのデータディレクトリ内
- Web: ブラウザのIndexedDB内
