# Steering: OpenID Connect (OIDC) 実装

## 目的・背景

現在のライブラリはOAuth2クライアント機能を提供していますが、OpenID Connect（OIDC）の認証機能はサポートしていません。OIDCはOAuth2を拡張した認証レイヤーであり、以下のユースケースで必要とされます：

- ユーザー認証とシングルサインオン（SSO）
- ユーザー情報（プロフィール、メールアドレス等）の取得
- 標準化された認証フロー（Google、GitHub、Keycloak等の統一的な利用）

OAuth2は**認可**（Authorization）に焦点を当てていますが、OIDCは**認証**（Authentication）を提供します。

## ゴール

1. **OIDC準拠のクライアントライブラリの実装**
   - OpenID Connect Core 1.0 仕様に準拠
   - ID Tokenの受信・検証・利用
   - UserInfo Endpointのサポート

2. **セキュリティの確保**
   - ID Tokenの署名検証
   - nonceによるリプレイ攻撃対策
   - クレーム検証（iss, aud, exp等）

3. **開発者体験の向上**
   - 型安全なAPI
   - わかりやすいエラーハンドリング
   - 実用的なサンプルコード

4. **実環境での検証**
   - Keycloakとの統合テスト
   - 実際のOIDCプロバイダー（Google、GitHub等）との互換性

## パッケージ構成

OIDC機能は**OAuth2パッケージとは別の独立したパッケージ**として実装します。

### ディレクトリ構造

```
lib/
├── oauth2/              # OAuth2パッケージ（既存）
│   ├── moon.pkg.json
│   ├── types.mbt
│   ├── authorization_request.mbt
│   ├── token_request.mbt
│   └── ...
└── oidc/                # OIDCパッケージ（新規）
    ├── moon.pkg.json
    ├── id_token.mbt
    ├── jwks.mbt
    ├── userinfo.mbt
    ├── discovery.mbt
    └── oidc_client.mbt
```

### パッケージ依存関係

**`lib/oidc/moon.pkg.json`**:

```json
{
  "is-main": false,
  "import": [
    "ryota0624/oauth2"
  ]
}
```

- `@oidc` パッケージは `@oauth2` パッケージに依存
- OIDCはOAuth2の上位レイヤーとして実装
- OAuth2の型（`ClientId`, `AccessToken`, `TokenResponse`等）を再利用

### 利用者側の使い分け

#### OAuth2のみ利用する場合

```moonbit
// OAuth2機能のみ
let token = @oauth2.ClientCredentialsRequest::new(...)
```

#### OIDCを利用する場合

```moonbit
// OIDC機能（内部でOAuth2を利用）
let client = @oidc.OidcClient::from_issuer(...)
let response = client.exchange_code(...)  // OAuth2の機能も利用可能
let id_token = response.id_token()        // OIDC固有の機能
```

### パッケージ分離の利点

1. **関心の分離**
   - OAuth2: 認可（Authorization）
   - OIDC: 認証（Authentication）

2. **依存関係の明確化**
   - OAuth2のみ必要な場合は、OIDCパッケージに依存しない
   - バンドルサイズの最適化

3. **メンテナンス性**
   - それぞれ独立してバージョン管理可能
   - テストの分離

4. **拡張性**
   - 将来的にSAML、CAS等の他の認証プロトコルも追加可能

## アプローチ

### Phase 1: コア機能の実装（最小限のOIDC対応）

#### 1.1 ID Token の型定義と基本パース

**新規ファイル**: `lib/oidc/id_token.mbt`

```moonbit
// ID Token型定義
struct IdToken {
  raw : String          // 元のJWT文字列
  header : JwtHeader
  payload : IdTokenClaims
  signature : String
}

// JWT Header
struct JwtHeader {
  alg : String          // 署名アルゴリズム（例: RS256）
  typ : String          // トークンタイプ（通常 "JWT"）
  kid : String?         // Key ID（オプション）
}

// ID Token Claims（標準クレーム）
struct IdTokenClaims {
  // 必須クレーム
  iss : String          // Issuer（発行者URL）
  sub : String          // Subject（ユーザーID）
  aud : String          // Audience（クライアントID）
  exp : Int64           // Expiration（UNIXタイムスタンプ）
  iat : Int64           // Issued At（発行時刻）

  // 推奨クレーム
  auth_time : Int64?    // 認証時刻
  nonce : String?       // リプレイ攻撃対策

  // オプションクレーム
  name : String?
  given_name : String?
  family_name : String?
  email : String?
  email_verified : Bool?
  picture : String?
  locale : String?
}

// ID Tokenのパース
fn IdToken::parse(token_string : String) -> Result[IdToken, OAuthError]

// JWT文字列を3部分に分割（header.payload.signature）
fn split_jwt(jwt : String) -> Result[(String, String, String), OAuthError]

// Base64URL デコード
fn base64url_decode(input : String) -> Result[String, OAuthError]

// JSON から Claims をパース
fn parse_claims(json : String) -> Result[IdTokenClaims, OAuthError]
```

