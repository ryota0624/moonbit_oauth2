# Steering: ID Token署名検証実装（Phase 3）

## 目的・背景

ID Token（JWT形式）の署名検証は、OpenID Connectのセキュリティにおいて最も重要な要素の一つです。
署名検証により、ID Tokenが正規のプロバイダー（Google）から発行され、改ざんされていないことを保証できます。

Google OAuth2では、ID Tokenの署名検証が強く推奨されており（セキュリティベストプラクティス）、
本番環境では必須の機能となります。

## ゴール

1. RS256アルゴリズムでID Tokenの署名を検証できること
2. Google公開鍵（JWKS）を使った検証ができること
3. ID Tokenのクレーム検証（exp、aud、iss、nonce）ができること
4. 包括的な検証APIを提供すること
5. 実際のGoogle ID Tokenで動作確認できること
6. ユニットテストと統合テストがパスすること

## 前提条件

- Phase 1（Discovery Document実装）が完了していること
- Phase 2（JWKS実装）が完了していること
- moonbitlang/x/cryptoライブラリでRS256署名検証が可能であること

## アプローチ

### 1. RS256署名検証の実装

```moonbit
pub fn verify_rs256_signature(
  jwt_data : String,          // header.payload（署名対象データ）
  signature : String,          // signature部分（Base64URL）
  public_key_n : String,      // RSA Modulus（Base64URL）
  public_key_e : String,      // RSA Exponent（Base64URL）
) -> Result[Unit, @oauth2.OAuth2Error]
```

**実装手順:**
1. signatureをBase64URLデコード
2. public_key_n、public_key_eをデコードしてRSA公開鍵を構築
3. jwt_dataのSHA256ハッシュを計算
4. RSA署名検証アルゴリズムで検証
5. 検証結果を返す

**依存関係:**
- moonbitlang/x/crypto - RSA署名検証
- 既存: @base64 - Base64URLデコード
- 既存: @crypto - SHA256ハッシュ（またはmoonbitlang/x/crypto）

### 2. ID Token検証関数の拡張

既存の`IdToken`構造体に検証メソッドを追加：

```moonbit
pub fn IdToken::verify_signature(
  self : IdToken,
  jwks : @oidc.JsonWebKeySet,
) -> Result[Unit, @oauth2.OAuth2Error] {
  // 1. JWT headerからkidを取得
  // 2. JWKSからkidに対応する公開鍵を取得
  // 3. 公開鍵を使ってRS256署名を検証
}

pub fn IdToken::verify_claims(
  self : IdToken,
  expected_audience : String,   // client_id
  expected_issuer : String,     // https://accounts.google.com
  current_time : Int64,         // 現在のUNIXタイムスタンプ
  nonce : String?,              // オプション: nonceの検証
) -> Result[Unit, @oauth2.OAuth2Error] {
  // 1. exp（有効期限）の検証
  // 2. aud（audience）の検証
  // 3. iss（issuer）の検証
  // 4. nonce（オプション）の検証
}

pub fn IdToken::verify(
  self : IdToken,
  jwks : @oidc.JsonWebKeySet,
  expected_audience : String,
  expected_issuer : String,
  current_time : Int64,
  nonce : String?,
) -> Result[Unit, @oauth2.OAuth2Error] {
  // 署名検証とクレーム検証の両方を実行
  self.verify_signature(jwks)?
  self.verify_claims(expected_audience, expected_issuer, current_time, nonce)?
  Ok(())
}
```

**設計判断:**
- verify_signature: 署名検証のみ（暗号学的検証）
- verify_claims: クレーム検証のみ（ビジネスロジック検証）
- verify: 両方を実行（最も一般的なユースケース）

### 3. Google専用ヘルパー（専用ディレクトリに配置）

**重要: Google OAuth2実装は専用ディレクトリに配置します**

ディレクトリ構造：
```
lib/
├── providers/
│   └── google/
│       ├── google_oauth2.mbt       # Googleプロバイダーメイン
│       ├── google_oauth2_wbtest.mbt
│       └── README.md               # Google実装のドキュメント
```

Google専用ヘルパー実装：

