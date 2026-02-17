# Steering: Discovery Document実装（Phase 1）

## 目的・背景

OpenID Connect Discovery（RFC 8414）は、OAuth2/OIDCプロバイダーのメタデータを標準化された方法で取得する仕組みです。
Google OAuth2対応の第一歩として、Discovery Document機能を実装することで、エンドポイントURLをハードコードせずに動的に取得できるようにします。

これにより、以下のメリットが得られます：
- エンドポイントURLの自動取得（authorization_endpoint、token_endpoint等）
- プロバイダーの設定変更に自動で追従
- 複数のOAuth2プロバイダーへの拡張が容易

## ゴール

1. `.well-known/openid-configuration`からDiscovery Documentを取得できること
2. 取得したメタデータから必要なエンドポイントURLを抽出できること
3. 既存の型（AuthUrl、TokenUrl等）へのマッピングができること
4. Googleの実際のDiscovery Documentで動作確認できること
5. ユニットテストと統合テストがパスすること

## アプローチ

### 1. DiscoveryDocument構造体の設計

```moonbit
pub struct DiscoveryDocument {
  // Required fields (OpenID Connect Discovery)
  issuer : String                      // https://accounts.google.com
  authorization_endpoint : String      // Authorization URL
  token_endpoint : String              // Token URL
  jwks_uri : String                    // JWKS endpoint

  // Recommended fields
  userinfo_endpoint : String?          // UserInfo URL
  scopes_supported : Array[String]?    // Supported scopes
  response_types_supported : Array[String]? // Supported response types

  // Optional fields (useful for future features)
  revocation_endpoint : String?        // Token revocation
  introspection_endpoint : String?     // Token introspection
  code_challenge_methods_supported : Array[String]? // PKCE methods
}
```

**設計判断:**
- 必須フィールド: OpenID Connect Discovery仕様の必須項目
- オプションフィールド: 将来の拡張に備えて主要な項目を含める
- String?型: 存在しない場合はNoneを返す

### 2. Discovery Document取得関数

```moonbit
pub async fn fetch_discovery_document(
  issuer_url : String,
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[DiscoveryDocument, @oauth2.OAuth2Error]
```

**実装手順:**
1. issuer_urlに`/.well-known/openid-configuration`を追加
2. HTTP GETリクエストを送信
3. JSONレスポンスをパース
4. DiscoveryDocument構造体に変換
5. 必須フィールドの検証

**エラーハンドリング:**
- HTTP通信エラー → OAuth2Error::new_other("Failed to fetch discovery document: ...")
- JSONパースエラー → OAuth2Error::new_other("Failed to parse discovery document: ...")
- 必須フィールド欠落 → OAuth2Error::new_other("Missing required field in discovery document: ...")

### 3. 既存の型へのマッピング

```moonbit
pub fn DiscoveryDocument::authorization_url(self : DiscoveryDocument) -> @oauth2.AuthUrl
pub fn DiscoveryDocument::token_url(self : DiscoveryDocument) -> @oauth2.TokenUrl
pub fn DiscoveryDocument::userinfo_url(self : DiscoveryDocument) -> @oidc.UserInfoUrl?
```

これにより、既存のコードベースとシームレスに統合できます。

### 4. Googleプロバイダーヘルパー（簡易版）

```moonbit
pub fn google_issuer_url() -> String {
  "https://accounts.google.com"
}

pub async fn fetch_google_discovery(
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[DiscoveryDocument, @oauth2.OAuth2Error] {
  fetch_discovery_document(google_issuer_url(), http_client)
}
```

**設計判断:**
- シンプルなヘルパー関数として実装
- 将来的にGoogleProviderクラスに拡張可能

### 5. HTTPクライアントのGETメソッド実装

既存の`OAuth2HttpClient`にGETメソッドを追加する必要があります：

```moonbit
// lib/http_client.mbtに追加
pub async fn OAuth2HttpClient::get(
  self : OAuth2HttpClient,
  url : String,
  headers : HttpHeaders,
) -> Result[HttpResponse, OAuth2Error]
```

**実装詳細:**
- `mizchi/x`の`@http.get()`を使用
- 既存のPOSTメソッドと同じエラーハンドリングパターン
- デバッグ出力の対応（self.debugフラグ）

## スコープ

### 含むもの
- DiscoveryDocument構造体と関連型の定義
- fetch_discovery_document()関数の実装
- JSONパース・検証ロジック
- OAuth2HttpClient::get()メソッドの実装
- Googleプロバイダーヘルパー関数
- ユニットテスト（15-20テスト）
- 統合テスト（Googleの実際のDiscovery Documentを使用）
- ドキュメントコメント（各関数・構造体）