#### 1.2 Token Response の拡張

**変更ファイル**: `lib/oauth2/types.mbt`

```moonbit
// 既存のTokenResponseを拡張してid_tokenを追加
struct TokenResponse {
  access_token : AccessToken
  token_type : String
  expires_in : Int?
  refresh_token : RefreshToken?
  scope : Array[Scope]

  // OIDC追加
  id_token : IdToken?   // ID Token（OIDCの場合に存在）
}

// TokenResponseのパース処理にid_tokenフィールドの処理を追加
fn TokenResponse::from_json(json : Json) -> Result[TokenResponse, OAuthError]
```

#### 1.3 UserInfo Endpoint の実装

**新規ファイル**: `lib/oidc/userinfo.mbt`

```moonbit
// UserInfo型定義
struct UserInfo {
  sub : String          // 必須: ユーザーID（ID Tokenのsubと一致）
  name : String?
  given_name : String?
  family_name : String?
  email : String?
  email_verified : Bool?
  picture : String?
  profile : String?
  locale : String?
  updated_at : Int64?
}

// UserInfo Endpoint URL型
struct UserInfoUrl {
  url : String
}

fn UserInfoUrl::new(url : String) -> UserInfoUrl

// UserInfo Request
struct UserInfoRequest {
  userinfo_url : UserInfoUrl
  access_token : AccessToken
}

fn UserInfoRequest::new(
  userinfo_url : UserInfoUrl,
  access_token : AccessToken
) -> UserInfoRequest

// UserInfo取得の実行
fn UserInfoRequest::execute(
  self : UserInfoRequest,
  http_client : OAuth2HttpClient
) -> Result[UserInfo, OAuthError]

// UserInfoのJSONパース
fn UserInfo::from_json(json : Json) -> Result[UserInfo, OAuthError]
```

#### 1.4 nonce パラメータのサポート

**変更ファイル**: `lib/oauth2/authorization_request.mbt`

```moonbit
// AuthorizationRequestにnonceフィールドを追加
struct AuthorizationRequest {
  auth_url : AuthUrl
  client_id : ClientId
  redirect_uri : RedirectUrl
  scopes : Array[Scope]
  state : CsrfToken
  pkce_challenge : PkceCodeChallenge?
  nonce : Nonce?        // 追加: OIDCのリプレイ攻撃対策
}

// Nonce型の定義
struct Nonce {
  value : String
}

fn Nonce::new(value : String) -> Nonce
fn Nonce::new_random() -> Nonce  // ランダムなnonce生成

// Authorization URL構築時にnonceをクエリパラメータに追加
fn AuthorizationRequest::build_authorization_url(
  self : AuthorizationRequest
) -> String
```

#### 1.5 OpenID Scope の追加

**変更ファイル**: `lib/oauth2/types.mbt`

```moonbit
// 標準的なOIDCスコープのヘルパー関数
fn Scope::openid() -> Scope {
  Scope::new("openid")
}

fn Scope::profile() -> Scope {
  Scope::new("profile")
}

fn Scope::email() -> Scope {
  Scope::new("email")
}

fn Scope::address() -> Scope {
  Scope::new("address")
}

fn Scope::phone() -> Scope {
  Scope::new("phone")
}
```

### Phase 2: セキュリティ強化（署名検証）

#### 2.1 JWKS (JSON Web Key Set) の取得

**新規ファイル**: `lib/oidc/jwks.mbt`