```moonbit
// lib/providers/google/google_oauth2.mbt

///|
/// Google OAuth2 Provider
///
/// This module provides convenience functions for Google OAuth2/OIDC integration.
/// It wraps the core OAuth2 and OIDC functionality with Google-specific defaults.

///|
/// Google Issuer URL
pub fn google_issuer() -> String {
  "https://accounts.google.com"
}

///|
/// Fetch Google Discovery Document
pub async fn fetch_discovery(
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[@oidc.DiscoveryDocument, @oauth2.OAuth2Error] {
  @oidc.fetch_discovery_document(google_issuer(), http_client)
}

///|
/// Verify Google ID Token
///
/// This function performs comprehensive verification:
/// - Signature verification using Google's public keys (JWKS)
/// - Expiration check (exp)
/// - Audience check (aud must match client_id)
/// - Issuer check (iss must be https://accounts.google.com)
/// - Optional nonce check
pub async fn verify_id_token(
  id_token : @oidc.IdToken,
  client_id : String,
  http_client : @oauth2.OAuth2HttpClient,
  nonce : String?,
) -> Result[Unit, @oauth2.OAuth2Error] {
  // 1. Fetch Discovery Document
  let discovery = fetch_discovery(http_client)?

  // 2. Fetch JWKS
  let jwks = @oidc.fetch_jwks(discovery.jwks_uri, http_client)?

  // 3. Get current time
  let current_time = get_current_unix_time()

  // 4. Verify token
  id_token.verify(
    jwks,
    client_id,
    google_issuer(),
    current_time,
    nonce,
  )
}

///|
/// Get current UNIX timestamp (seconds since epoch)
fn get_current_unix_time() -> Int64 {
  // Implementation depends on MoonBit's time API
  // For now, we can use a placeholder or external function
  @time.now().unix_timestamp()
}
```

### 4. 統合例（すべてのPhaseを組み合わせ）

```moonbit
// examples/google/verify_id_token.mbt

pub fn main {
  let http_client = @oauth2.OAuth2HttpClient::new()
  let client_id = "YOUR_CLIENT_ID.apps.googleusercontent.com"

  // 1. Get ID Token (from authorization flow)
  let id_token_string = "eyJhbGc..." // Obtained from token response
  let id_token = @oidc.IdToken::parse(id_token_string)?

  // 2. Verify ID Token using Google helper
  match @providers.google.verify_id_token(
    id_token,
    client_id,
    http_client,
    None,  // No nonce in this example
  ) {
    Ok(_) => {
      println("ID Token is valid!")
      println("User ID: \{id_token.subject()}")
      println("Email: \{id_token.email().or("N/A")}")
    }
    Err(e) => {
      println("ID Token verification failed: \{e.message()}")
    }
  }
}
```

## スコープ

### 含むもの
- RS256署名検証の実装
- IdToken検証メソッド（verify_signature、verify_claims、verify）
- クレーム検証（exp、aud、iss、nonce）
- Google専用ヘルパー（lib/providers/google/）
- 現在時刻取得の実装
- ユニットテスト（25-30テスト）
- 統合テスト（実際のGoogle ID Tokenを使用）
- ドキュメントコメント
- 使用例（examples/google/）

### 含まないもの
- EC鍵（ES256等）の署名検証
  - 理由: GoogleはRS256を使用
- カスタムクレームの検証
  - 理由: 標準クレームのみサポート
- ID Tokenのキャッシング
  - 理由: アプリケーション側の責任
- トークンリフレッシュロジック
  - 理由: 別フェーズで実装

## 影響範囲

### 新規ファイル
- `lib/oidc/verification.mbt` - 署名検証実装
  - verify_rs256_signature()関数
  - Base64URLデコードヘルパー
  - RSA公開鍵構築ヘルパー

- `lib/oidc/verification_wbtest.mbt` - 検証機能のテスト
  - RS256署名検証テスト
  - クレーム検証テスト

- `lib/providers/google/google_oauth2.mbt` - Googleプロバイダー（新規ディレクトリ）
  - Google固有のヘルパー関数
  - 統合検証関数

- `lib/providers/google/google_oauth2_wbtest.mbt` - Googleプロバイダーテスト

- `lib/providers/google/README.md` - Google実装ドキュメント

- `examples/google/verify_id_token.mbt` - ID Token検証サンプル

- `examples/google/README.md` - サンプルドキュメント

