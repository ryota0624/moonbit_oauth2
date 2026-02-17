# Steering: Google OAuth2/OIDC サポート実装

## 目的・背景

Google認証に対応することで、ライブラリの実用性を高め、実際のプロダクションユースケースでの利用を可能にする。
Googleは最も広く使われているOAuth2/OIDCプロバイダーの一つであり、このサポートはライブラリの価値を大きく向上させる。

## ゴール

1. Googleの.well-known/openid-configuration（Discovery Document）からエンドポイント情報を自動取得できること
2. Google公開鍵を使ったID Tokenの署名検証ができること
3. Googleとの連携サンプルコード（examples/google/）を提供すること
4. 実際のGoogle OAuth2フローで動作することを統合テストで検証すること

## 現状分析

### 既存実装の確認

既に以下が実装済み：
- OAuth2基本フロー（Authorization Code Flow、PKCE）
- OIDC基本機能（ID Token パース、UserInfo エンドポイント）
- JWT パース（Base64URL デコード、クレーム抽出）

参照ファイル：
- `lib/oidc/id_token.mbt` - ID Tokenパース機能
- `lib/oidc/userinfo.mbt` - UserInfo エンドポイント実装
- `lib/authorization_request.mbt` - 認可リクエスト
- `lib/token_request.mbt` - トークン交換

### 不足している機能

Google OAuth2を完全にサポートするには、以下が必要：

1. **Discovery Document対応**
   - エンドポイントURLを.well-known/openid-configurationから取得
   - 動的にエンドポイントを構成

2. **JWKS (JSON Web Key Set)サポート**
   - Google公開鍵の取得（https://www.googleapis.com/oauth2/v3/certs）
   - 公開鍵のキャッシング
   - kid（Key ID）によるキー選択

3. **ID Token署名検証**
   - RS256アルゴリズムでの署名検証
   - Google公開鍵を使った検証
   - exp（有効期限）、aud（audience）、iss（issuer）の検証

4. **Google固有のエンドポイント**
   - Authorization: `https://accounts.google.com/o/oauth2/v2/auth`
   - Token: `https://oauth2.googleapis.com/token`
   - UserInfo: `https://openidconnect.googleapis.com/v1/userinfo`
   - Discovery: `https://accounts.google.com/.well-known/openid-configuration`
   - JWKS: `https://www.googleapis.com/oauth2/v3/certs`

## アプローチ

### Phase 1: Discovery Document対応

1. **DiscoveryDocument構造体の実装**
   ```moonbit
   pub struct DiscoveryDocument {
     issuer: String
     authorization_endpoint: String
     token_endpoint: String
     userinfo_endpoint: String
     jwks_uri: String
     // その他のフィールド
   }
   ```

2. **Discovery Documentの取得関数**
   ```moonbit
   pub async fn fetch_discovery_document(
     issuer_url: String,
     http_client: OAuth2HttpClient
   ) -> Result[DiscoveryDocument, OAuth2Error]
   ```

3. **GoogleOAuth2Providerヘルパー**
   - Googleのissuer URLをデフォルト設定
   - Discovery Documentから必要な情報を取得
   - 既存の型（AuthUrl、TokenUrl等）へのマッピング

### Phase 2: JWKS対応

1. **JsonWebKey構造体**
   ```moonbit
   pub struct JsonWebKey {
     kty: String  // Key Type (RSA)
     use_: String // Public Key Use (sig)
     kid: String  // Key ID
     alg: String  // Algorithm (RS256)
     n: String    // RSA Modulus (Base64URL)
     e: String    // RSA Exponent (Base64URL)
   }
   ```

2. **JsonWebKeySet構造体**
   ```moonbit
   pub struct JsonWebKeySet {
     keys: Array[JsonWebKey]
   }
   ```