```moonbit
// JWKS URL型
struct JwksUrl {
  url : String
}

fn JwksUrl::new(url : String) -> JwksUrl

// JSON Web Key
struct Jwk {
  kty : String          // Key Type (例: "RSA")
  use : String?         // Public Key Use (例: "sig")
  kid : String?         // Key ID
  alg : String?         // Algorithm (例: "RS256")
  n : String?           // RSA Modulus (Base64URL)
  e : String?           // RSA Exponent (Base64URL)
}

// JWKS (複数のJWK)
struct Jwks {
  keys : Array[Jwk]
}

// JWKSの取得
fn fetch_jwks(
  jwks_url : JwksUrl,
  http_client : OAuth2HttpClient
) -> Result[Jwks, OAuthError]

// JWKSからKey IDでJWKを検索
fn Jwks::find_key(self : Jwks, kid : String) -> Jwk?

// JSONからJWKSをパース
fn Jwks::from_json(json : Json) -> Result[Jwks, OAuthError]
```

#### 2.2 ID Token の署名検証

**変更ファイル**: `lib/oidc/id_token.mbt`

```moonbit
// 署名検証機能の追加
fn IdToken::verify_signature(
  self : IdToken,
  jwk : Jwk
) -> Result[Unit, OAuthError]

// RS256署名検証（RSA SHA-256）
fn verify_rs256(
  message : String,       // header.payload
  signature : String,     // Base64URL署名
  jwk : Jwk              // 公開鍵
) -> Result[Unit, OAuthError]

// RSA公開鍵の構築（JWKのn, eから）
fn build_rsa_public_key(jwk : Jwk) -> Result[RsaPublicKey, OAuthError]
```

**依存関係**: RSA署名検証のため、暗号化ライブラリが必要
- `moonbitlang/x/crypto` を利用、または外部ライブラリの検討

#### 2.3 ID Token Claims の検証

**変更ファイル**: `lib/oidc/id_token.mbt`

```moonbit
// Claims検証の設定
struct IdTokenValidator {
  client_id : ClientId       // 期待されるaud
  issuer : String           // 期待されるiss
  nonce : Nonce?            // 期待されるnonce
  clock_skew : Int          // 時刻のズレ許容（秒）
}

fn IdTokenValidator::new(
  client_id : ClientId,
  issuer : String,
  nonce : Nonce?,
  clock_skew : Int  // デフォルト: 60秒
) -> IdTokenValidator

// ID Tokenの検証（署名 + クレーム）
fn IdToken::validate(
  self : IdToken,
  validator : IdTokenValidator,
  jwk : Jwk
) -> Result[Unit, OAuthError]

// 個別のクレーム検証
fn validate_issuer(iss : String, expected : String) -> Result[Unit, OAuthError]
fn validate_audience(aud : String, expected : ClientId) -> Result[Unit, OAuthError]
fn validate_expiration(exp : Int64, clock_skew : Int) -> Result[Unit, OAuthError]
fn validate_nonce(nonce : String?, expected : Nonce?) -> Result[Unit, OAuthError]
```

### Phase 3: 高度な機能（Discovery Document）

#### 3.1 OpenID Provider Discovery

**新規ファイル**: `lib/oidc/discovery.mbt`

```moonbit
// Discovery Document URL
// 例: https://accounts.google.com/.well-known/openid-configuration
struct DiscoveryUrl {
  url : String
}

fn DiscoveryUrl::from_issuer(issuer : String) -> DiscoveryUrl {
  // issuer + "/.well-known/openid-configuration"
}

// OpenID Provider Metadata
struct ProviderMetadata {
  issuer : String
  authorization_endpoint : String
  token_endpoint : String
  userinfo_endpoint : String?
  jwks_uri : String
  scopes_supported : Array[String]?
  response_types_supported : Array[String]
  grant_types_supported : Array[String]?
  subject_types_supported : Array[String]
  id_token_signing_alg_values_supported : Array[String]
  claims_supported : Array[String]?
}

// Discovery Documentの取得
fn fetch_discovery(
  discovery_url : DiscoveryUrl,
  http_client : OAuth2HttpClient
) -> Result[ProviderMetadata, OAuthError]

// JSONからProviderMetadataをパース
fn ProviderMetadata::from_json(json : Json) -> Result[ProviderMetadata, OAuthError]
```

#### 3.2 OIDC Client の統合API

**新規ファイル**: `lib/oidc/oidc_client.mbt`