### 変更ファイル
- `lib/oidc/id_token.mbt` - 検証メソッドの追加
  - verify_signature()メソッド
  - verify_claims()メソッド
  - verify()メソッド

- `moon.mod.json` - moonbitlang/x/crypto依存関係の追加（必要に応じて）

### ディレクトリ構造（最終形）
```
lib/
├── oauth2/
│   ├── types.mbt
│   ├── authorization_request.mbt
│   ├── token_request.mbt
│   ├── ... (他のOAuth2コア機能)
├── oidc/
│   ├── discovery.mbt           # Phase 1
│   ├── jwks.mbt                # Phase 2
│   ├── verification.mbt        # Phase 3（新規）
│   ├── id_token.mbt            # Phase 3（変更）
│   ├── token_response.mbt
│   └── userinfo.mbt
└── providers/
    └── google/                 # Google専用（新規ディレクトリ）
        ├── google_oauth2.mbt
        ├── google_oauth2_wbtest.mbt
        └── README.md

examples/
└── google/                     # Google使用例
    ├── verify_id_token.mbt
    ├── authorization_flow.mbt  # Phase 4で作成
    └── README.md
```

**設計方針:**
- `lib/oidc/`: 汎用的なOIDC機能（プロバイダー非依存）
- `lib/providers/google/`: Google固有の実装とヘルパー
- `examples/google/`: Google OAuth2の使用例

## 技術的決定事項

### 1. RS256署名検証の実装
- moonbitlang/x/cryptoライブラリを使用（利用可能な場合）
- 不可能な場合: エラーを返し、ドキュメントで外部検証を推奨

### 2. クレーム検証の基準
- **exp（有効期限）**: current_time < exp
  - 猶予時間: なし（厳密に検証）
- **aud（audience）**: expected_audience == aud（完全一致）
- **iss（issuer）**: expected_issuer == iss（完全一致）
- **nonce**: オプション、指定された場合のみ検証

### 3. エラーメッセージの詳細度
- 署名検証失敗: "Invalid ID Token signature"
- exp検証失敗: "ID Token has expired (exp: {exp}, now: {current_time})"
- aud検証失敗: "Invalid audience (expected: {expected}, actual: {actual})"
- iss検証失敗: "Invalid issuer (expected: {expected}, actual: {actual})"
- nonce検証失敗: "Invalid nonce (expected: {expected}, actual: {actual})"

### 4. 現在時刻の取得
MoonBitのtime APIを使用：
```moonbit
fn get_current_unix_time() -> Int64 {
  @time.now().unix_timestamp()
}
```

利用不可能な場合は、外部から渡す設計も検討。

## 実装順序

### Step 1: RS256署名検証の調査（1時間）
1. moonbitlang/x/cryptoの機能調査
2. RSA署名検証APIの確認
3. 実装可能性の判断
4. 代替案の検討（必要に応じて）

### Step 2: 署名検証実装（2時間）
1. `lib/oidc/verification.mbt`作成
2. Base64URLデコード実装（既存のものを流用）
3. RSA公開鍵構築
4. verify_rs256_signature()実装
5. ユニットテスト（5-8テスト）

### Step 3: IdToken検証メソッド実装（1.5時間）
1. `lib/oidc/id_token.mbt`に検証メソッド追加
2. verify_signature()実装
3. verify_claims()実装
4. verify()実装
5. ユニットテスト（10-15テスト）

### Step 4: Google専用ヘルパー実装（1時間）
1. `lib/providers/google/`ディレクトリ作成
2. `google_oauth2.mbt`作成
3. fetch_discovery()実装
4. verify_id_token()実装
5. ドキュメント作成（README.md）
6. ユニットテスト（5-8テスト）

### Step 5: 統合テスト（1.5時間）
1. `examples/google/verify_id_token.mbt`作成
2. 実際のGoogle ID Tokenでテスト
3. エラーケースのテスト
4. ドキュメント作成（README.md）

**合計推定工数: 7時間**

## テスト戦略

### ユニットテスト（25-30テスト）

1. **RS256署名検証テスト**
   ```moonbit
   test "verify_rs256_signature succeeds with valid signature"
   test "verify_rs256_signature fails with invalid signature"
   test "verify_rs256_signature fails with wrong public key"
   test "verify_rs256_signature handles Base64URL decode errors"
   ```

