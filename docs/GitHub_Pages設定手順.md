# GitHub Pages設定手順

GitHub Pagesで404エラーが発生している場合の対処方法です。

## 現在の状況

- リポジトリURL: `https://github.com/onoikuto/soft-tennis-pj_frontend`
- GitHub Pages URL: `https://onoikuto.github.io/soft-tennis-pj_frontend/`
- 404エラーが発生している

## 解決手順

### 1. GitHub Pagesの設定を確認・変更

1. GitHubリポジトリ（https://github.com/onoikuto/soft-tennis-pj_frontend）にアクセス
2. 「Settings」タブをクリック
3. 左側のメニューから「Pages」を選択
4. 「Source」セクションで以下を確認：
   - **現在の設定が「None」の場合**:
     - 「Deploy from a branch」を選択
     - 「Branch」で「main」または「master」を選択（現在のブランチ名を確認）
     - 「/ (root)」を選択
     - 「Save」をクリック
   - **現在の設定が「Deploy from a branch」の場合**:
     - 「/docs」フォルダを選択
     - 「Save」をクリック

### 2. ファイルの配置確認

以下のファイルが `docs` フォルダに存在することを確認：
- `docs/privacy_policy.html`
- `docs/terms_of_service.html`

### 3. ファイルをGitHubにプッシュ

```bash
cd /Users/ononono/soft-tennis-pj_frontend

# 変更を確認
git status

# 変更をステージング
git add docs/privacy_policy.html docs/terms_of_service.html docs/利用規約公開手順.md docs/プライバシーポリシー公開手順.md lib/screens/subscription_screen.dart

# コミット
git commit -m "Add Terms of Service and update GitHub Pages URLs"

# プッシュ（現在のブランチに）
git push origin feature/soft_tennis_pj_ph1
```

**重要**: GitHub Pagesは通常、`main` または `master` ブランチからデプロイされます。現在のブランチが `feature/soft_tennis_pj_ph1` の場合、以下のいずれかが必要です：

#### オプションA: mainブランチにマージ
```bash
# mainブランチに切り替え
git checkout main

# featureブランチをマージ
git merge feature/soft_tennis_pj_ph1

# プッシュ
git push origin main
```

#### オプションB: GitHub Pagesの設定を変更
1. GitHubリポジトリの「Settings」→「Pages」
2. 「Source」で「Deploy from a branch」を選択
3. 「Branch」で `feature/soft_tennis_pj_ph1` を選択
4. 「/docs」フォルダを選択
5. 「Save」をクリック

### 4. GitHub Pagesの反映を待つ

- プッシュ後、GitHub Pagesの反映には通常 **5-10分** かかります
- 「Settings」→「Pages」でデプロイ状況を確認できます

### 5. URLの確認

反映後、以下のURLにアクセスして確認してください：

**プライバシーポリシー:**
```
https://onoikuto.github.io/soft-tennis-pj_frontend/privacy_policy.html
```

**利用規約:**
```
https://onoikuto.github.io/soft-tennis-pj_frontend/terms_of_service.html
```

### 6. まだ404エラーが出る場合

#### 確認事項：
1. **ブランチ名**: GitHub Pagesの設定で正しいブランチが選択されているか
2. **フォルダパス**: `/docs` フォルダがソースとして設定されているか
3. **ファイル名**: ファイル名の大文字小文字が正しいか（`terms_of_service.html` など）
4. **デプロイ状況**: 「Settings」→「Pages」でエラーメッセージがないか確認

#### トラブルシューティング：
- GitHub Pagesの設定を一度「None」に戻してから再度設定
- ブラウザのキャッシュをクリア（`Cmd + Shift + R`）
- 別のブラウザで確認

## 正しいURL一覧

以下のURLを使用してください：

- **プライバシーポリシー**: `https://onoikuto.github.io/soft-tennis-pj_frontend/privacy_policy.html`
- **利用規約**: `https://onoikuto.github.io/soft-tennis-pj_frontend/terms_of_service.html`

これらのURLをApp Store Connectのメタデータに設定してください。
