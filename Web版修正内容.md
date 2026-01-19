# Web版での表示問題の修正

## 問題
- `sqflite`パッケージはWeb版では直接動作しない
- ブラウザで何も表示されない

## 修正内容

### 1. パッケージの追加
`pubspec.yaml`に以下を追加：
- `sqflite_common_ffi`: デスクトップ版用
- `sqflite_common_ffi_web`: Web版用

### 2. データベースヘルパーの修正
`lib/database/database_helper.dart`を修正：
- Web版とデスクトップ版を自動判定
- Web版では`databaseFactoryFfiWeb`を使用
- デスクトップ版では`databaseFactoryFfi`を使用

### 3. エラーハンドリングの追加
`lib/main.dart`にエラーハンドリングを追加：
- データベース初期化エラーが発生してもアプリが起動するように

## 次のステップ

以下のコマンドを実行してください：

```bash
cd /Users/ononono/soft-tennis-pj_frontend
export PATH="$PATH:/Users/ononono/soft-tennis-pj_frontend/flutter/bin"

# 依存関係を再インストール
flutter pub get

# アプリを再実行
flutter run -d chrome
```

## 確認事項

ブラウザの開発者ツール（F12）でコンソールを確認：
- エラーが表示されていないか確認
- データベースの初期化が成功しているか確認
