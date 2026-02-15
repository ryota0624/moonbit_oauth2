# Steering: OAuth2追加認証フロー実装（Step 5）

## 目的・背景

OAuth2クライアントライブラリの追加認証フローを実装します。既にAuthorization Code Flow（PKCE対応）が実装されているため、残りの主要なフローを追加します。

### なぜ必要か
- **Client Credentials Grant**: マシン間通信（M2M）で使用される一般的なフロー
- **Resource Owner Password Credentials Grant**: レガシーシステムとの互換性維持に必要（非推奨だが実用上必要）
- RFC 6749の主要フローを完全にカバーするため

## ゴール

### 作業完了時の状態
1. Client Credentials Grantの完全な実装
2. Resource Owner Password Credentials Grantの完全な実装
3. 各フローのテストコード（各8-10テスト）
4. 既存コードとの一貫性のある設計

### 成功の基準
- 全テストがパスする
- 既存のTokenResponseと統合される
- OAuth2Errorによる一貫したエラーハンドリング
- ドキュメントコメントが完備されている

## アプローチ

### 技術的アプローチ
1. **既存実装の再利用**: TokenRequestの設計パターンを踏襲
2. **型安全性**: MoonBitの型システムを活用
3. **段階的実装**: Client Credentials → Password Credentialsの順で実装

### 設計方針
- 各フローに専用の構造体を作成（ClientCredentialsRequest, PasswordRequest）
- build_request_body(), execute()メソッドで既存のパターンを踏襲
- TokenResponse, OAuth2Errorを共通で使用
- HTTPクライアント層（OAuth2HttpClient）は既存のものを再利用

## スコープ

### 含むもの

#### 1. Client Credentials Grant（RFC 6749 Section 4.4）
- **ClientCredentialsRequest構造体**
  - token_url: TokenUrl
  - client_id: ClientId
  - client_secret: ClientSecret
  - scope: Array[Scope] (optional)
  - grant_type: "client_credentials"

- **主要メソッド**
  - `ClientCredentialsRequest::new()`
  - `ClientCredentialsRequest::build_request_body() -> String`
  - `ClientCredentialsRequest::get_auth_header() -> String`
  - `ClientCredentialsRequest::execute(http_client) -> Result[TokenResponse, OAuth2Error]`

- **リクエストパラメータ**
  - grant_type: "client_credentials" (必須)
  - client_id: クライアントID (必須)
  - client_secret: クライアントシークレット (必須)
  - scope: スコープ (オプション)

#### 2. Resource Owner Password Credentials Grant（RFC 6749 Section 4.3）
- **PasswordRequest構造体**
  - token_url: TokenUrl
  - client_id: ClientId
  - client_secret: ClientSecret (optional)
  - username: String
  - password: String
  - scope: Array[Scope] (optional)
  - grant_type: "password"

- **主要メソッド**
  - `PasswordRequest::new()`
  - `PasswordRequest::build_request_body() -> String`
  - `PasswordRequest::get_auth_header() -> String?`
  - `PasswordRequest::execute(http_client) -> Result[TokenResponse, OAuth2Error]`

- **リクエストパラメータ**
  - grant_type: "password" (必須)
  - username: ユーザー名 (必須)
  - password: パスワード (必須)
  - client_id: クライアントID (必須)
  - client_secret: クライアントシークレット (オプション)
  - scope: スコープ (オプション)

#### 3. テストコード
- **client_credentials_wbtest.mbt**: 8-10テスト
  - ClientCredentialsRequest::newのテスト
  - build_request_bodyのテスト（各パラメータ）
  - scopeのハンドリング（空、単一、複数）
  - get_auth_headerのテスト

- **password_request_wbtest.mbt**: 8-10テスト
  - PasswordRequest::newのテスト
  - build_request_bodyのテスト（各パラメータ）
  - client_secretありなしのケース
  - scopeのハンドリング
  - get_auth_headerのテスト（secretありなし）

### 含まないもの
- Implicit Grant（セキュリティ上非推奨）
- Device Authorization Flow（Phase 2）
- Refresh Token Request（別途実装予定）
- トークンの自動リフレッシュ（Phase 2）

## 影響範囲

### 新規作成ファイル
```
lib/oauth2/
├── client_credentials.mbt          # Client Credentials Grant実装
├── client_credentials_wbtest.mbt   # Client Credentialsテスト
├── password_request.mbt            # Password Grant実装
└── password_request_wbtest.mbt     # Password Requestテスト
```

### 変更ファイル
- `lib/oauth2/moon.pkg`: パッケージの公開APIに新規構造体を追加（必要な場合）
- `lib/oauth2/pkg.generated.mbti`: 自動生成インターフェースの更新

### 参照するファイル（変更なし）
- `lib/oauth2/types.mbt`: 基本型（ClientId, TokenResponse等）
- `lib/oauth2/error.mbt`: OAuth2Error
- `lib/oauth2/http_client.mbt`: HTTPクライアント、url_encode, base64等
- `lib/oauth2/http_types.mbt`: HTTP型定義
- `lib/oauth2/token_request.mbt`: parse_token_response関数を再利用

## 実装計画

### Step 5.1: Client Credentials Grant実装（1-2時間）

#### 5.1.1: client_credentials.mbt実装
- ClientCredentialsRequest構造体の定義
- new()コンストラクタ
- build_request_body()メソッド
- get_auth_header()メソッド
- execute()メソッド（非同期）
- RFC 6749 Section 4.4に準拠

