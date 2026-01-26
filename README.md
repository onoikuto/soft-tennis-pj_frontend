# VALVE - ソフトテニス採点アプリ

FlutterとSQLiteを使用したソフトテニスの採点表管理アプリです。オフラインで動作し、ローカルデータベースにマッチとスコアを保存します。

## アプリ情報

- **アプリ名**: VALVE
- **アプリID**: `com.onoikuto.valve`
- **バージョン**: 1.0.0+1
- **プラットフォーム**: iOS, Android, Web, macOS

## 主な機能

### 基本機能
- マッチの作成・管理
- プレイヤー名の登録（チーム1とチーム2、各2名）
- ゲームスコアの記録（5ゲーム、7ゲーム、9ゲームマッチ対応）
- ファイナルゲームの自動判定
- マッチ履歴の表示
- マッチの完了・勝利チームの記録

### 統計機能
- ペア単位の統計
- 学校・クラブ単位の統計
- 選手単位の統計
- ゲーム別の勝率
- デュース時取得率（プレミアム機能）
- サーブ・レシーブ別取得率（プレミアム機能）
- ファイナルゲーム取得率（プレミアム機能）
- データインサイト（プレミアム機能）

### プレミアム機能（サブスクリプション）
- 広告非表示
- 詳細な統計データの表示
- 詳細入力モード（ポイントごとの詳細記録）
  - 1stサーブの入/不入
  - ポイント種類（エース、ウィナー、相手のミス）
  - 選手名の記録

### マスター管理機能
- 選手マスターの管理（追加、編集、削除）
- 所属チームマスターの管理（追加、編集、削除）

### データ管理機能
- データのエクスポート（CSV形式）
- データのインポート（CSV形式）

## 必要な環境

- Flutter SDK (3.0.0以上)
- Dart SDK
- Android Studio / Xcode (iOS開発の場合)
- Java JDK (Androidビルド用)

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

3. Android設定（Androidビルドの場合）
   - `android/app/build.gradle.kts` でアプリIDを確認
   - `android/key.properties` でリリース署名設定（本番環境）

4. アプリの実行
   ```bash
   # Android
   flutter run

   # iOS
   flutter run

   # Web
   flutter run -d chrome

   # macOS
   flutter run -d macos

   # 特定のデバイスを指定する場合
   flutter devices  # 利用可能なデバイスを確認
   flutter run -d <device_id>
   ```

## リリースビルド

### Android App Bundle (AAB)
```bash
flutter build appbundle
```
出力: `build/app/outputs/bundle/release/app-release.aab`

### Android APK
```bash
flutter build apk --release
```
出力: `build/app/outputs/flutter-apk/app-release.apk`

### iOS
```bash
flutter build ios --release
```

## プロジェクト構造

```
lib/
├── main.dart                 # アプリのエントリーポイント
├── models/                  # データモデル
│   ├── match.dart          # マッチモデル
│   ├── game_score.dart     # ゲームスコアモデル
│   ├── set_score.dart      # セットスコアモデル（未使用）
│   └── point_detail.dart   # ポイント詳細モデル
├── database/                # データベース関連
│   └── database_helper.dart # SQLiteヘルパークラス
├── screens/                 # 画面
│   ├── main_menu_screen.dart
│   ├── match_setup_screen.dart
│   ├── official_scoring_screen.dart
│   ├── match_history_screen.dart
│   ├── statistics_screen.dart
│   ├── my_page_screen.dart
│   ├── subscription_screen.dart
│   ├── privacy_policy_screen.dart
│   ├── master_management_screen.dart
│   ├── player_management_screen.dart
│   ├── club_management_screen.dart
│   └── backup_screen.dart
├── services/                # ビジネスロジック
│   └── subscription_service.dart
└── widgets/                 # 再利用可能なウィジェット
    ├── common/
    │   ├── bottom_navigation_bar.dart
    │   └── simple_button.dart
    └── score_input_dialog.dart
```

## データベース構造

詳細は [DB設計書](./docs/DB設計書.md) を参照してください。

### 主要テーブル

- **matches**: 試合情報
- **game_scores**: ゲームスコア
- **point_details**: ポイント詳細（プレミアム機能）
- **players**: 選手マスター
- **clubs**: 所属チームマスター
- **set_scores**: セットスコア（現在未使用）

## 使用パッケージ

### コアパッケージ
- `sqflite`: SQLiteデータベース操作
- `sqflite_common_ffi`: デスクトップ版SQLiteサポート
- `sqflite_common_ffi_web`: Web版SQLiteサポート
- `path`: パス操作
- `intl`: 日時フォーマット
- `shared_preferences`: ユーザー設定の保存

### UI/UX
- `flutter`: Flutter SDK
- `cupertino_icons`: iOSスタイルのアイコン

### 広告・課金
- `google_mobile_ads`: Google Mobile Ads（広告表示）
- `in_app_purchase`: アプリ内課金（現在コメントアウト、将来実装）

### その他
- `url_launcher`: URL起動（メールアプリなど）

## ドキュメント

- [DB設計書](./docs/DB設計書.md) - データベース構造の詳細
- [画面設計書](./docs/画面設計書.md) - 各画面の設計と機能
- [コード解説書](./docs/コード解説書.md) - コードの解説と学習資料

## 広告とサブスクリプション

### 広告
- **実装**: Google Mobile Ads
- **表示箇所**: 統計画面の下部
- **条件**: サブスクリプション未購入時のみ表示
- **テストID**: `ca-app-pub-3940256099942544/6300978111`

### サブスクリプション
- **現在の実装**: テスト用（`SharedPreferences`で状態管理）
- **将来実装**: `in_app_purchase` を使用した本番実装が必要
- **機能**: 広告非表示、詳細統計、詳細入力モード

## エラーハンドリング

アプリ全体で以下のエラーハンドリングを実装しています：

- `runZonedGuarded`: 予期しないエラーをキャッチ
- `FlutterError.onError`: Flutterエラーをキャッチ
- `ErrorWidget.builder`: カスタムエラー画面を表示

## プラットフォーム対応

### Android
- 最小SDK: Flutterデフォルト
- ターゲットSDK: Flutterデフォルト
- アプリID: `com.onoikuto.valve`
- アプリ名: "VALVE"

### iOS
- 最小バージョン: Flutterデフォルト
- Bundle ID: `com.onoikuto.valve`

### Web
- データベース: IndexedDBを使用
- 広告: 表示しない

### macOS
- データベース: SQLite FFIを使用
- 広告: 表示しない
- サブスクリプション: 手動で有効化可能（テスト用）

## ライセンス

このプロジェクトは個人利用を目的としています。

## 更新履歴

### Version 1.0.0+1
- 初回リリース
- 基本機能の実装
- プレミアム機能の実装（テスト用）
- 広告機能の実装