### 含まないもの
- Discovery Documentのキャッシング機構
  - 理由: Phase 2以降で実装（複雑性を増す）
- 他のプロバイダー固有実装（GitHub、Facebook等）
  - 理由: まずGoogleで動作確認してからパターン化
- Discovery DocumentのJWKS取得
  - 理由: Phase 2で実装（JWKS機能全体として）

## 影響範囲

### 新規ファイル
- `lib/oidc/discovery.mbt` - Discovery Document実装
  - DiscoveryDocument構造体
  - fetch_discovery_document()関数
  - JSONパース関数
  - ヘルパー関数

- `lib/oidc/discovery_wbtest.mbt` - ユニットテスト
  - JSONパーステスト（正常系）
  - JSONパーステスト（異常系）
  - フィールド検証テスト
  - マッピング関数テスト

### 変更ファイル
- `lib/http_client.mbt` - GETメソッド追加
  - OAuth2HttpClient::get()メソッド実装
  - 約20-30行追加

- `lib/http_client_wbtest.mbt` - GETメソッドテスト
  - GETメソッドの基本テスト
  - 約5-10テスト追加

- `lib/moon.pkg.json` - 依存関係確認（変更なしの見込み）
  - 既存の依存関係で対応可能

### ディレクトリ構造
```
lib/
├── oidc/
│   ├── discovery.mbt           # 新規
│   ├── discovery_wbtest.mbt    # 新規
│   ├── id_token.mbt            # 既存
│   ├── token_response.mbt      # 既存
│   └── userinfo.mbt            # 既存
├── http_client.mbt             # 変更
└── http_client_wbtest.mbt      # 変更
```

## 技術的決定事項

### 1. Discovery DocumentのURL構成
- 標準: `{issuer}/.well-known/openid-configuration`
- 例: `https://accounts.google.com/.well-known/openid-configuration`
- 実装: `issuer_url + "/.well-known/openid-configuration"`

### 2. 必須フィールドの定義
OpenID Connect Discovery 1.0仕様に従う：
- issuer（必須）
- authorization_endpoint（必須）
- token_endpoint（必須）
- jwks_uri（必須）

その他はオプション（String?型）

### 3. エラーメッセージの詳細度
- HTTP通信エラー: ステータスコードとURLを含める
- JSONパースエラー: パース失敗箇所を含める（可能なら）
- フィールド欠落: 欠落フィールド名を明示

### 4. HTTPヘッダー
```moonbit
let headers : HttpHeaders = {}
headers["Accept"] = "application/json"
headers["User-Agent"] = "moonbit-oauth2/0.1.2"
```

## 実装順序

### Step 1: HTTPクライアントGETメソッド実装（30分）
1. `lib/http_client.mbt`に`OAuth2HttpClient::get()`を追加
2. `@http.get()`の統合
3. エラーハンドリング
4. デバッグ出力対応
5. 基本テスト作成

### Step 2: DiscoveryDocument構造体（30分）
1. `lib/oidc/discovery.mbt`ファイル作成
2. DiscoveryDocument構造体定義
3. ゲッターメソッド実装
4. 既存型へのマッピング関数

### Step 3: JSONパース実装（1時間）
1. `parse_discovery_document()`関数実装
2. 必須フィールドの抽出と検証
3. オプションフィールドの抽出
4. エラーハンドリング
5. ユニットテスト（10-15テスト）

### Step 4: Discovery Document取得関数（30分）
1. `fetch_discovery_document()`関数実装
2. URL構成
3. HTTP GET実行
4. パース処理
5. エラーハンドリング

### Step 5: Googleプロバイダーヘルパー（15分）
1. `google_issuer_url()`関数
2. `fetch_google_discovery()`関数
3. 基本テスト

### Step 6: 統合テスト（30分）
1. Googleの実際のDiscovery Documentを取得
2. パース成功の確認
3. エンドポイントURLの検証
4. テストスクリプト作成

**合計推定工数: 3.5時間**

## テスト戦略

### ユニットテスト（15-20テスト）

1. **JSONパーステスト（正常系）**
   ```moonbit
   test "parse valid discovery document with all fields"
   test "parse valid discovery document with required fields only"
   test "parse valid discovery document with optional fields"
   ```

2. **JSONパーステスト（異常系）**
   ```moonbit
   test "parse fails with missing issuer"
   test "parse fails with missing authorization_endpoint"
   test "parse fails with missing token_endpoint"
   test "parse fails with missing jwks_uri"
   test "parse fails with invalid JSON"
   test "parse fails with non-object JSON"
   ```