#### 5.1.2: client_credentials_wbtest.mbt実装
- 基本的なテスト（8-10テスト）
  - [ ] new()の基本テスト
  - [ ] build_request_body()のテスト
  - [ ] grant_typeが"client_credentials"であることを確認
  - [ ] client_id/client_secretの含有確認
  - [ ] scopeなしのケース
  - [ ] scope単一のケース
  - [ ] scope複数のケース
  - [ ] get_auth_header()のテスト
  - [ ] リクエストボディのurl encoding確認

#### 5.1.3: テスト実行と修正
```bash
moon test
```

### Step 5.2: Password Credentials Grant実装（1-2時間）

#### 5.2.1: password_request.mbt実装
- PasswordRequest構造体の定義
- new()コンストラクタ
- build_request_body()メソッド
- get_auth_header()メソッド（client_secretありの場合のみ）
- execute()メソッド（非同期）
- RFC 6749 Section 4.3に準拠
- **セキュリティ警告**: 非推奨フローであることをコメントに明記

#### 5.2.2: password_request_wbtest.mbt実装
- 基本的なテスト（8-10テスト）
  - [ ] new()の基本テスト
  - [ ] build_request_body()のテスト
  - [ ] grant_typeが"password"であることを確認
  - [ ] username/passwordの含有確認
  - [ ] client_secretありのケース
  - [ ] client_secretなしのケース
  - [ ] scopeなしのケース
  - [ ] scope単一のケース
  - [ ] scope複数のケース
  - [ ] get_auth_header()のテスト（secretありなし）

#### 5.2.3: テスト実行と修正
```bash
moon test
```

### Step 5.3: 統合テストと最終確認（30分-1時間）

#### 5.3.1: 統合テストの追加（オプション）
- integration_test.mbtに追加テストを記述（必要に応じて）
- モックサーバーでのテスト

#### 5.3.2: 最終テスト実行
```bash
moon test
moon info && moon fmt
```

#### 5.3.3: 完了ドキュメント作成
- `docs/completed/20260215_oauth2_additional_flows.md`の作成

## 技術的決定事項

### 1. TokenResponseの再利用
**決定**: 既存のTokenResponseをそのまま使用
- **理由**: すべてのOAuth2フローで同じレスポンスフォーマット
- **実装**: parse_token_response()関数を共有

### 2. エラーハンドリングの統一
**決定**: OAuth2Errorで統一
- **理由**: 既存実装との一貫性
- **実装**: parse_oauth2_error()を再利用

### 3. Scopeの扱い
**決定**: Array[Scope]で統一
- **理由**: 既存のAuthorizationRequest/TokenRequestと同じパターン
- **実装**: build_scope_string()を使用（必要に応じてhttp_client.mbtに移動）

### 4. Basic認証ヘッダー
**決定**: build_basic_auth_header()を再利用
- **理由**: 既存実装との一貫性
- **実装**: client_id/client_secretをBase64エンコード

### 5. Password Grantの非推奨警告
**決定**: コードコメントで明示的に警告
- **理由**: RFC 6749でも非推奨とされている
- **実装**: ドキュメントコメントに以下を記載:
```moonbit
/// WARNING: Resource Owner Password Credentials Grant is deprecated
/// and should only be used for legacy systems. Consider using
/// Authorization Code Grant with PKCE instead.
```

## コード例

### Client Credentials Grantの使用例
```moonbit
// Create a client credentials request
let request = ClientCredentialsRequest::new(
  token_url: TokenUrl::new("https://example.com/oauth/token"),
  client_id: ClientId::new("my-client-id"),
  client_secret: ClientSecret::new("my-client-secret"),
  scope: [Scope::new("read"), Scope::new("write")],
)

// Execute the request
let http_client = OAuth2HttpClient::new()
let result = request.execute(http_client)

match result {
  Ok(token_response) => {
    println("Access Token: \{token_response.access_token()}")
  }
  Err(error) => {
    println("Error: \{error}")
  }
}
```

### Password Grantの使用例
```moonbit
// WARNING: This grant type is deprecated!
let request = PasswordRequest::new(
  token_url: TokenUrl::new("https://example.com/oauth/token"),
  client_id: ClientId::new("my-client-id"),
  client_secret: Some(ClientSecret::new("my-client-secret")),
  username: "user@example.com",
  password: "user-password",
  scope: [Scope::new("read")],
)

// Execute the request
let http_client = OAuth2HttpClient::new()
let result = request.execute(http_client)

match result {
  Ok(token_response) => {
    println("Access Token: \{token_response.access_token()}")
  }
  Err(error) => {
    println("Error: \{error}")
  }
}
```

## リスクと対策

### リスク1: Password Grantのセキュリティ懸念
- **対策**: ドキュメントで非推奨を明記、代替手段（Authorization Code + PKCE）を推奨

### リスク2: 既存コードとの統合
- **対策**: 既存のparse_token_response()を再利用、TokenResponseの変更不要

### リスク3: テストの非同期実行
- **対策**: 既存のテストパターンを踏襲、リクエスト構造の検証に集中

## 参考資料

### 仕様書
- [RFC 6749 Section 4.3: Resource Owner Password Credentials Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.3)
- [RFC 6749 Section 4.4: Client Credentials Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)

### 既存実装
- `lib/oauth2/token_request.mbt`: 参考実装
- `lib/oauth2/authorization_request.mbt`: Scopeの扱い方
- `docs/steering/20260215_oauth2_implementation_planning.md`: 全体計画

## 見積もり

- **Step 5.1**: 1-2時間（Client Credentials）
- **Step 5.2**: 1-2時間（Password Credentials）
- **Step 5.3**: 30分-1時間（統合テスト、ドキュメント）
- **合計**: 3-5時間

## 次のステップ

1. このsteeringドキュメントの確認
2. Client Credentials Grant実装開始
3. Password Credentials Grant実装
4. テスト実行と修正
5. 完了ドキュメント作成
6. Git Commit