```moonbit
// OIDCクライアント（Discovery Documentから自動設定）
struct OidcClient {
  provider_metadata : ProviderMetadata
  client_id : ClientId
  client_secret : ClientSecret
  redirect_uri : RedirectUrl
  http_client : OAuth2HttpClient
}

// Issuer URLからOIDCクライアントを作成
fn OidcClient::from_issuer(
  issuer : String,
  client_id : ClientId,
  client_secret : ClientSecret,
  redirect_uri : RedirectUrl,
  http_client : OAuth2HttpClient
) -> Result[OidcClient, OAuthError]

// Authorization URLの生成
fn OidcClient::authorization_url(
  self : OidcClient,
  scopes : Array[Scope],
  state : CsrfToken,
  nonce : Nonce,
  pkce_challenge : PkceCodeChallenge
) -> String

// Codeの交換 + ID Token検証
fn OidcClient::exchange_code(
  self : OidcClient,
  code : String,
  pkce_verifier : PkceCodeVerifier,
  nonce : Nonce
) -> Result[OidcTokenResponse, OAuthError]

// UserInfo取得
fn OidcClient::fetch_userinfo(
  self : OidcClient,
  access_token : AccessToken
) -> Result[UserInfo, OAuthError]
```

**新規型**: `OidcTokenResponse`

```moonbit
struct OidcTokenResponse {
  access_token : AccessToken
  id_token : IdToken        // 検証済みID Token
  refresh_token : RefreshToken?
  expires_in : Int?
  token_type : String
}
```

## スコープ

### 含むもの

1. **ID Tokenのサポート**
   - JWT形式のパース
   - 標準クレームの型定義
   - Base64URLデコード

2. **UserInfo Endpointのサポート**
   - HTTP GETリクエスト
   - Bearer Token認証
   - JSONレスポンスのパース

3. **セキュリティ機能**
   - nonce パラメータ
   - ID Token署名検証（RS256）
   - Claims検証（iss, aud, exp, nonce）

4. **Discovery Document**
   - `.well-known/openid-configuration` の取得
   - Provider Metadata の利用

5. **統合テスト**
   - Keycloak での OIDC フローテスト
   - ID Token検証のテスト
   - UserInfo取得のテスト

6. **ドキュメント**
   - OIDCの使い方ガイド
   - サンプルコード
   - APIリファレンス

### 含まないもの

1. **OIDCプロバイダー（サーバー側）の実装**
   - このライブラリはクライアント専用
   - Authorization ServerやID Token発行は含まない

2. **Implicit FlowとHybrid Flow**
   - 現代のベストプラクティスではない
   - Authorization Code Flow + PKCEに注力

3. **高度な署名アルゴリズム**
   - RS256のみサポート
   - ES256, PS256等は将来的な拡張

4. **ID Tokenの暗号化（JWE）**
   - 署名（JWS）のみサポート
   - 暗号化は現時点で対象外

5. **Dynamic Client Registration**
   - 静的なクライアント設定のみ
   - 動的登録は対象外

6. **Session Management**
   - フロントチャネルログアウト
   - バックチャネルログアウト
   - これらは将来的な拡張

## 影響範囲

### 新規ファイル

```
lib/oidc/                     # OIDCパッケージ（新規）
├── moon.pkg.json             # パッケージ定義（oauth2に依存）
├── id_token.mbt              # ID Token型定義・パース・検証
├── id_token_wbtest.mbt       # ID Tokenのテスト
├── jwks.mbt                  # JWKS取得・管理
├── jwks_wbtest.mbt           # JWKSのテスト
├── userinfo.mbt              # UserInfo Endpoint
├── userinfo_wbtest.mbt       # UserInfoのテスト
├── discovery.mbt             # Discovery Document
├── discovery_wbtest.mbt      # Discoveryのテスト
└── oidc_client.mbt           # 統合OIDC Client API
```

### 変更ファイル

```
lib/oauth2/
├── types.mbt                 # TokenResponseにid_token追加、Scopeヘルパー追加
├── authorization_request.mbt # nonceパラメータ追加
├── token_request.mbt         # レスポンスにid_token処理追加
└── error.mbt                 # OIDCエラー種別追加
```

### テストファイル

```
lib/keycloak_test/
├── oidc_flow_test.mbt        # OIDC Authorization Code Flow
├── id_token_test.mbt         # ID Token検証
├── userinfo_test.mbt         # UserInfo取得
└── discovery_test.mbt        # Discovery Document
```

### ドキュメント

```
docs/
├── oidc_guide.md             # OIDC使用ガイド
├── id_token_validation.md    # ID Token検証の詳細
└── examples/
    ├── oidc_basic.mbt        # 基本的なOIDCフロー
    ├── oidc_with_userinfo.mbt # UserInfo取得の例
    └── oidc_google.mbt       # Google OIDCの例
```

## 技術的な決定事項

### 1. JWT処理

