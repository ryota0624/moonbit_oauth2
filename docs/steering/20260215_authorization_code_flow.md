# Steering: 認可コードフロー実装

## 目的・背景

OAuth2の最も一般的な認証フロー「認可コードグラント（Authorization Code Grant）」を実装する。このフローは、サーバーサイドアプリケーションで推奨される最も安全な認証方式である。

### なぜ必要か
- OAuth2の基本的かつ最も重要なフロー
- CSRF攻撃を防ぐstateパラメータをサポート
- 後続のPKCE実装の基盤となる

## ゴール

### 作業完了時の状態
1. AuthorizationRequestで認可URLを生成できる
2. CSRF保護のためのstateパラメータがサポートされている
3. TokenRequestでトークンを取得できる
4. TokenResponseのJSONパースが実装されている
5. 基本的な統合テストが完成している

### 成功の基準
- 認可URLが正しい形式で生成される
- トークンリクエストが成功する
- テストが全て通る

## アプローチ

### 技術的アプローチ
1. **AuthorizationRequest**: 認可エンドポイント用のURLを構築
2. **TokenRequest**: トークンエンドポイントへPOSTリクエスト
3. **TokenResponse**: JSONレスポンスをパースしてTokenResponse型に変換
4. **テスト**: 各コンポーネントの単体テストと統合テスト

### OAuth2 認可コードフローの流れ
```
1. クライアント → 認可サーバー: 認可リクエスト（AuthorizationRequest）
   GET /authorize?response_type=code&client_id=xxx&redirect_uri=xxx&scope=xxx&state=xxx

2. ユーザー: 認証・承認

3. 認可サーバー → クライアント: リダイレクト with 認可コード
   redirect_uri?code=xxx&state=xxx

4. クライアント → 認可サーバー: トークンリクエスト（TokenRequest）
   POST /token
   grant_type=authorization_code&code=xxx&redirect_uri=xxx&client_id=xxx&client_secret=xxx

5. 認可サーバー → クライアント: トークンレスポンス（TokenResponse）
   {"access_token":"xxx","token_type":"Bearer","expires_in":3600,"refresh_token":"xxx"}
```

## スコープ

### 含むもの（Phase 1）

#### 1. AuthorizationRequest構造体
```moonbit
pub struct AuthorizationRequest {
  auth_url: AuthUrl
  client_id: ClientId
  redirect_uri: RedirectUrl
  scope: Option[Array[Scope]]
  state: CsrfToken
}
```

機能：
- 認可URLの生成（`build_authorization_url()`）
- stateパラメータの自動生成またはカスタム設定
- scopeの配列をスペース区切り文字列に変換
- response_type=code の固定

#### 2. TokenRequest構造体
```moonbit
pub struct TokenRequest {
  token_url: TokenUrl
  client_id: ClientId
  client_secret: ClientSecret
  code: String  // 認可コード
  redirect_uri: RedirectUrl
}
```

機能：
- トークンエンドポイントへのPOSTリクエスト
- application/x-www-form-urlencodedボディの構築
- Basic認証またはボディにクライアント認証情報を含める

#### 3. TokenResponseのJSONパース
既存のTokenResponse構造体に対して：
- JSONレスポンスからTokenResponseへの変換関数
- 必須フィールド（access_token, token_type）のバリデーション
- オプショナルフィールド（expires_in, refresh_token, scope）の処理

#### 4. AuthorizationCodeClient構造体
認可コードフロー全体を管理するクライアント：
```moonbit
pub struct AuthorizationCodeClient {
  client_id: ClientId
  client_secret: ClientSecret
  auth_url: AuthUrl
  token_url: TokenUrl
  redirect_uri: RedirectUrl
  http_client: OAuth2HttpClient
}
```

機能：
- `authorize()`: AuthorizationRequestを作成
- `exchange()`: 認可コードをトークンに交換

#### 5. テスト
- AuthorizationRequestのURL生成テスト
- TokenRequestのボディ構築テスト
- TokenResponseのJSONパーステスト
- エラーケースのテスト

### 含まないもの（後で実装）
- PKCE（Step 4で実装）
- トークンリフレッシュ
- 実際のOAuth2プロバイダとの統合テスト（モックのみ）
- ブラウザ統合

### 技術的制約
- 非同期処理（async/await）を使用
- mizchi/xのHTTPクライアントを活用
- 既存のHTTPクライアント実装を再利用

## 影響範囲

### 新規作成ファイル
```
lib/oauth2/
├── authorization_request.mbt      # 認可リクエスト
├── token_request.mbt              # トークンリクエスト
├── authorization_code_client.mbt  # 認可コードフローのクライアント
├── authorization_request_wbtest.mbt
├── token_request_wbtest.mbt
└── authorization_code_client_wbtest.mbt
```

### 変更ファイル
- `lib/oauth2/types.mbt`: TokenResponse用のJSON変換関数追加の可能性
- `lib/oauth2/http_client.mbt`: 必要に応じてヘルパー関数追加

## 実装計画

### Step 3.1: AuthorizationRequest実装（1-2時間）
- AuthorizationRequest構造体の定義
- build_authorization_url()の実装
- stateパラメータの生成
- scopeのハンドリング
- テスト作成

### Step 3.2: TokenRequest実装（1-2時間）
- TokenRequest構造体の定義
- リクエストボディの構築
- HTTPクライアントとの統合
- テスト作成

### Step 3.3: TokenResponseのJSONパース（1時間）
- parse_token_response()関数の実装
- JSONからTokenResponseへの変換
- エラーハンドリング
- テスト作成

### Step 3.4: AuthorizationCodeClient実装（1-2時間）
- AuthorizationCodeClient構造体の定義
- authorize()メソッド
- exchange()メソッド
- 統合テスト

### Step 3.5: 統合テストとドキュメント（1時間）
- エンドツーエンドのテスト
- 使用例のドキュメント

## リスクと対策

### リスク1: stateパラメータの生成
- **対策**: ランダムな文字列生成が必要。まずは簡単な実装から始める

### リスク2: JSONパースの複雑さ
- **対策**: 既存のextract_json_string_value()を拡張して使用

### リスク3: 非同期処理の複雑さ
- **対策**: 既存のHTTPクライアント実装パターンを踏襲

## 参考資料
- [RFC 6749: Section 4.1 - Authorization Code Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1)
- [RFC 6749: Section 5.1 - Successful Response](https://datatracker.ietf.org/doc/html/rfc6749#section-5.1)
- [Rust oauth2 crate - Authorization Code Grant](https://docs.rs/oauth2/latest/oauth2/)

## 次のステップ
1. このsteeringドキュメントのレビューと承認
2. AuthorizationRequestの実装開始
3. TokenRequestの実装
4. 統合テスト
