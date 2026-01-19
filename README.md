# ソフトテニス採点表アプリ

FlutterとSQLiteを使用したソフトテニスの採点表管理アプリです。オフラインで動作し、ローカルデータベースにマッチとスコアを保存します。

## 機能

- マッチの作成・管理
- プレイヤー名の登録（チーム1とチーム2、各2名）
- セットスコアの記録
- マッチ履歴の表示
- マッチの完了・勝利チームの記録

## 必要な環境

- Flutter SDK (3.0.0以上)
- Dart SDK
- Android Studio / Xcode (iOS開発の場合)

## セットアップ手順

1. Flutterのインストール（未インストールの場合）
   ```bash
   # Flutterの公式サイトからインストール
   # https://flutter.dev/docs/get-started/install
   ```

2. 依存関係のインストール
   ```bash
   flutter pub get
   ```

3. アプリの実行
   ```bash
   # Android
   flutter run

   # iOS
   flutter run

   # 特定のデバイスを指定する場合
   flutter devices  # 利用可能なデバイスを確認
   flutter run -d <device_id>
   ```

## プロジェクト構造

```
lib/
├── main.dart                 # アプリのエントリーポイント
├── models/                  # データモデル
│   ├── match.dart          # マッチモデル
│   └── set_score.dart      # セットスコアモデル
├── database/                # データベース関連
│   └── database_helper.dart # SQLiteヘルパークラス
├── screens/                 # 画面
│   ├── home_screen.dart    # ホーム画面（マッチ一覧）
│   ├── new_match_screen.dart # 新規マッチ作成画面
│   └── match_detail_screen.dart # マッチ詳細画面
└── widgets/                 # 再利用可能なウィジェット
    └── score_input_dialog.dart # スコア入力ダイアログ
```

## データベース構造

### matches テーブル
- id: 主キー
- team1_player1: チーム1のプレイヤー1
- team1_player2: チーム1のプレイヤー2
- team2_player1: チーム2のプレイヤー1
- team2_player2: チーム2のプレイヤー2
- created_at: 作成日時
- completed_at: 完了日時（null可能）
- winner: 勝利チーム（'team1' or 'team2' or null）

### set_scores テーブル
- id: 主キー
- match_id: マッチID（外部キー）
- set_number: セット番号
- team1_score: チーム1のスコア
- team2_score: チーム2のスコア
- winner: セットの勝利チーム（'team1' or 'team2'）

## 使用パッケージ

- `sqflite`: SQLiteデータベース操作
- `path`: パス操作
- `intl`: 日時フォーマット

## ライセンス

このプロジェクトは個人利用を目的としています。