**選択肢**:
- A. 外部JWTライブラリを使用
- B. 自前でJWTパース・検証を実装

**決定**: **B. 自前で実装**

**理由**:
- MoonBitエコシステムにJWTライブラリが少ない
- OIDCに必要な最小限の機能（RS256のみ）に絞れる
- 依存関係を減らし、クロスプラットフォーム対応を容易にする
- Base64URLデコード、JSONパースは既存機能で対応可能

### 2. 暗号化処理

**選択肢**:
- A. `moonbitlang/x/crypto` を使用
- B. プラットフォーム依存のFFIを使用
- C. 外部暗号ライブラリ

**決定**: **A. `moonbitlang/x/crypto` を使用**

**理由**:
- 公式ライブラリで安定性が高い
- SHA-256は既に実装されている
- RSA検証機能が必要（要確認・拡張）

### 3. Discovery Documentの扱い

**選択肢**:
- A. 必須機能として実装
- B. オプション機能として実装
- C. Phase 3で実装

**決定**: **C. Phase 3で実装**

**理由**:
- 手動設定でも十分に機能する
- Phase 1, 2でコア機能を固めてから拡張
- 多くのOIDCクライアントは手動設定から始まる

### 4. エラーハンドリング

**拡張するエラー種別**:

```moonbit
enum OAuthError {
  // 既存のエラー
  NetworkError(String)
  InvalidResponse(String)
  AuthorizationError(String, String)

  // OIDC追加エラー
  InvalidIdToken(String)           // ID Tokenの形式が不正
  IdTokenValidationError(String)   // ID Token検証失敗
  InvalidSignature(String)         // 署名検証失敗
  ExpiredIdToken                   // ID Tokenの有効期限切れ
  InvalidIssuer(String, String)    // Issuer不一致
  InvalidAudience(String, String)  // Audience不一致
  InvalidNonce(String, String)     // Nonce不一致
  JwksError(String)                // JWKS取得エラー
  UserInfoError(String)            // UserInfo取得エラー
}
```

## 実装順序

### Phase 1: 基礎実装（1-2週間）

0. **OIDCパッケージのセットアップ**
   - `lib/oidc/` ディレクトリ作成
   - `lib/oidc/moon.pkg.json` 作成
   - `@oauth2` パッケージへの依存設定

1. **ID Token型定義とパース** (`lib/oidc/id_token.mbt`)
   - JWT文字列の分割
   - Base64URLデコード
   - JSON→Claims変換
   - テスト作成

2. **TokenResponse拡張** (`lib/oauth2/types.mbt`)
   - `id_token` フィールド追加
   - JSONパース更新
   - テスト更新

3. **UserInfo実装** (`lib/oidc/userinfo.mbt`)
   - UserInfoRequest作成
   - HTTP GET実装
   - レスポンスパース
   - テスト作成

4. **nonce対応** (`lib/oauth2/authorization_request.mbt`)
   - Nonce型定義
   - AuthorizationRequestに追加
   - URL構築更新
   - テスト更新

5. **統合テスト** (`lib/keycloak_test/oidc_flow_test.mbt`)
   - KeycloakでOIDCフローテスト
   - ID Token受信確認
   - UserInfo取得確認

### Phase 2: セキュリティ強化（1-2週間）

6. **JWKS実装** (`lib/oidc/jwks.mbt`)
   - JWK型定義
   - JWKS取得
   - Key検索
   - テスト作成

7. **署名検証** (`lib/oidc/id_token.mbt`)
   - RS256検証実装
   - RSA公開鍵構築
   - 暗号ライブラリ統合
   - テスト作成

8. **Claims検証** (`lib/oidc/id_token.mbt`)
   - IdTokenValidator実装
   - 各クレーム検証
   - 統合検証
   - テスト作成

9. **統合テスト強化**
   - 署名検証テスト
   - Claims検証テスト
   - エラーケーステスト

### Phase 3: 高度な機能（1週間）

10. **Discovery Document** (`lib/oidc/discovery.mbt`)
    - ProviderMetadata型定義
    - Discovery取得
    - テスト作成

11. **OIDC Client統合API** (`lib/oidc/oidc_client.mbt`)
    - OidcClient実装
    - ヘルパーメソッド
    - テスト作成

12. **ドキュメント作成**
    - 使用ガイド
    - サンプルコード
    - APIリファレンス

## テスト戦略

### Unit Tests

各モジュールごとにホワイトボックステスト:

