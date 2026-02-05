# iOSアプリリリース手順

VALVEアプリをApp Storeにリリースするための完全な手順です。

---

## 📋 前提条件

### 1. Xcodeのインストール

```bash
# App Storeから「Xcode」をインストール（約12GB）
# インストール後、以下を実行：

sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

確認：
```bash
flutter doctor
```

`✓ Xcode` と表示されればOKです。

### 2. Apple Developer アカウント

1. https://developer.apple.com/ にアクセス
2. Apple IDでサインイン
3. **Apple Developer Program** に登録（年間99ドル）
4. 登録完了まで数時間～1日かかる場合があります

---

## 🔧 設定の確認

### 現在の設定

- **アプリ名**: VALVE ✅
- **Bundle Identifier**: `com.onoikuto.valve` ✅
- **バージョン**: 1.0.1+6 ✅
- **Google Mobile Ads**: 設定済み ✅

---

## 📱 ステップ1: Xcodeでプロジェクトを開く

```bash
cd /Users/ononono/soft-tennis-pj_frontend
open ios/Runner.xcworkspace
```

**重要**: `.xcworkspace` を開くこと（`.xcodeproj` ではない）

---

## 🔐 ステップ2: Signing & Capabilitiesの設定

Xcodeで：

1. 左側のプロジェクトナビゲーターで **「Runner」** を選択
2. 中央の **「Signing & Capabilities」** タブをクリック
3. 以下の設定を行う：

   - **Team**: Apple Developer アカウントを選択
   - **Bundle Identifier**: `com.onoikuto.valve`（既に設定済み）
   - **Automatically manage signing**: ✅ チェックを入れる

4. エラーが出た場合：
   - 「Add Account」をクリックしてApple IDを追加
   - または、Apple Developer アカウントの確認

---

## 🧪 ステップ3: シミュレーターでテスト

```bash
# iOSシミュレーターを起動
open -a Simulator

# アプリを実行
flutter run -d ios
```

または、Xcodeで：
1. 上部のデバイス選択で「iPhone 15 Pro」などを選択
2. ▶️ ボタンをクリックして実行

---

## 📦 ステップ4: リリースビルド

### 方法1: Flutterコマンド（推奨）

```bash
cd /Users/ononono/soft-tennis-pj_frontend
flutter build ipa --release
```

IPAファイルの場所：
```
/Users/ononono/soft-tennis-pj_frontend/build/ios/ipa/soft_tennis_scoring.ipa
```

### 方法2: Xcodeから（詳細設定が必要な場合）

1. Xcodeで **「Product」** → **「Archive」** を選択
2. アーカイブが完了するまで待つ（数分）
3. **Organizer** ウィンドウが開く
4. **「Distribute App」** をクリック
5. **「App Store Connect」** を選択
6. **「Upload」** を選択
7. オプションを確認して **「Upload」** をクリック

---

## 🏪 ステップ5: App Store Connectでアプリ登録

### 5.1 アプリの作成

1. https://appstoreconnect.apple.com/ にアクセス
2. **「マイApp」** → **「+」** → **「新規App」** をクリック
3. 以下の情報を入力：

   - **プラットフォーム**: iOS
   - **名前**: VALVE
   - **プライマリ言語**: 日本語
   - **バンドルID**: `com.onoikuto.valve`
   - **SKU**: `valve-ios`（任意のユニークな文字列）
   - **ユーザーアクセス**: フルアクセス

4. **「作成」** をクリック

### 5.2 アプリ情報の入力

#### 基本情報

- **名前**: VALVE
- **サブタイトル**: ソフトテニス採点アプリ
- **カテゴリ**:
  - プライマリ: **スポーツ**
  - セカンダリ: **ユーティリティ**（オプション）

#### 価格と販売地域

- **価格**: 無料
- **販売地域**: すべての地域（または選択）

#### プライバシー

- **プライバシーポリシーURL**: 必須（後述）
- **データ収集**: 
  - 使用状況データ: はい（統計データ）
  - 広告データ: はい（Google Mobile Ads）

---

## 📸 ステップ6: スクリーンショットの準備

### 必要なサイズ

1. **6.5インチ（iPhone 15 Pro Max）**: 1290 x 2796 px
2. **6.1インチ（iPhone 15 Pro）**: 1179 x 2556 px
3. **5.5インチ（iPhone 8 Plus）**: 1242 x 2208 px
4. **12.9インチ iPad Pro**: 2048 x 2732 px

### スクリーンショットの撮影方法

#### 方法1: iOSシミュレーターを使用

1. Xcodeでシミュレーターを起動
2. デバイスを選択（例: iPhone 15 Pro Max）
3. アプリを実行
4. 各画面でスクリーンショットを撮影：
   - `Cmd + S` でスクリーンショット保存
   - または、メニュー「Device」→「Screenshot」

#### 方法2: 実機を使用

1. iPhone/iPadでアプリを実行
2. スクリーンショットを撮影：
   - iPhone X以降: サイドボタン + 音量上ボタン
   - iPhone 8以前: ホームボタン + サイドボタン

### 推奨する画面

1. メインメニュー画面
2. 試合設定画面
3. 採点画面（スコア入力中）
4. 試合履歴画面
5. 統計画面

---

## 📝 ステップ7: アプリの説明文

### タイトル
```
VALVE - ソフトテニス採点アプリ
```

### サブタイトル
```
試合のスコア記録と統計分析
```

### 説明文（日本語）

```
VALVEは、ソフトテニスの試合スコアを簡単に記録・管理できるアプリです。

【主な機能】
✓ 簡単なスコア入力
   - 直感的な操作で試合のスコアを記録
   - ゲーム数、セット数を自動計算