3. **フィールド検証テスト**
   ```moonbit
   test "issuer returns correct value"
   test "authorization_endpoint returns correct value"
   test "token_endpoint returns correct value"
   test "jwks_uri returns correct value"
   test "optional field returns None when missing"
   test "optional field returns Some when present"
   ```

4. **マッピング関数テスト**
   ```moonbit
   test "authorization_url creates AuthUrl correctly"
   test "token_url creates TokenUrl correctly"
   test "userinfo_url creates UserInfoUrl correctly"
   test "userinfo_url returns None when endpoint missing"
   ```

### 統合テスト

1. **Googleの実Discovery Document取得**
   ```moonbit
   // examples/google_discovery/main.mbt
   pub fn main {
     let http_client = @oauth2.OAuth2HttpClient::new()
     let result = @oidc.fetch_google_discovery(http_client)

     match result {
       Ok(doc) => {
         println("Issuer: \{doc.issuer}")
         println("Auth URL: \{doc.authorization_endpoint}")
         println("Token URL: \{doc.token_endpoint}")
         println("JWKS URI: \{doc.jwks_uri}")
       }
       Err(e) => {
         println("Error: \{e.message()}")
       }
     }
   }
   ```

2. **テストスクリプト**
   ```bash
   # scripts/test_discovery.sh
   #!/bin/bash
   set -e

   echo "Testing Discovery Document implementation..."

   # Run unit tests
   moon test --target native
   moon test --target js

   # Run integration test
   echo "Fetching Google Discovery Document..."
   moon run examples/google_discovery --target native

   echo "All tests passed!"
   ```

## 検証項目

実装完了時に以下を確認：

- [ ] HTTPクライアントのGETメソッドが動作する
- [ ] DiscoveryDocument構造体が適切に定義されている
- [ ] JSONパースが正しく動作する（正常系・異常系）
- [ ] 必須フィールドの検証が行われる
- [ ] オプションフィールドが正しくハンドリングされる
- [ ] 既存型へのマッピングが正しく動作する
- [ ] Googleの実際のDiscovery Documentが取得できる
- [ ] 全ユニットテストがパスする（Native/JS両方）
- [ ] 統合テストがパスする
- [ ] ドキュメントコメントが適切に記述されている
- [ ] `moon fmt`でフォーマットされている
- [ ] `moon info`で`.mbti`の変更を確認

## 成功基準

1. ✅ Googleの実際のDiscovery Documentを取得し、パースできる
2. ✅ すべてのユニットテストがパスする（15-20テスト）
3. ✅ Native/JS両ターゲットで動作する
4. ✅ エラーハンドリングが適切に実装されている
5. ✅ 既存のテストが全てパスする（破壊的変更なし）
6. ✅ ドキュメントコメントが完備されている

## リスク・懸念事項

### リスク1: HTTP GETメソッドの実装
- **影響度**: 低
- **懸念**: `mizchi/x`の`@http.get()`の動作が不明
- **対策**: POSTメソッドの実装パターンを踏襲
- **代替案**: 成功実績のある別のHTTPライブラリ使用

### リスク2: Googleの実Discovery Documentの変更
- **影響度**: 極低
- **懸念**: テスト実行時にGoogleのエンドポイントが変更されている可能性
- **対策**: OpenID Connect Discovery仕様に準拠（後方互換性保証）
- **影響**: ほぼなし（Googleは互換性を重視）

### リスク3: MoonBitの非同期処理
- **影響度**: 低
- **懸念**: 非同期関数のテストがMoonBitでサポートされているか不明
- **対策**: 既存のHTTPクライアントテストパターンを踏襲
- **代替案**: CLIツール経由での統合テスト

## 次のステップ

実装完了後：
1. 完了ドキュメント作成（`docs/completed/20260217_discovery_document_implementation.md`）
2. Phase 2（JWKS実装）のsteeringドキュメント作成
3. コードレビュー
4. Git commit

## 参考資料

### OpenID Connect Discovery仕様
- [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html)
- [RFC 8414: OAuth 2.0 Authorization Server Metadata](https://datatracker.ietf.org/doc/html/rfc8414)

### Google固有のドキュメント
- [Google Discovery Document](https://accounts.google.com/.well-known/openid-configuration)
- [OpenID Connect | Sign in with Google](https://developers.google.com/identity/openid-connect/openid-connect)

### 既存実装の参考
- `lib/http_client.mbt` - HTTPクライアント実装
- `lib/oidc/userinfo.mbt` - HTTP GETの使用例（予定）
- `lib/oidc/id_token.mbt` - JSONパースの参考