3. **JWKS取得関数**
   ```moonbit
   pub async fn fetch_jwks(
     jwks_uri: String,
     http_client: OAuth2HttpClient
   ) -> Result[JsonWebKeySet, OAuth2Error]
   ```

4. **キーキャッシング**
   - JWKSのキャッシュ機構（TTL付き）
   - 効率的なキー選択（kidによる検索）

### Phase 3: ID Token署名検証

1. **RS256署名検証の実装**
   - moonbitlang/x/cryptoライブラリの活用
   - RSA公開鍵による署名検証

2. **IdToken検証関数**
   ```moonbit
   pub fn IdToken::verify(
     self: IdToken,
     jwks: JsonWebKeySet,
     expected_audience: String,
     expected_issuer: String
   ) -> Result[Unit, OAuth2Error]
   ```

3. **検証項目**
   - 署名の正当性（RS256）
   - exp（有効期限）の確認
   - aud（audience = client_id）の確認
   - iss（issuer = https://accounts.google.com）の確認
   - nonceの確認（オプション、リプレイ攻撃対策）

### Phase 4: Google統合とサンプル

1. **GoogleOAuth2Clientヘルパー**
   - シンプルなAPI
   - Discovery Documentの自動取得
   - ID Token検証の自動化

2. **使用例（examples/google/）**
   - Web Server Flow（Authorization Code + PKCE）
   - ID Tokenの取得と検証
   - UserInfo取得
   - リフレッシュトークン

3. **統合テスト**
   - Google OAuth2 Playgroundを使ったテスト
   - または、開発用Googleプロジェクトでの実環境テスト

## スコープ

### 含むもの
- Discovery Document対応（Phase 1）
- JWKS対応（Phase 2）
- ID Token署名検証（Phase 3）
- Google連携サンプル（Phase 4）
- 統合テスト
- ドキュメント（使用ガイド、API説明）

### 含まないもの
- 他のプロバイダー固有実装（GitHub、Facebook等）
  - 理由: Googleで確立したパターンを他プロバイダーへ展開できる
- Google APIs（Gmail、Drive等）のSDK
  - 理由: OAuth2/OIDCライブラリのスコープ外
- Google Sign-In JavaScript ライブラリとの統合
  - 理由: このライブラリはサーバーサイド向け

## 影響範囲

### 新規ファイル
- `lib/oidc/discovery.mbt` - Discovery Document機能
- `lib/oidc/jwks.mbt` - JWKS関連機能
- `lib/oidc/verification.mbt` - ID Token署名検証
- `lib/providers/google.mbt` - Googleプロバイダー固有実装
- `examples/google/main.mbt` - Google連携サンプル
- `examples/google/README.md` - サンプルドキュメント

### 変更ファイル
- `lib/oidc/id_token.mbt` - 検証機能の追加（署名検証メソッド）
- `lib/http_client.mbt` - GETメソッドの実装（Discovery、JWKS取得用）
- `moon.mod.json` - 必要に応じた依存関係の追加
- `README.mbt.md` - Google連携の説明追加

### 依存関係
- moonbitlang/x/crypto - RSA署名検証用
- 既存: moonbitlang/x/codec/base64 - Base64URL処理
- 既存: @json - JSON処理

## 技術的決定事項

### RS256署名検証の実装方針
- moonbitlang/x/cryptoライブラリを使用（利用可能な場合）
- 不可能な場合: 外部検証サービスの利用または検証スキップオプション提供

### Discovery Documentのキャッシング
- メモリ内キャッシュ（TTL: 24時間）
- 理由: Googleの設定は頻繁に変更されないため

### JWKSのキャッシング
- メモリ内キャッシュ（TTL: 1時間）
- 理由: 公開鍵はローテーションされることがあるため、適度な更新が必要

### エラーハンドリング
- Discovery取得失敗 → OAuth2Error::new_other()
- JWKS取得失敗 → OAuth2Error::new_other()
- 署名検証失敗 → OAuth2Error::new_other()（詳細なエラーメッセージを含む）

