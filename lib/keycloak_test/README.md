# Keycloak OAuth2 検証 (MoonBit 版)

MoonBit の OAuth2 実装を使用して Keycloak の動作を検証するテストプログラムです。

## 概要

このプログラムは以下の OAuth2 フローを実際の MoonBit コードでテストします：

1. **Client Credentials Flow**: Machine-to-Machine 認証
2. **Password Grant Flow**: ユーザー認証情報による直接的なトークン取得
3. **Authorization Code Flow (準備)**: 認可 URL の生成と検証
4. **エラーハンドリング**: 無効な認証情報でのエラーレスポンス検証

## 前提条件

- Keycloak が起動していること
- test-realm、test-client、testuser が設定されていること
- Client Secret を取得していること

### クイックセットアップ

```bash
# Keycloak を起動・設定（自動）
./scripts/setup_keycloak.sh
```

## 使用方法

### Option 1: スクリプト経由で実行（推奨）

```bash
# Client Secret を自動取得して実行
./scripts/test_keycloak_moonbit.sh
```

スクリプトが自動的に：
1. Client Secret を Keycloak API から取得
2. MoonBit プログラムをビルド
3. テストを実行

### Option 2: 手動で実行

```bash
# 1. Client Secret を環境変数に設定
export CLIENT_SECRET="your-client-secret-here"

# 2. ビルド
moon build --target native lib/keycloak_test/main.mbt

# 3. 実行
./target/native/debug/build/keycloak_test/keycloak_test.exe
```

### Option 3: カスタム設定で実行

環境変数で設定をカスタマイズ：

```bash
export KEYCLOAK_REALM="my-realm"
export KEYCLOAK_BASE_URL="http://localhost:8080/realms/my-realm"
export TOKEN_ENDPOINT="${KEYCLOAK_BASE_URL}/protocol/openid-connect/token"
export CLIENT_ID="my-client"
export CLIENT_SECRET="my-secret"
export TEST_USERNAME="myuser"
export TEST_PASSWORD="mypassword"

./scripts/test_keycloak_moonbit.sh
```

## 環境変数

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `KEYCLOAK_REALM` | `test-realm` | Keycloak レルム名 |
| `KEYCLOAK_BASE_URL` | `http://localhost:8080/realms/test-realm` | Keycloak ベース URL |
| `TOKEN_ENDPOINT` | `${KEYCLOAK_BASE_URL}/protocol/openid-connect/token` | トークンエンドポイント |
| `CLIENT_ID` | `test-client` | OAuth2 クライアント ID |
| `CLIENT_SECRET` | **(必須)** | OAuth2 クライアントシークレット |
| `TEST_USERNAME` | `testuser` | テストユーザー名 |
| `TEST_PASSWORD` | `testpass123` | テストユーザーパスワード |

## 出力例

```
============================================================
Keycloak OAuth2 検証スクリプト (MoonBit)
============================================================

📋 設定:
  Realm: test-realm
  Base URL: http://localhost:8080/realms/test-realm
  Token Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/token
  Client ID: test-client
  Client Secret: a1b2c3d4e5...
  Test User: testuser

============================================================
Test 1: Client Credentials Flow
============================================================
Token Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/token
Client ID: test-client

リクエスト送信中...
[✓ 成功] トークン取得

📋 トークン情報:
  Token Type: Bearer
  Expires In: 300秒
  Access Token (先頭50文字): eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE...
  Scope: openid
[✓ 成功] JWT 形式
[✓ 成功] 有効期限
  expires_in=300秒

============================================================
Test 2: Password Grant Flow
============================================================
...
```

## テスト項目

### 1. Client Credentials Flow
- ✅ トークン取得の成功
- ✅ JWT 形式の検証
- ✅ 有効期限の検証
- ✅ Token Type の確認
- ✅ Scope の確認

### 2. Password Grant Flow
- ✅ Access Token 取得
- ✅ Refresh Token 取得
- ✅ ID Token 取得（OpenID Connect）
- ✅ JWT 形式の検証
- ✅ ユーザー情報の確認

### 3. Authorization Code Flow（準備）
- ✅ 認可 URL の生成
- ✅ PKCE code_challenge の生成
- ✅ 必須パラメータの確認
  - client_id
  - redirect_uri
  - scope
  - state
  - code_challenge

### 4. エラーハンドリング
- ✅ 無効な Client Secret でのエラー
- ✅ 無効なユーザー認証情報でのエラー
- ✅ OAuth2 仕様準拠のエラーレスポンス

## トラブルシューティング

### ビルドエラー

**症状**: `moon build` が失敗する

**対処**:
```bash
# 依存関係を更新
moon install

# クリーンビルド
rm -rf target/
moon build --target native lib/keycloak_test/main.mbt
```

### CLIENT_SECRET エラー

**症状**: "CLIENT_SECRET が設定されていません"

**対処**:
```bash
# セットアップスクリプトを実行
./scripts/setup_keycloak.sh

# 出力された Client Secret をコピーして設定
export CLIENT_SECRET="your-client-secret-here"
```

### 接続エラー

**症状**: "ネットワークエラー: Connection refused"

**対処**:
```bash
# Keycloak が起動しているか確認
docker compose ps

# 起動していない場合
docker compose up -d keycloak postgres

# ログを確認
docker compose logs -f keycloak
```

### InvalidClient エラー

**症状**: "無効なクライアント"

**原因**: Client Secret が間違っている、またはクライアントが存在しない

**対処**:
1. Keycloak 管理コンソールで設定を確認
   - http://localhost:8080/admin
2. セットアップスクリプトを再実行
   ```bash
   ./scripts/setup_keycloak.sh
   ```

## 実装の詳細

### 使用している OAuth2 ライブラリ

- `@oauth2.ClientCredentialsRequest`: Client Credentials Flow
- `@oauth2.PasswordRequest`: Password Grant Flow
- `@oauth2.AuthorizationRequest`: Authorization Code Flow
- エラー型: `@oauth2.OAuthError`

### HTTP クライアント

- `mizchi/x/http`: Native/JS 両対応の HTTP クライアント
- RFC 7230 準拠（Content-Length/Transfer-Encoding/PassThrough 対応）

### セキュリティ

- PKCE (Proof Key for Code Exchange) サポート
- Chacha8 CSPRNG による安全な乱数生成
- CSRF トークン生成

## 関連ドキュメント

- [Keycloak 検証手順書](../../docs/testing/keycloak_verification_guide.md)
- [テストドキュメント概要](../../docs/testing/README.md)
- [OAuth2 実装完了報告](../../docs/completed/)

## 開発

### テストの追加

新しいテストケースを追加する場合:

```moonbit
///|
/// 新しいテスト関数
async fn test_new_feature(config : Config) -> Unit {
  print_separator("Test X: 新機能")

  try {
    // テストロジック
    print_result("テスト項目", true, "詳細メッセージ")
  } catch {
    err => print_result("テスト項目", false, "エラー: \{err}")
  }
}

///|
/// main から呼び出し
async fn main() -> Unit {
  // ...
  test_new_feature(config)
  // ...
}
```

### デバッグ

詳細なログを有効にする:

```moonbit
// デバッグ用の println を追加
println("[DEBUG] Request: \{request}")
println("[DEBUG] Response: \{response}")
```

## ライセンス

Apache-2.0
