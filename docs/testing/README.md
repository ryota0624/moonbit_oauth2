# テストドキュメント

このディレクトリには、OAuth2 実装のテストに関するドキュメントが含まれています。

## 📚 ドキュメント一覧

### 1. [Keycloak 動作検証手順書](./keycloak_verification_guide.md)

**概要**: 本番環境に近い Keycloak を使用した包括的な動作検証手順

**内容**:
- Keycloak の初期設定（レルム、クライアント、ユーザー作成）
- 全 OAuth2 フロー（Authorization Code、Client Credentials、Password Grant）の検証
- トークンの検証とデバッグ方法
- エラーハンドリングのテスト
- トラブルシューティング

**対象者**:
- 統合テストを実施する開発者
- 本番環境前の検証を行う QA エンジニア
- OAuth2 実装の詳細を理解したい方

**所要時間**: 30-60分

---

## 🚀 クイックスタート

### Option 1: MoonBit スクリプトで検証（推奨）

**OAuth2 ライブラリの完全な動作検証：**

```bash
# 1. Keycloak を起動し、初期設定を自動実行
./scripts/setup_keycloak.sh

# 2. MoonBit OAuth2 実装で全フローをテスト
./scripts/test_keycloak_moonbit.sh
```

**または直接実行:**
```bash
# Client Secret を設定して直接実行
export CLIENT_SECRET="your-secret"
moon run lib/keycloak_test
```

### Option 2: curl スクリプトで検証

**シンプルな動作確認（依存関係最小）：**

```bash
# 1. Keycloak を起動し、初期設定を自動実行
./scripts/setup_keycloak.sh

# 2. curl で OAuth2 フローをテスト
./scripts/test_keycloak_flows.sh
```


---

## 🧪 テスト方法の比較

### テストツール

| 項目 | MoonBit スクリプト | curl スクリプト |
|------|--------------------|----------------|
| **実行コマンド** | `./scripts/test_keycloak_moonbit.sh` | `./scripts/test_keycloak_flows.sh` |
| **検証対象** | OAuth2 ライブラリの実装 | Keycloak の動作 |
| **依存関係** | MoonBit, OAuth2 ライブラリ | curl, jq |
| **メリット** | 型安全、ライブラリ検証 | シンプル、デバッグ容易 |
| **推奨用途** | ライブラリ開発・検証 | インフラ動作確認 |

### 推奨フロー

- 🟢 **ライブラリ開発**: MoonBit スクリプト + Keycloak
- 🟢 **統合テスト**: MoonBit スクリプト + Keycloak
- 🟡 **インフラ確認**: curl スクリプト + Keycloak

---

## 📋 テストチェックリスト

### 基本動作確認

- [ ] Client Credentials Flow でトークンが取得できる
- [ ] Password Grant Flow でトークンが取得できる
- [ ] Authorization Code Flow で認可 URL が生成できる
- [ ] 取得したトークンが有効な JWT 形式である
- [ ] トークンに適切なクレーム（exp, iss, aud 等）が含まれる

### エラーハンドリング

- [ ] 無効なクライアント認証情報でエラーが返る
- [ ] 無効なユーザー認証情報でエラーが返る
- [ ] 無効な認可コードでエラーが返る
- [ ] エラーレスポンスが OAuth2 仕様に準拠している

### PKCE 検証

- [ ] PKCE の code_challenge が正しく生成される
- [ ] code_verifier が正しく検証される
- [ ] PKCE なしの認可リクエストが拒否される（設定による）

### セキュリティ検証

- [ ] CSRF トークンが予測不可能である
- [ ] PKCE code_verifier が暗号学的に安全である
- [ ] トークンが適切な有効期限を持つ
- [ ] リフレッシュトークンが正しく動作する

---

## 🛠️ テストツール

### 1. スクリプト

| スクリプト | 用途 | 実行時間 | 推奨度 |
|-----------|------|---------|--------|
| `setup_keycloak.sh` | Keycloak の自動セットアップ | 約1分 | ⭐⭐⭐ |
| `test_keycloak_moonbit.sh` | MoonBit OAuth2 ライブラリ検証 | 約30秒 | ⭐⭐⭐ |
| `test_keycloak_flows.sh` | curl での OAuth2 フロー確認 | 約30秒 | ⭐⭐ |

### 2. 手動テストツール

- **curl**: コマンドラインでの HTTP リクエストテスト
- **jq**: JSON レスポンスの整形・解析
- **ブラウザ**: Authorization Code Flow のテスト
- **Keycloak 管理コンソール**: 設定確認・デバッグ

### 3. デバッグツール

- **jwt.io**: JWT トークンのデコード・検証
- **Postman**: GUI ベースの HTTP クライアント
- **Keycloak ログ**: `docker compose logs -f keycloak`

---

## 📖 関連ドキュメント

### プロジェクト内

- [CLAUDE.md](../../CLAUDE.md): 開発ガイドライン
- [README.mbt.md](../../README.mbt.md): プロジェクト概要
- [完了報告](../completed/): 実装完了レポート

### 外部リソース

- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [Keycloak Documentation](https://www.keycloak.org/documentation)

---

## 💡 Tips

### よくある質問

**Q: テストが失敗する場合は？**

A: トラブルシューティングセクションを確認してください：
- [Keycloak 検証ガイド - トラブルシューティング](./keycloak_verification_guide.md#トラブルシューティング)

**Q: Keycloak と mock-oauth2-server のどちらを使うべき？**

A: 開発フェーズに応じて使い分けてください：
- 開発初期・単体テスト: mock-oauth2-server（軽量・高速）
- 統合テスト・本番前検証: Keycloak（本番相当）

**Q: CI/CD に組み込むには？**

A: 統合テストガイドを参照してください：
- [統合テストガイド - CI/CD 統合](./integration_test_guide.md)

### パフォーマンスベンチマーク

参考値（MacBook Pro M1, 16GB RAM）:

- mock-oauth2-server 起動: < 5秒
- Keycloak 起動: 約30秒
- トークン取得（mock-oauth2): < 100ms
- トークン取得（Keycloak): < 500ms
- 統合テスト CLI 実行: 約10秒

---

## 🔄 更新履歴

- **2026-02-15**: 初版作成
  - Keycloak 検証手順書を追加
  - 自動セットアップスクリプトを追加
  - テストスクリプトを追加