## セキュリティ考慮事項

1. **HTTPS必須**
   - すべてのGoogle OAuth2通信はHTTPSで行う
   - HTTP接続は拒否される（Google側の要件）

2. **ID Token検証の必須項目**
   - 署名検証（RS256）
   - exp（有効期限）確認
   - aud（client_id）確認
   - iss（https://accounts.google.com）確認

3. **CSRF保護**
   - stateパラメータの使用（既存実装で対応済み）

4. **PKCE使用推奨**
   - 公開クライアント（SPAなど）では必須
   - サンプルコードでPKCEをデフォルト使用

## 成功基準

1. Discovery Documentから正しくエンドポイントを取得できること
2. JWKSからGoogle公開鍵を取得できること
3. Google ID Tokenの署名を正しく検証できること
4. サンプルコードでGoogle OAuth2フローが完動すること
5. 全テストがパスすること（既存 + 新規）
6. ドキュメントが整備されていること

## 参考資料

### Google公式ドキュメント
- [OpenID Connect | Sign in with Google](https://developers.google.com/identity/openid-connect/openid-connect)
- [Using OAuth 2.0 to Access Google APIs](https://developers.google.com/identity/protocols/oauth2)
- [Using OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)

### RFC仕様
- RFC 6749: OAuth 2.0 Authorization Framework
- RFC 7636: PKCE (Proof Key for Code Exchange)
- RFC 7517: JSON Web Key (JWK)
- RFC 7519: JSON Web Token (JWT)
- OpenID Connect Core 1.0

### Google Endpoints
- Discovery: https://accounts.google.com/.well-known/openid-configuration
- Authorization: https://accounts.google.com/o/oauth2/v2/auth
- Token: https://oauth2.googleapis.com/token
- UserInfo: https://openidconnect.googleapis.com/v1/userinfo
- JWKS: https://www.googleapis.com/oauth2/v3/certs

## 実装順序

### Week 1: Discovery & JWKS
1. Discovery Document実装（2-3時間）
2. JWKS実装（2-3時間）
3. テスト作成（1-2時間）

### Week 2: ID Token検証
1. RS256署名検証の調査・実装（3-4時間）
2. IdToken検証ロジック実装（2-3時間）
3. テスト作成（1-2時間）

### Week 3: Google統合
1. GoogleOAuth2Clientヘルパー実装（2-3時間）
2. サンプルコード作成（2-3時間）
3. 統合テスト（1-2時間）

### Week 4: ドキュメント・仕上げ
1. ドキュメント作成（2-3時間）
2. コードレビュー・リファクタリング（1-2時間）
3. 最終テスト・検証（1-2時間）

**合計推定工数: 20-30時間**

## 懸念事項・リスク

### リスク1: RS256署名検証の実装難易度
- **影響度**: 高
- **対策**: moonbitlang/x/cryptoライブラリの調査を最優先で実施
- **代替案**: 署名検証はスキップし、他の検証項目（exp、aud、iss）のみ実施（セキュリティレベルは低下）

### リスク2: MoonBit非同期処理の制約
- **影響度**: 中
- **対策**: 既存のHTTPクライアント実装パターンを踏襲
- **代替案**: 同期的な実装も提供

### リスク3: Google APIレート制限
- **影響度**: 低
- **対策**: JWKS、Discovery Documentのキャッシング実装
- **影響**: 通常の使用では問題ない（制限が緩い）

## 次のステップ

1. RS256署名検証の実装可能性調査（moonbitlang/x/cryptoの確認）
2. Discovery Document実装（lib/oidc/discovery.mbt）
3. JWKS実装（lib/oidc/jwks.mbt）
4. ID Token署名検証実装（lib/oidc/verification.mbt）
5. Google統合実装（lib/providers/google.mbt）
6. サンプル作成（examples/google/）
7. テスト・ドキュメント整備
