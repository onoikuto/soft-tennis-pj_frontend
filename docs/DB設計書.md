# データベース設計書

## 1. 概要

- **データベース名**: `soft_tennis.db`
- **データベースバージョン**: 2
- **データベースエンジン**: SQLite
- **文字エンコーディング**: UTF-8

## 2. テーブル一覧

| テーブル名 | 説明 | 主キー |
|-----------|------|--------|
| `matches` | 試合情報 | `id` |
| `set_scores` | セットスコア（現在未使用） | `id` |
| `game_scores` | ゲームスコア | `id` |

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

## 4. リレーションシップ

```
matches (1) ──< (N) game_scores
matches (1) ──< (N) set_scores
```

- 1つの試合に対して複数のゲームスコアが存在します
- 1つの試合に対して複数のセットスコアが存在します（現在未使用）
- `matches` を削除すると、関連する `game_scores` と `set_scores` も自動削除されます（CASCADE）

---

## 5. データ型の詳細

### 5.1 TEXT型の値

- `first_serve`, `service_team`, `winner`: `'team1'` または `'team2'`
- `created_at`, `completed_at`: ISO8601形式の文字列（例: `"2024-01-15T10:30:00.000Z"`）

### 5.2 INTEGER型の値

- `game_count`: 5, 7, 9 のいずれか
- `game_number`: 1以上の整数
- `team1_score`, `team2_score`: 0以上の整数（通常ゲーム: 0-4、ファイナルゲーム: 0-7）

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

---

## 7. パフォーマンス最適化

### インデックス

- `idx_match_id`: `set_scores.match_id` に対する検索を高速化
- `idx_game_match_id`: `game_scores.match_id` に対する検索を高速化

### クエリパターン

主なクエリパターン：
1. 全試合の取得（`matches` テーブル、`created_at DESC` でソート）
2. 特定試合のゲームスコア取得（`game_scores` テーブル、`match_id` でフィルタ、`game_number ASC` でソート）
3. 試合の削除（CASCADE削除により関連データも自動削除）

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
         │ N
┌────────▼────────┐
│  game_scores     │
├──────────────────┤
│ id (PK)         │
│ match_id (FK)   │
│ game_number     │
│ team1_score     │
│ team2_score     │
│ service_team    │
│ winner          │
└──────────────────┘

┌─────────────────┐
│   set_scores     │
├─────────────────┤
│ id (PK)         │
│ match_id (FK)   │
│ set_number      │
│ team1_score     │
│ team2_score     │
│ winner          │
└─────────────────┘
```

---

## 9. データ整合性

### 9.1 外部キー制約

- `game_scores.match_id` → `matches.id` (CASCADE削除)
- `set_scores.match_id` → `matches.id` (CASCADE削除)

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
