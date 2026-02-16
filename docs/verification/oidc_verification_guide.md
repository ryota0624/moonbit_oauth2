# OIDC 動作検証ガイド

このドキュメントは、MoonBit OAuth2ライブラリのOIDC実装を実際のKeycloak環境で検証する手順を説明します。

## 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [自動検証の実行](#自動検証の実行)
4. [検証内容](#検証内容)
5. [手動検証の手順](#手動検証の手順)
6. [トラブルシューティング](#トラブルシューティング)
7. [期待される結果](#期待される結果)

## 概要

### 検証の目的

OIDC Phase 1の実装が以下の機能を正しく動作することを確認します:

- ID Tokenの取得とパース
- ID Token内のクレーム検証
- UserInfo Endpointからの情報取得
- nonceパラメータのサポート

### 検証環境

- **OIDCプロバイダー**: Keycloak 26.5.3
- **実行環境**: Docker Compose
- **テストターゲット**: MoonBit Native/JS

## 前提条件

### 必要なツール

1. **Docker と Docker Compose**
   ```bash
   docker --version
   docker compose version
   ```

2. **MoonBit ツールチェーン**
   ```bash
   moon version
   ```

3. **jq（JSON処理用）**
   ```bash
   jq --version
   ```

4. **curl（HTTP リクエスト用）**
   ```bash
   curl --version
   ```

### 環境のセットアップ

Keycloak環境がまだセットアップされていない場合:

```bash
./scripts/setup_keycloak.sh
```

このスクリプトは以下を自動で実行します:
- Keycloak と PostgreSQL の起動
- test-realm の作成
- test-client の作成（OIDC対応）
- testuser の作成

## 自動検証の実行

### 基本的な実行方法

```bash
./scripts/verify_oidc.sh
```

このスクリプトは以下を自動で実行します:

1. Keycloakの起動確認
2. Client Secretの取得または確認
3. OIDC検証テストの実行
4. 結果のレポート出力

### 環境変数のカスタマイズ

デフォルト値以外を使用する場合:

```bash
export KEYCLOAK_REALM="my-realm"
export CLIENT_ID="my-client"
export CLIENT_SECRET="my-secret"
export TEST_USERNAME="myuser"
export TEST_PASSWORD="mypass"

./scripts/verify_oidc.sh
```

### 直接実行

スクリプトを使わずに直接実行する場合:

```bash
# 環境変数を設定
export CLIENT_SECRET="your-client-secret"
export TOKEN_ENDPOINT="http://localhost:8080/realms/test-realm/protocol/openid-connect/token"

# テストを実行
moon run lib/keycloak_test/oidc_verification
```

## 検証内容

### Test 1: ID Token取得（Password Grant Flow）

**目的**: OIDCスコープを含むトークンリクエストでID Tokenが取得できることを確認

**検証項目**:
- ✅ トークン取得の成功
- ✅ TokenResponseにid_tokenフィールドが存在
- ✅ JWT形式の確認（3部分構造）
- ✅ ID Tokenのパース成功
- ✅ 必須クレームの存在（iss, sub, aud, exp, iat）
- ✅ クレームの妥当性確認
  - issuerがKeycloak URLを含む
  - audienceがclient_idと一致
  - subjectが非空
  - expirationが未来の時刻
  - issued_atが過去の時刻
- ✅ オプションクレームの取得（email, name等）

**リクエスト**:
```moonbit
let scopes = [
  @oauth2.Scope::openid(),
  @oauth2.Scope::profile(),
  @oauth2.Scope::email(),
]

let request = @oauth2.PasswordRequest::new(
  token_url,
  client_id,
  Some(client_secret),
  username,
  password,
  scopes,
)
```

**期待されるレスポンス**:
```json
{
  "access_token": "eyJhbGc...",
  "id_token": "eyJhbGc...",  // ID Token（JWT形式）
  "token_type": "Bearer",
  "expires_in": 300,
  "refresh_token": "eyJhbGc...",
  "scope": "openid profile email"
}
```

### Test 2: UserInfo Endpoint

**目的**: Access TokenでUserInfo Endpointからユーザー情報を取得できることを確認

**検証項目**:
- ✅ Access Token取得の成功
- ✅ UserInfoリクエストの成功
- ✅ subフィールドの存在
- ✅ ID TokenのsubとUserInfoのsubが一致
- ✅ オプションフィールドの取得（name, email等）

**リクエスト**:
```moonbit
let userinfo_url = @oidc.UserInfoUrl::new(
  "http://localhost:8080/realms/test-realm/protocol/openid-connect/userinfo"
)
let request = @oidc.UserInfoRequest::new(userinfo_url, access_token)
let result = request.execute(http_client)
```

**期待されるレスポンス**:
```json
{
  "sub": "user-uuid",
  "email": "testuser@example.com",
  "email_verified": true,
  "name": "Test User",
  "preferred_username": "testuser",
  "given_name": "Test",
  "family_name": "User"
}
```

### Test 3: nonce パラメータ

**目的**: nonceパラメータがAuthorization URLに含まれることを確認

**検証項目**:
- ✅ nonce生成の成功
- ✅ Authorization URL生成の成功
- ✅ URLにnonceパラメータが含まれる
- ✅ その他の必須パラメータの確認
  - client_id
  - redirect_uri
  - scope（openidを含む）
  - state
  - code_challenge（PKCE）

**生成されるURL例**:
```
http://localhost:8080/realms/test-realm/protocol/openid-connect/auth?
  response_type=code&
  client_id=test-client&
  redirect_uri=http://localhost:3000/callback&
  scope=openid+profile&
  state=random-state-token&
  nonce=random-nonce-token&
  code_challenge=challenge-string&
  code_challenge_method=S256
```

### Test 4: TokenResponse ヘルパー関数

**目的**: OIDCパッケージのヘルパー関数が正しく動作することを確認

**検証項目**:
- ✅ `parse_id_token_from_response()` の動作
  - TokenResponseからID Tokenをパース
  - Noneの場合も正しく処理
- ✅ `get_id_token_from_response()` の動作
  - TokenResponseからID Tokenを取得
  - 存在しない場合はエラーを返す

## 手動検証の手順

自動検証スクリプトが使えない場合の手動検証手順です。

### 1. Keycloak環境の起動

```bash
docker compose up -d keycloak postgres
```

起動確認:
```bash
curl http://localhost:8080/health/ready
```

### 2. Client Secretの取得

管理者トークンを取得:
```bash
ADMIN_TOKEN=$(curl -s -X POST \
  'http://localhost:8080/realms/master/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin' \
  -d 'password=admin' \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | jq -r '.access_token')
```

Client UUIDを取得:
```bash
CLIENT_UUID=$(curl -s -X GET \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  'http://localhost:8080/admin/realms/test-realm/clients?clientId=test-client' | \
  jq -r '.[0].id')
```

Client Secretを取得:
```bash
CLIENT_SECRET=$(curl -s -X GET \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "http://localhost:8080/admin/realms/test-realm/clients/${CLIENT_UUID}/client-secret" | \
  jq -r '.value')

echo "Client Secret: ${CLIENT_SECRET}"
```

### 3. curlでのID Token取得テスト

Password Grant Flowでトークンを取得:

```bash
curl -X POST \
  'http://localhost:8080/realms/test-realm/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password" \
  -d "client_id=test-client" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=testuser" \
  -d "password=testpass123" \
  -d "scope=openid profile email" | jq
```

期待されるレスポンス:
```json
{
  "access_token": "...",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJfX3N...",
  "token_type": "Bearer",
  "expires_in": 300,
  "refresh_token": "...",
  "scope": "openid profile email"
}
```

### 4. ID Tokenのデコード

ID Tokenは3部分に分かれています（header.payload.signature）:

```bash
ID_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJfX3N..."

# Payloadを抽出（2番目の部分）
PAYLOAD=$(echo $ID_TOKEN | cut -d '.' -f 2)

# Base64URLデコードしてJSON表示
echo $PAYLOAD | base64 -d 2>/dev/null | jq
```

期待されるpayload:
```json
{
  "exp": 1708123456,
  "iat": 1708123156,
  "auth_time": 1708123156,
  "jti": "...",
  "iss": "http://localhost:8080/realms/test-realm",
  "aud": "test-client",
  "sub": "user-uuid",
  "typ": "ID",
  "azp": "test-client",
  "session_state": "...",
  "email_verified": true,
  "name": "Test User",
  "preferred_username": "testuser",
  "given_name": "Test",
  "family_name": "User",
  "email": "testuser@example.com"
}
```

### 5. UserInfo Endpointのテスト

Access Tokenを使用してUserInfo取得:

```bash
ACCESS_TOKEN="your-access-token-here"

curl -X GET \
  'http://localhost:8080/realms/test-realm/protocol/openid-connect/userinfo' \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq
```

### 6. MoonBitテストの実行

```bash
export CLIENT_SECRET="${CLIENT_SECRET}"
moon run lib/keycloak_test/oidc_verification
```

## トラブルシューティング

### 問題1: Keycloakが起動しない

**症状**:
```
✗ Keycloak の起動がタイムアウトしました
```

**解決方法**:
1. PostgreSQLが正常に起動しているか確認
   ```bash
   docker compose ps postgres
   docker compose logs postgres
   ```

2. Keycloakのログを確認
   ```bash
   docker compose logs keycloak
   ```

3. ポートが使用中でないか確認
   ```bash
   lsof -i :8080
   lsof -i :5432
   ```

4. Docker Composeを再起動
   ```bash
   docker compose down
   docker compose up -d
   ```

### 問題2: Client Secretが取得できない

**症状**:
```
✗ CLIENT_SECRET の取得に失敗しました
```

**解決方法**:
1. セットアップスクリプトを実行
   ```bash
   ./scripts/setup_keycloak.sh
   ```

2. Keycloak管理コンソールから手動で取得
   - http://localhost:8080/admin にアクセス
   - admin / admin でログイン
   - Clients → test-client → Credentials タブ
   - Client Secretをコピー

3. 環境変数に設定
   ```bash
   export CLIENT_SECRET="取得したシークレット"
   ```

### 問題3: トークン取得でエラー

**症状**:
```
✗ トークン取得: invalid_client
```

**解決方法**:
1. Client IDが正しいか確認
   ```bash
   echo $CLIENT_ID
   ```

2. Client Secretが正しいか確認
   ```bash
   echo $CLIENT_SECRET
   ```

3. testuserが存在するか確認
   ```bash
   curl -s -X GET \
     -H "Authorization: Bearer ${ADMIN_TOKEN}" \
     'http://localhost:8080/admin/realms/test-realm/users?username=testuser' | jq
   ```

### 問題4: ID Tokenが含まれない

**症状**:
```
✗ id_token フィールド存在: TokenResponse に id_token が含まれていません
```

**解決方法**:
1. スコープに `openid` が含まれているか確認
   ```moonbit
   let scopes = [@oauth2.Scope::openid()]
   ```

2. Clientの設定を確認
   - Keycloak管理コンソール
   - Clients → test-client → Settings
   - "OpenID Connect" プロトコルが選択されているか

### 問題5: UserInfo取得でエラー

**症状**:
```
✗ UserInfo 取得: HTTP 401
```

**解決方法**:
1. Access Tokenが有効か確認
   - トークンの有効期限を確認
   - 再度トークンを取得

2. UserInfo EndpointのURLが正しいか確認
   ```bash
   echo $KEYCLOAK_BASE_URL/protocol/openid-connect/userinfo
   ```

3. scopeに `profile` または `email` が含まれているか確認

### 問題6: MoonBitビルドエラー

**症状**:
```
Error: Cannot find package @oidc
```

**解決方法**:
1. パッケージ依存関係を確認
   ```bash
   cat lib/keycloak_test/moon.pkg
   ```

2. `@oidc` が import に含まれているか確認
   ```json
   {
     "is-main": true,
     "import": [
       "ryota0624/oauth2",
       "ryota0624/oidc"
     ]
   }
   ```

3. 依存関係を更新
   ```bash
   moon install
   ```

## 期待される結果

### 成功時の出力例

```
============================================================
Keycloak OIDC 検証スクリプト (MoonBit)
============================================================

📋 設定:
  Realm: test-realm
  Base URL: http://localhost:8080/realms/test-realm
  Token Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/token
  UserInfo Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/userinfo
  Client ID: test-client
  Client Secret: ********...
  Test User: testuser

============================================================
Test 1: ID Token取得（Password Grant Flow）
============================================================
Token Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/token
Client ID: test-client
Username: testuser
Scopes: openid, profile, email

リクエスト送信中...
[✓ 成功] トークン取得
[✓ 成功] id_token フィールド存在

📋 ID Token (先頭50文字):
  eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6IC...
[✓ 成功] JWT 形式（3部分構造）

📋 ID Token パース:
[✓ 成功] ID Token パース

📋 ID Token クレーム:
  iss (Issuer): http://localhost:8080/realms/test-realm
  sub (Subject): a1b2c3d4-...
  aud (Audience): test-client
  exp (Expiration): 1708123456
  iat (Issued At): 1708123156
[✓ 成功] iss クレーム
[✓ 成功] sub クレーム
[✓ 成功] aud クレーム
[✓ 成功] exp クレーム
[✓ 成功] iat クレーム
[✓ 成功] Issuer 妥当性
  realm が含まれる: true
[✓ 成功] Audience 妥当性
  client_id と一致: true

📋 オプションクレーム:
  email: testuser@example.com
[✓ 成功] email クレーム
  name: Test User
[✓ 成功] name クレーム

============================================================
Test 2: UserInfo Endpoint
============================================================
UserInfo Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/userinfo

📋 Access Token 取得中...
[✓ 成功] Access Token 取得

📋 UserInfo リクエスト送信中...
[✓ 成功] UserInfo 取得

📋 UserInfo:
  sub: a1b2c3d4-...
  name: Test User
  email: testuser@example.com
  email_verified: true
[✓ 成功] sub フィールド
[✓ 成功] sub 一致（ID Token vs UserInfo）
  一致: true
[✓ 成功] name フィールド
[✓ 成功] email フィールド

============================================================
Test 3: nonce パラメータ
============================================================
Authorization Endpoint: http://localhost:8080/realms/test-realm/protocol/openid-connect/auth

📋 生成された nonce:
  random-nonce-string
[✓ 成功] nonce 生成

📋 生成された Authorization URL:
http://localhost:8080/realms/test-realm/protocol/openid-connect/auth?...&nonce=random-nonce-string&...

[✓ 成功] nonce パラメータ存在
[✓ 成功] client_id パラメータ
[✓ 成功] redirect_uri パラメータ
[✓ 成功] scope パラメータ
[✓ 成功] openid スコープ

============================================================
Test 4: TokenResponse ヘルパー関数
============================================================

📋 トークン取得中...
[✓ 成功] トークン取得

📋 parse_id_token_from_response テスト:
[✓ 成功] parse_id_token_from_response
  sub: a1b2c3d4-...

📋 get_id_token_from_response テスト:
[✓ 成功] get_id_token_from_response
  sub: a1b2c3d4-...

============================================================
テスト完了
============================================================

✓ MoonBit OIDC 実装で Keycloak の動作を検証しました

📖 詳細な手順は docs/verification/oidc_verification_guide.md を参照
```

### 検証項目のチェックリスト

すべて成功すべき項目:

- [ ] トークン取得の成功
- [ ] id_tokenフィールドの存在
- [ ] JWT形式の確認
- [ ] ID Tokenパースの成功
- [ ] 必須クレーム（iss, sub, aud, exp, iat）の存在
- [ ] Issuerの妥当性
- [ ] Audienceの妥当性
- [ ] UserInfo取得の成功
- [ ] subの一致（ID Token vs UserInfo）
- [ ] nonce生成
- [ ] nonceパラメータの存在
- [ ] ヘルパー関数の動作

## 次のステップ

検証が成功したら:

1. **完了ドキュメントの作成**
   - 検証結果をまとめる
   - 発見した問題と解決方法を記録

2. **Phase 2の準備**
   - 署名検証の実装計画
   - JWKS統合の設計

3. **ドキュメントの更新**
   - READMEにOIDCセクションを追加
   - サンプルコードの追加

4. **CI/CD統合**
   - GitHub ActionsでOIDC検証を追加
   - PRでの自動テスト

## 参考資料

- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [RFC 7519 - JWT](https://tools.ietf.org/html/rfc7519)
- [OAuth 2.0 検証ガイド](../testing/keycloak_verification_guide.md)