✓ 詳細な統計分析
   - ペア単位、選手単位の統計
   - ゲーム別の勝率
   - サーブ・レシーブ別の取得率（プレミアム機能）

✓ 試合履歴管理
   - 過去の試合を一覧表示
   - 試合の詳細情報を確認

✓ オフライン対応
   - インターネット接続なしでも使用可能
   - データは端末内に安全に保存

【プレミアム機能】
広告非表示、詳細な統計データ、ポイントごとの詳細記録など、より充実した機能をご利用いただけます。

シンプルで使いやすいデザインで、ソフトテニスの試合管理をサポートします。
```

### キーワード（100文字以内）

```
ソフトテニス,採点,スコア,試合,統計,テニス,スポーツ,記録,管理,分析
```

---

## 🔒 ステップ8: プライバシーポリシーの作成

App Storeでは**プライバシーポリシーのURL**が必須です。

### 必要な内容

1. **収集するデータ**
   - 使用状況データ（統計情報）
   - 広告ID（Google Mobile Ads）

2. **データの使用目的**
   - アプリの機能提供
   - 広告の表示

3. **データの保存期間**
   - ユーザーが削除するまで

4. **ユーザーの権利**
   - データの削除権
   - アクセス権

### プライバシーポリシーのホスティング

以下のいずれかでホスティング：

1. **GitHub Pages**（無料）
2. **Firebase Hosting**（無料）
3. **独自のWebサイト**
4. **プライバシーポリシー生成サービス**

---

## 📤 ステップ9: アプリのアップロード

### 方法1: Transporter（推奨）

1. App Storeから **「Transporter」** をインストール
2. Transporterを起動
3. IPAファイルをドラッグ&ドロップ
4. **「配信」** をクリック

### 方法2: Xcodeから

1. Xcodeで **「Product」** → **「Archive」**
2. **「Distribute App」** → **「App Store Connect」**
3. **「Upload」** を選択
4. アップロード

### 方法3: コマンドライン

```bash
# Xcodeのコマンドラインツールを使用
xcrun altool --upload-app --type ios --file build/ios/ipa/soft_tennis_scoring.ipa --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID
```

---

## ✅ ステップ10: 審査に提出

1. App Store Connectでアプリを開く
2. **「バージョン」** を選択
3. すべての情報を入力：
   - スクリーンショット
   - 説明文
   - キーワード
   - プライバシーポリシーURL
   - 年齢制限（4+）
   - 連絡先情報

4. **「審査に提出」** ボタンをクリック

---

## ⏱️ 審査プロセス

- **初回審査**: 通常1～3日
- **更新審査**: 通常24時間以内
- **却下された場合**: 理由を確認して修正

---

## 📋 チェックリスト

### 事前準備
- [ ] Xcodeがインストールされている
- [ ] Apple Developer アカウントに登録済み
- [ ] Bundle Identifierが `com.onoikuto.valve` に設定されている
- [ ] Signing & Capabilitiesが正しく設定されている

### アプリ情報
- [ ] アプリ名が「VALVE」に設定されている
- [ ] バージョンが 1.0.1+6 になっている
- [ ] アプリアイコンが設定されている（1024 x 1024 px）

### スクリーンショット
- [ ] 6.5インチ用のスクリーンショット（1290 x 2796 px）
- [ ] 6.1インチ用のスクリーンショット（1179 x 2556 px）
- [ ] 5.5インチ用のスクリーンショット（1242 x 2208 px）
- [ ] 12.9インチ iPad用のスクリーンショット（2048 x 2732 px）

### App Store Connect
- [ ] アプリが作成されている
- [ ] 基本情報が入力されている
- [ ] 説明文が入力されている
- [ ] キーワードが入力されている
- [ ] プライバシーポリシーURLが設定されている
- [ ] カテゴリが選択されている

### ビルドとアップロード
- [ ] リリースビルドが成功している
- [ ] IPAファイルが生成されている
- [ ] App Store Connectにアップロードされている
- [ ] ビルドが処理完了している

### 審査提出
- [ ] すべての情報が入力されている
- [ ] スクリーンショットがアップロードされている
- [ ] プライバシーポリシーが公開されている
- [ ] 「審査に提出」ボタンをクリック

---

## 🐛 トラブルシューティング

### Signingエラー

**エラー**: "No signing certificate found"

**解決方法**:
1. Xcodeで **「Preferences」** → **「Accounts」**
2. Apple IDを追加
3. **「Download Manual Profiles」** をクリック

### ビルドエラー

**エラー**: "CocoaPods not installed"

**解決方法**:
```bash
sudo gem install cocoapods
cd ios
pod install
```

### アップロードエラー

**エラー**: "Invalid Bundle"

**解決方法**:
1. Bundle Identifierが正しいか確認
2. バージョン番号が正しいか確認
3. 署名が正しく設定されているか確認

---

## 📚 参考リンク

- [Apple Developer](https://developer.apple.com/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [App Store審査ガイドライン](https://developer.apple.com/app-store/review/guidelines/)
- [Flutter iOS デプロイ](https://docs.flutter.dev/deployment/ios)

---

## 🎉 リリース後の確認

1. App Storeでアプリを検索
2. ダウンロードして動作確認
3. レビューを確認
4. クラッシュレポートを確認（App Store Connect）

---

## 📝 次のステップ

リリース後は：

1. **アップデートの準備**
   - バージョン番号を更新（1.0.2+7 など）
   - 変更内容を記録

2. **マーケティング**
   - SNSで告知
   - ユーザーレビューへの対応

3. **改善**
   - ユーザーフィードバックを収集
   - 機能追加やバグ修正