2. **クレーム検証テスト**
   ```moonbit
   test "verify_claims succeeds with valid claims"
   test "verify_claims fails with expired token"
   test "verify_claims fails with invalid audience"
   test "verify_claims fails with invalid issuer"
   test "verify_claims succeeds without nonce"
   test "verify_claims succeeds with matching nonce"
   test "verify_claims fails with mismatching nonce"
   test "verify_claims fails with missing nonce"
   ```

3. **統合検証テスト**
   ```moonbit
   test "verify succeeds with valid token and signature"
   test "verify fails with invalid signature"
   test "verify fails with expired token"
   test "verify fails with invalid audience"
   ```

4. **Googleヘルパーテスト**
   ```moonbit
   test "google_issuer returns correct URL"
   test "fetch_discovery calls correct endpoint"
   test "verify_id_token performs all checks"
   ```

### 統合テスト

1. **実際のGoogle ID Tokenでの検証**
   - Google OAuth2 Playgroundから取得したID Token
   - または開発用Googleプロジェクトで取得

2. **エラーケースのテスト**
   - 改ざんされたID Token
   - 期限切れのID Token
   - 間違ったaudienceのID Token

## 検証項目

実装完了時に以下を確認：

- [ ] RS256署名検証が実装されている
- [ ] IdToken検証メソッドが実装されている
- [ ] クレーム検証が正しく動作する
- [ ] Google専用ヘルパーが実装されている（専用ディレクトリ）
- [ ] 実際のGoogle ID Tokenで検証が成功する
- [ ] 全ユニットテストがパスする（Native/JS両方）
- [ ] 統合テストがパスする
- [ ] ドキュメントコメントが適切に記述されている
- [ ] 使用例が動作する
- [ ] `moon fmt`でフォーマットされている
- [ ] `moon info`で`.mbti`の変更を確認
- [ ] Google実装のREADME.mdが作成されている

## 成功基準

1. ✅ 実際のGoogle ID Tokenの署名を検証できる
2. ✅ すべてのクレーム検証が正しく動作する
3. ✅ すべてのユニットテストがパスする（25-30テスト）
4. ✅ Native/JS両ターゲットで動作する
5. ✅ エラーハンドリングが適切に実装されている
6. ✅ 既存のテストが全てパスする（破壊的変更なし）
7. ✅ Google専用ディレクトリが適切に構成されている
8. ✅ ドキュメントが完備されている

## リスク・懸念事項

### リスク1: RS256署名検証の実装難易度
- **影響度**: 高（最大のリスク）
- **懸念**: moonbitlang/x/cryptoでRSA署名検証が実装されていない可能性
- **対策**: Step 1で徹底的に調査
- **代替案1**: 外部ライブラリやFFIを使用
- **代替案2**: 署名検証をスキップし、他のクレーム検証のみ実施（セキュリティは低下）
- **代替案3**: ドキュメントで外部検証サービスの利用を推奨

### リスク2: 現在時刻の取得
- **影響度**: 中
- **懸念**: MoonBitのtime APIが不明
- **対策**: 調査を優先
- **代替案**: current_timeを外部から渡す設計に変更

### リスク3: Base64URLデコードのエッジケース
- **影響度**: 低
- **懸念**: パディング処理等のエッジケース
- **対策**: 既存のBase64URL実装を使用（lib/oidc/id_token.mbtで実績あり）

## 次のステップ

実装完了後：
1. 完了ドキュメント作成（`docs/completed/20260217_id_token_verification.md`）
2. Phase 4（Google統合サンプル）のsteeringドキュメント作成
3. コードレビュー
4. Git commit

## 参考資料

### RFC仕様
- [RFC 7519: JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7515: JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515)

### Google固有のドキュメント
- [Validating an ID token | OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect#validatinganidtoken)
- [Google Identity - Authenticate with a backend server](https://developers.google.com/identity/sign-in/web/backend-auth)

### 既存実装の参考
- `lib/oidc/id_token.mbt` - ID Token構造とパース
- `lib/oidc/jwks.mbt` - JWKS機能（Phase 2）
- `lib/oidc/discovery.mbt` - Discovery Document（Phase 1）

### MoonBit関連
- moonbitlang/x/crypto - 暗号機能ライブラリ
- moonbitlang/core/time - 時刻関連API（予定）
