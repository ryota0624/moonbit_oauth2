# Steering: PKCE (Proof Key for Code Exchange) 実装

## 目的・背景

OAuth2のAuthorization Code Flowにおいて、公開クライアント（モバイルアプリやSPAなど）でclient_secretを安全に保持できない場合、PKCE（RFC 7636）を使用して認可コードの盗聴攻撃から保護する必要があります。

PKCEは以下の仕組みで機能します：
1. クライアントがランダムな`code_verifier`を生成
2. `code_verifier`から`code_challenge`を計算（SHA256ハッシュ、Base64URL エンコード）
3. 認可リクエストに`code_challenge`と`code_challenge_method`を含める
4. トークンリクエストに元の`code_verifier`を含める
5. サーバーが`code_verifier`から`code_challenge`を再計算して検証

## ゴール

- PKCEをサポートするOAuth2クライアントの実装
- 既存のAuthorizationCode Flowとシームレスに統合
- Native/JSの両方で動作する実装

## アプローチ

### 1. PkceCodeVerifier実装

```moonbit
pub struct PkceCodeVerifier {
  value : String
}

pub fn PkceCodeVerifier::new_random() -> PkceCodeVerifier
pub fn PkceCodeVerifier::new(value : String) -> PkceCodeVerifier
```

- ランダムな43～128文字のcode_verifierを生成
- 使用可能文字：A-Z, a-z, 0-9, -, ., _, ~（RFC 7636準拠）
- 最低限の長さ：43文字（256ビットのエントロピー）

### 2. PkceCodeChallenge実装

```moonbit
pub struct PkceCodeChallenge {
  value : String
  method : PkceCodeChallengeMethod
}

pub enum PkceCodeChallengeMethod {
  Plain
  S256  // SHA256
}

pub fn PkceCodeChallenge::from_verifier(
  verifier : PkceCodeVerifier,
  method : PkceCodeChallengeMethod
) -> PkceCodeChallenge
```

- `Plain`: code_challenge = code_verifier（後方互換性のため）
- `S256`: code_challenge = BASE64URL(SHA256(code_verifier))（推奨）
- MoonBitでSHA256を実装する必要がある（外部ライブラリまたは手動実装）

### 3. SHA256実装

MoonBitに標準のSHA256ライブラリがない場合、以下のオプション：
1. **手動実装**: SHA256アルゴリズムをMoonBitで実装（RFC 6234準拠）
2. **外部ライブラリ**: 利用可能なcryptoライブラリを探す
3. **プラットフォーム固有のFFI**: Native/JSそれぞれで実装

今回は**手動実装**を採用します（依存関係を最小限に保つため）。

### 4. Base64URL エンコーディング

RFC 4648のBase64URL variant:
- 標準Base64の`+`を`-`に、`/`を`_`に置換
- パディング`=`を削除

既存の`base64_encode`を拡張してBase64URLをサポート。

### 5. AuthorizationRequestへの統合

```moonbit
pub struct AuthorizationRequest {
  // ... 既存フィールド
  pkce_challenge : PkceCodeChallenge?
}

pub fn AuthorizationRequest::new_with_pkce(
  auth_url : AuthUrl,
  client_id : ClientId,
  redirect_uri : RedirectUrl,
  scope : Array[Scope],
  state : CsrfToken,
  pkce_challenge : PkceCodeChallenge
) -> AuthorizationRequest
```

### 6. TokenRequestへの統合

```moonbit
pub struct TokenRequest {
  // ... 既存フィールド
  pkce_verifier : PkceCodeVerifier?
}

pub fn TokenRequest::new_with_pkce(
  token_url : TokenUrl,
  client_id : ClientId,
  client_secret : ClientSecret?,  // PKCEでは不要な場合がある
  code : String,
  redirect_uri : RedirectUrl,
  pkce_verifier : PkceCodeVerifier
) -> TokenRequest
```

## スコープ

### 含む
- PkceCodeVerifier構造体と生成ロジック
- PkceCodeChallenge構造体とS256計算
- SHA256アルゴリズムの実装
- Base64URLエンコーディング
- AuthorizationRequestへのPKCE統合
- TokenRequestへのPKCE統合
- PKCE関連の包括的なテスト

### 含まない
- デバイス認可フロー（Phase 2）
- トークンリフレッシュの自動化（Phase 2）
- エラーリトライロジック（Phase 2）

## 影響範囲

### 変更ファイル
- `lib/oauth2/pkce.mbt`: PKCE関連の型と関数（新規）
- `lib/oauth2/sha256.mbt`: SHA256実装（新規）
- `lib/oauth2/http_client.mbt`: Base64URL エンコード追加
- `lib/oauth2/authorization_request.mbt`: PKCE challenge対応
- `lib/oauth2/token_request.mbt`: PKCE verifier対応

### テストファイル
- `lib/oauth2/pkce_wbtest.mbt`: PKCE型のテスト
- `lib/oauth2/sha256_wbtest.mbt`: SHA256実装のテスト
- `lib/oauth2/http_client_wbtest.mbt`: Base64URLテスト追加

## 実装順序

1. **Step 4.1**: SHA256実装とテスト
2. **Step 4.2**: Base64URLエンコーディング実装とテスト
3. **Step 4.3**: PkceCodeVerifier実装とテスト
4. **Step 4.4**: PkceCodeChallenge実装とテスト
5. **Step 4.5**: AuthorizationRequestへの統合
6. **Step 4.6**: TokenRequestへの統合
7. **Step 4.7**: PKCE統合テスト

## 参考資料

- [RFC 7636: Proof Key for Code Exchange by OAuth Public Clients](https://datatracker.ietf.org/doc/html/rfc7636)
- [RFC 6234: US Secure Hash Algorithms (SHA and SHA-based HMAC and HKDF)](https://datatracker.ietf.org/doc/html/rfc6234)
- [RFC 4648: The Base16, Base32, and Base64 Data Encodings](https://datatracker.ietf.org/doc/html/rfc4648#section-5)

## 成功基準

- [ ] PkceCodeVerifierが適切な長さとフォーマットで生成される
- [ ] PkceCodeChallengeがS256メソッドで正しく計算される
- [ ] SHA256実装がRFC 6234のテストベクターに合格
- [ ] Base64URLエンコーディングが正しく動作
- [ ] PKCE付きAuthorization Code Flowが正常に動作
- [ ] 全テストがパス（目標：+20テスト以上）
