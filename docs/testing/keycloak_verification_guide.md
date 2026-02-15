# Keycloak を使った OAuth2 実装の動作検証手順書

このドキュメントでは、本番環境に近い Keycloak を使用して、OAuth2 実装の動作を検証する手順を説明します。

## 目次

1. [環境構築](#環境構築)
2. [Keycloak 初期設定](#keycloak-初期設定)
3. [動作検証](#動作検証)
4. [トラブルシューティング](#トラブルシューティング)

---

## 環境構築

### 必要な環境

- Docker & Docker Compose
- MoonBit (moon CLI)
- ブラウザ（Keycloak 管理コンソール用）

### Keycloak の起動

```bash
# Keycloak と PostgreSQL を起動
docker compose up -d keycloak postgres

# 起動確認（Ready になるまで約30秒）
docker compose logs -f keycloak
```

**起動完了のサイン**:
```
Keycloak 26.5.3 on JVM ... started in XXms.
Listening on: http://0.0.0.0:8080
```

### アクセス確認

- **管理コンソール**: http://localhost:8080/admin
  - ユーザー名: `admin`
  - パスワード: `admin`

---

## Keycloak 初期設定

### 1. レルム（Realm）の作成

1. 管理コンソールにログイン
2. 左上の "Keycloak" ドロップダウン → "Create realm"
3. レルム設定:
   - **Realm name**: `test-realm`
   - **Enabled**: ON
4. "Create" をクリック

### 2. クライアントアプリケーションの作成

#### 2.1 Authorization Code Flow 用クライアント

1. 左メニュー "Clients" → "Create client"
2. **General Settings**:
   - Client type: `OpenID Connect`
   - Client ID: `test-client`
3. "Next" をクリック
4. **Capability config**:
   - Client authentication: `ON`
   - Authorization: `OFF`
   - Authentication flow:
     - ✅ Standard flow
     - ✅ Direct access grants
5. "Next" をクリック
6. **Login settings**:
   - Valid redirect URIs: `http://localhost:3000/callback`
   - Valid post logout redirect URIs: `http://localhost:3000`
   - Web origins: `http://localhost:3000`
7. "Save" をクリック

#### 2.2 Client Credentials の取得

1. "Clients" → `test-client` → "Credentials" タブ
2. **Client Secret** をコピー（後で使用）

例: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

#### 2.3 Client Credentials Flow 用クライアント（オプション）

Machine-to-Machine 通信用の別クライアントを作成する場合:

1. "Clients" → "Create client"
2. **Client ID**: `service-client`
3. **Client authentication**: `ON`
4. **Service accounts roles**: `ON`
5. その他は同様に設定

### 3. テストユーザーの作成

#### 3.1 ユーザー作成

1. 左メニュー "Users" → "Add user"
2. ユーザー設定:
   - **Username**: `testuser`
   - **Email**: `testuser@example.com`
   - **Email verified**: `ON`
   - **First name**: `Test`
   - **Last name**: `User`
3. "Create" をクリック

#### 3.2 パスワード設定

1. 作成したユーザー → "Credentials" タブ
2. "Set password"
3. パスワード設定:
   - **Password**: `testpass123`
   - **Password confirmation**: `testpass123`
   - **Temporary**: `OFF`
4. "Save" をクリック

### 4. スコープの設定（オプション）

カスタムスコープを追加する場合:

1. "Client scopes" → "Create client scope"
2. スコープ設定:
   - **Name**: `api:read`
   - **Type**: `Default`
3. 同様に `api:write` も作成

---

## 動作検証

### 準備: 環境変数の設定

```bash
# Keycloak のエンドポイント
export KEYCLOAK_BASE_URL="http://localhost:8080/realms/test-realm"
export TOKEN_ENDPOINT="${KEYCLOAK_BASE_URL}/protocol/openid-connect/token"
export AUTH_ENDPOINT="${KEYCLOAK_BASE_URL}/protocol/openid-connect/auth"

# クライアント認証情報
export CLIENT_ID="test-client"
export CLIENT_SECRET="your-client-secret-here"  # 手順2.2でコピーした値

# テストユーザー認証情報
export TEST_USERNAME="testuser"
export TEST_PASSWORD="testpass123"
```

### 検証 1: Client Credentials Flow

Machine-to-Machine 認証のテスト。

#### curl で直接テスト

```bash
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "scope=openid" | jq
```

**期待される結果**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "token_type": "Bearer",
  "scope": "openid"
}
```

#### MoonBit 実装でテスト

統合テスト CLI を使用:

```bash
# テストコードを実行
moon run lib/integration_test_cli

# または手動でビルドして実行
moon build --target native
./target/native/debug/build/integration_test_cli/integration_test_cli.exe
```

**検証ポイント**:
- ✅ アクセストークンが取得できる
- ✅ トークンが JWT 形式である
- ✅ `expires_in` が正しく設定されている
- ✅ HTTP ステータス 200 が返る

### 検証 2: Resource Owner Password Credentials Flow

ユーザー認証情報を使った直接的なトークン取得。

#### curl で直接テスト

```bash
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${TEST_USERNAME}" \
  -d "password=${TEST_PASSWORD}" \
  -d "scope=openid profile email" | jq
```

**期待される結果**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "scope": "openid profile email"
}
```

#### MoonBit 実装でテスト

```moonbit
// lib/oauth2/password_request.mbt を使用
let request = PasswordRequest::new(
  token_url: "${TOKEN_ENDPOINT}",
  client_id: "${CLIENT_ID}",
  client_secret: "${CLIENT_SECRET}",
  username: "${TEST_USERNAME}",
  password: "${TEST_PASSWORD}",
  scope: Some(["openid", "profile", "email"])
)

let token_response = request.execute()
```

**検証ポイント**:
- ✅ アクセストークンとリフレッシュトークンが取得できる
- ✅ ID トークンが取得できる（OpenID Connect）
- ✅ ユーザー情報がトークンに含まれる
- ✅ 無効な認証情報でエラーが返る

### 検証 3: Authorization Code Flow (PKCE)

最も安全なブラウザベースの認証フロー。

#### 3.1 認可リクエスト URL の生成

```moonbit
// lib/oauth2/authorization_request.mbt を使用
let request = AuthorizationRequest::new_with_pkce(
  authorization_url: "${AUTH_ENDPOINT}",
  client_id: "${CLIENT_ID}",
  redirect_uri: "http://localhost:3000/callback",
  scope: ["openid", "profile", "email"],
  state: Some(generate_csrf_token())
)

let auth_url = request.build_authorization_url()
println("認可URL: ${auth_url}")
```

#### 3.2 ブラウザでの認証

1. 生成された URL をブラウザで開く
2. Keycloak のログイン画面が表示される
3. テストユーザーでログイン:
   - Username: `testuser`
   - Password: `testpass123`
4. 同意画面（Consent）でスコープを確認して承認
5. リダイレクト URI にコールバック:
   ```
   http://localhost:3000/callback?
     code=abc123def456...&
     state=state_1234567890_abcdef
   ```

#### 3.3 認可コードをトークンに交換

```bash
# URL からコードを抽出
export AUTH_CODE="abc123def456..."  # ブラウザのURLから取得

# トークン取得（PKCE の code_verifier が必要）
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=http://localhost:3000/callback" \
  -d "code_verifier=${CODE_VERIFIER}" | jq  # 手順3.1で生成
```

**検証ポイント**:
- ✅ 認可 URL が正しく生成される
- ✅ PKCE の code_challenge が含まれる
- ✅ ブラウザでログインできる
- ✅ 認可コードが取得できる
- ✅ トークンに交換できる
- ✅ ID トークンにユーザー情報が含まれる

### 検証 4: トークンの検証

取得したトークンの内容を確認。

#### JWT デコード

```bash
# アクセストークンをデコード（jwt.io を使用するか）
export ACCESS_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# ヘッダー部分
echo $ACCESS_TOKEN | cut -d. -f1 | base64 -d | jq

# ペイロード部分
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq
```

**確認すべき内容**:
```json
{
  "exp": 1709876543,  // 有効期限
  "iat": 1709876243,  // 発行時刻
  "jti": "uuid-here",
  "iss": "http://localhost:8080/realms/test-realm",  // Issuer
  "aud": "account",   // Audience
  "sub": "user-uuid", // Subject (ユーザーID)
  "typ": "Bearer",
  "azp": "test-client",  // Authorized party
  "scope": "openid profile email"
}
```

#### UserInfo エンドポイントでユーザー情報取得

```bash
curl -X GET "${KEYCLOAK_BASE_URL}/protocol/openid-connect/userinfo" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq
```

**期待される結果**:
```json
{
  "sub": "user-uuid",
  "email_verified": true,
  "name": "Test User",
  "preferred_username": "testuser",
  "given_name": "Test",
  "family_name": "User",
  "email": "testuser@example.com"
}
```

### 検証 5: エラーハンドリング

#### 無効なクライアント認証情報

```bash
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=invalid-secret" | jq
```

**期待される結果**:
```json
{
  "error": "unauthorized_client",
  "error_description": "Invalid client or Invalid client credentials"
}
```

#### 無効なユーザー認証情報

```bash
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${TEST_USERNAME}" \
  -d "password=wrong-password" | jq
```

**期待される結果**:
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid user credentials"
}
```

#### 無効な認可コード

```bash
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=invalid-code" \
  -d "redirect_uri=http://localhost:3000/callback" | jq
```

**期待される結果**:
```json
{
  "error": "invalid_grant",
  "error_description": "Code not valid"
}
```

---

## トラブルシューティング

### Keycloak が起動しない

**症状**: `docker compose up` が失敗する

**原因と対処**:
1. **ポート競合**: 8080 が既に使用されている
   ```bash
   # 使用中のポートを確認
   lsof -i :8080
   # 他のサービスを停止するか、docker-compose.yml のポートを変更
   ```

2. **PostgreSQL の初期化エラー**:
   ```bash
   # ボリュームを削除して再作成
   docker compose down -v
   docker compose up -d keycloak postgres
   ```

### 管理コンソールにアクセスできない

**症状**: http://localhost:8080/admin にアクセスできない

**対処**:
```bash
# コンテナの状態を確認
docker compose ps

# Keycloak のログを確認
docker compose logs keycloak

# 起動完了まで待つ（約30秒）
```

### トークン取得時に "Invalid redirect URI" エラー

**症状**:
```json
{
  "error": "invalid_request",
  "error_description": "Invalid redirect_uri"
}
```

**対処**:
1. Keycloak 管理コンソールでクライアント設定を確認
2. "Valid redirect URIs" に正確な URI を追加
3. URIs は完全一致が必要（末尾の `/` にも注意）

### PKCE 検証失敗

**症状**:
```json
{
  "error": "invalid_grant",
  "error_description": "PKCE verification failed"
}
```

**対処**:
1. `code_verifier` が認可リクエスト時の値と一致しているか確認
2. `code_challenge` の生成方法を確認（SHA256 + Base64URL）
3. Keycloak のログで詳細を確認

### トークンが期限切れ

**症状**: API 呼び出し時に 401 Unauthorized

**対処**:
```bash
# トークンの有効期限を確認
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq '.exp'

# リフレッシュトークンで新しいアクセストークンを取得
curl -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "refresh_token=${REFRESH_TOKEN}" | jq
```

---

## 補足情報

### Keycloak の便利な機能

#### 1. トークンの検査（Introspection）

```bash
curl -X POST "${KEYCLOAK_BASE_URL}/protocol/openid-connect/token/introspect" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "token=${ACCESS_TOKEN}" | jq
```

#### 2. セッション管理

管理コンソール → Users → testuser → Sessions

- アクティブなセッションを確認
- 強制ログアウト可能

#### 3. 監査ログ

管理コンソール → Realm Settings → Events

- ログイン試行
- トークン発行
- エラーイベント

### Keycloak と mock-oauth2-server の違い

| 機能 | Keycloak | mock-oauth2-server |
|------|----------|---------------------|
| **用途** | 本番想定の検証 | 簡易的な動作確認 |
| **ユーザー管理** | 完全な管理機能 | 事前設定のみ |
| **認証フロー** | 全フローサポート | 基本フローのみ |
| **トークン形式** | 完全な JWT | 簡易的な JWT |
| **設定の複雑さ** | 高い | 低い（即座に利用可能） |
| **パフォーマンス** | 本番相当 | 軽量・高速 |

**推奨**:
- 開発初期・単体テスト: `mock-oauth2-server`
- 統合テスト・本番前検証: `Keycloak`

### 環境のクリーンアップ

```bash
# Keycloak と PostgreSQL を停止
docker compose down

# データを完全に削除（レルム・ユーザー等も削除）
docker compose down -v

# イメージも削除
docker rmi quay.io/keycloak/keycloak:26.5.3 postgres:15.3
```

---

## チェックリスト

### 初期設定完了確認

- [ ] Keycloak が起動している
- [ ] 管理コンソールにログインできる
- [ ] test-realm が作成されている
- [ ] test-client が作成され、Client Secret を取得した
- [ ] testuser が作成され、パスワードが設定されている

### 動作検証完了確認

- [ ] Client Credentials Flow でトークンを取得できた
- [ ] Password Grant Flow でトークンを取得できた
- [ ] Authorization Code Flow で認可 URL を生成できた
- [ ] ブラウザでログインし、認可コードを取得できた
- [ ] 認可コードをトークンに交換できた
- [ ] JWT をデコードし、内容を確認できた
- [ ] UserInfo エンドポイントからユーザー情報を取得できた
- [ ] 無効な認証情報でエラーハンドリングが動作した

---

## 参考リンク

- [Keycloak 公式ドキュメント](https://www.keycloak.org/documentation)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