```
lib/oidc/
├── id_token_wbtest.mbt
│   ├── test_parse_valid_jwt
│   ├── test_parse_invalid_jwt
│   ├── test_base64url_decode
│   └── test_validate_claims
├── jwks_wbtest.mbt
│   ├── test_parse_jwks
│   ├── test_find_key
│   └── test_build_rsa_key
└── userinfo_wbtest.mbt
    ├── test_userinfo_request
    └── test_parse_userinfo
```

### Integration Tests (Keycloak)

実際のOIDCプロバイダーでのE2Eテスト:

```
lib/keycloak_test/
├── oidc_flow_test.mbt
│   ├── test_authorization_code_flow_with_id_token
│   ├── test_userinfo_endpoint
│   └── test_id_token_validation
└── discovery_test.mbt
    └── test_fetch_discovery_document
```

### Snapshot Tests

ID TokenやUserInfoのレスポンス形式を記録:

```moonbit
test "parse_google_id_token" {
  let jwt = "eyJhbGc..."
  let result = IdToken::parse(jwt)
  inspect!(result, content="Ok(IdToken { ... })")
}
```

## 参考資料

### 仕様書

- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html)
- [RFC 7519 - JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)
- [RFC 7515 - JSON Web Signature (JWS)](https://tools.ietf.org/html/rfc7515)
- [RFC 7517 - JSON Web Key (JWK)](https://tools.ietf.org/html/rfc7517)

### 実装参考

- [oauth2-rs](https://github.com/ramosbugs/oauth2-rs) - Rust implementation
- [go-oidc](https://github.com/coreos/go-oidc) - Go implementation
- [node-openid-client](https://github.com/panva/node-openid-client) - Node.js implementation

### セキュリティ

- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [OAuth 2.0 Security Best Current Practice](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)

## リスクと対策

### リスク1: RSA署名検証の実装難易度

**リスク**: `moonbitlang/x/crypto` にRSA署名検証機能がない可能性

**対策**:
- Phase 1では署名検証をスキップし、パース・利用のみ実装
- Phase 2でRSA検証を追加
- 必要に応じてFFI経由でネイティブ暗号ライブラリを使用

### リスク2: クロスプラットフォーム互換性

**リスク**: ネイティブとJSターゲットで暗号処理が異なる

**対策**:
- Phase 1から両ターゲットでテスト
- プラットフォーム固有の実装を分離（`_native.mbt`, `_js.mbt`）
- 統一されたインターフェースを提供

### リスク3: JWTライブラリ依存

**リスク**: 自前実装でバグやセキュリティ脆弱性が混入

**対策**:
- 十分なテストカバレッジ（80%以上）
- セキュリティレビュー
- Keycloakでの実際の検証
- 既存の実装（oauth2-rs等）を参考にする

### リスク4: 仕様の複雑さ

**リスク**: OIDC仕様が広範で、全機能の実装が困難

**対策**:
- 段階的な実装（Phase分割）
- 最小限の機能から開始
- 必須機能と推奨機能を明確に区別
- ドキュメントで対応範囲を明示

## 成功の基準

1. **機能的成功**
   - Keycloakとの統合テストが全てパス
   - ID Tokenの受信・パース・検証が動作
   - UserInfo Endpointからユーザー情報取得
   - Google、GitHub等の実プロバイダーで動作確認

2. **品質的成功**
   - テストカバレッジ80%以上
   - 全てのユニットテストがパス
   - 統合テストがパス
   - ドキュメントが整備されている

3. **セキュリティ的成功**
   - ID Token署名検証が正しく動作
   - Claims検証が全て実装
   - nonce検証が動作
   - 既知の脆弱性がない

4. **開発者体験的成功**
   - 5行以内でOIDCフローが書ける
   - エラーメッセージがわかりやすい
   - サンプルコードが動作する
   - ドキュメントが明確

## 次のステップ

1. **このSteeringドキュメントのレビュー**
   - 内容の確認
   - アプローチの妥当性確認
   - スコープの調整

2. **Phase 1の開始**
   - `lib/oauth2/id_token.mbt` の作成
   - ID Tokenの型定義とパース実装
   - 基本的なテスト作成

3. **定期的な進捗確認**
   - 各Phase完了後にレビュー
   - 問題があれば方針調整
   - 完了ドキュメントの作成

4. **CI/CDの更新**
   - OIDCテストの追加
   - テストカバレッジの監視
   - ドキュメント生成の自動化
