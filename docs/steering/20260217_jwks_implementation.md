# Steering: JWKS (JSON Web Key Set) 実装（Phase 2）

## 目的・背景

JWKS (JSON Web Key Set) は、OAuth2/OIDCプロバイダーが公開鍵を配布するための標準形式です（RFC 7517）。
ID Tokenの署名検証には、プロバイダーの公開鍵が必要であり、JWKSからこれを取得します。

Google OAuth2では、ID Tokenの署名検証が推奨されており（セキュリティベストプラクティス）、
そのためにはGoogleの公開鍵をJWKSエンドポイント（https://www.googleapis.com/oauth2/v3/certs）から取得する必要があります。

## ゴール

1. JWKSエンドポイントからJSON Web Key Setを取得できること
2. 取得したJWKSから個々のJWK（JSON Web Key）を抽出できること
3. kid（Key ID）を使って適切な公開鍵を選択できること
4. RSA公開鍵のパラメータ（n、e）を抽出できること
5. Googleの実際のJWKSで動作確認できること
6. ユニットテストと統合テストがパスすること

## 前提条件

- Phase 1（Discovery Document実装）が完了していること
- HTTPクライアントのGETメソッドが利用可能であること

## アプローチ

### 1. JsonWebKey構造体の設計

```moonbit
pub struct JsonWebKey {
  // Standard JWK fields (RFC 7517)
  kty : String        // Key Type (例: "RSA")
  use_ : String?      // Public Key Use (例: "sig" for signature)
  kid : String        // Key ID (例: "abc123")
  alg : String?       // Algorithm (例: "RS256")

  // RSA-specific fields (RFC 7518, Section 6.3)
  n : String?         // RSA Modulus (Base64URL encoded)
  e : String?         // RSA Exponent (Base64URL encoded)

  // EC-specific fields (将来の拡張用、今回は未実装)
  // crv : String?    // Curve (例: "P-256")
  // x : String?      // X coordinate
  // y : String?      // Y coordinate
} derive(Show, Eq)
```

**設計判断:**
- kty、kid: 必須フィールド（JWK仕様）
- use_、alg: オプションフィールド（プロバイダーによっては省略される）
- n、e: RSA鍵の必須パラメータ（kty="RSA"の場合）
- EC鍵: 今回は未サポート（将来的に追加可能）

### 2. JsonWebKeySet構造体の設計

```moonbit
pub struct JsonWebKeySet {
  keys : Array[JsonWebKey]  // JWKの配列
} derive(Show, Eq)
```

**設計判断:**
- シンプルな構造（JWKの配列を保持）
- 検索機能はヘルパーメソッドで提供

### 3. JWKS取得関数

```moonbit
pub async fn fetch_jwks(
  jwks_uri : String,
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[JsonWebKeySet, @oauth2.OAuth2Error]
```

**実装手順:**
1. jwks_uriにHTTP GETリクエストを送信
2. JSONレスポンスをパース
3. JsonWebKeySet構造体に変換
4. 各JWKの基本的な検証

**エラーハンドリング:**
- HTTP通信エラー → OAuth2Error::new_other("Failed to fetch JWKS: ...")
- JSONパースエラー → OAuth2Error::new_other("Failed to parse JWKS: ...")
- 不正なJWK → OAuth2Error::new_other("Invalid JWK in JWKS: ...")

### 4. JWKS検索機能

```moonbit
pub fn JsonWebKeySet::find_by_kid(
  self : JsonWebKeySet,
  kid : String,
) -> JsonWebKey? {
  // kidが一致するJWKを検索
}

pub fn JsonWebKeySet::find_rsa_key_by_kid(
  self : JsonWebKeySet,
  kid : String,
) -> JsonWebKey? {
  // kidが一致し、kty="RSA"のJWKを検索
}

pub fn JsonWebKeySet::get_all_keys(
  self : JsonWebKeySet,
) -> Array[JsonWebKey] {
  self.keys
}
```

**設計判断:**
- find_by_kid: 基本的な検索機能
- find_rsa_key_by_kid: RSA鍵に特化した検索（今回の主要ユースケース）
- get_all_keys: すべてのキーを取得（デバッグ用）

### 5. RSA公開鍵パラメータ抽出

```moonbit
pub fn JsonWebKey::rsa_modulus(self : JsonWebKey) -> String? {
  self.n
}

pub fn JsonWebKey::rsa_exponent(self : JsonWebKey) -> String? {
  self.e
}

pub fn JsonWebKey::is_rsa(self : JsonWebKey) -> Bool {
  self.kty == "RSA"
}
```

### 6. Discovery DocumentとJWKSの統合

Discovery Documentから取得したjwks_uriを使ってJWKSを取得：

```moonbit
// 使用例
let discovery = fetch_google_discovery(http_client)?
let jwks = fetch_jwks(discovery.jwks_uri, http_client)?
```

## スコープ

### 含むもの
- JsonWebKey構造体と関連メソッド
- JsonWebKeySet構造体と検索機能
- fetch_jwks()関数の実装
- JSONパース・検証ロジック
- RSA鍵の検証（kty="RSA"の場合）
- ユニットテスト（20-25テスト）
- 統合テスト（GoogleのJWKSを使用）
- ドキュメントコメント

### 含まないもの
- JWKSのキャッシング機構
  - 理由: 別途実装（Phase 3.5として）
- EC鍵（楕円曲線暗号）のサポート
  - 理由: GoogleはRSA鍵を使用、EC鍵は将来の拡張
- 対称鍵（oct）のサポート
  - 理由: 公開鍵暗号方式のみサポート
- JWK Thumbprint（RFC 7638）
  - 理由: 今回のユースケースでは不要

## 影響範囲

### 新規ファイル
- `lib/oidc/jwks.mbt` - JWKS実装
  - JsonWebKey構造体
  - JsonWebKeySet構造体
  - fetch_jwks()関数
  - JSONパース関数
  - 検索・検証関数

- `lib/oidc/jwks_wbtest.mbt` - ユニットテスト
  - JWKパーステスト（正常系・異常系）
  - JWKSetパーステスト
  - 検索機能テスト
  - RSA鍵検証テスト

### 変更ファイル
なし（既存ファイルへの変更は不要）

### ディレクトリ構造
```
lib/
├── oidc/
│   ├── discovery.mbt           # Phase 1
│   ├── discovery_wbtest.mbt    # Phase 1
│   ├── jwks.mbt                # 新規（Phase 2）
│   ├── jwks_wbtest.mbt         # 新規（Phase 2）
│   ├── id_token.mbt            # 既存
│   ├── token_response.mbt      # 既存
│   └── userinfo.mbt            # 既存
```

## 技術的決定事項

### 1. JWKの必須フィールド
RFC 7517に従い、以下を必須とする：
- kty（Key Type）: 必須
- kid（Key ID）: 実質的に必須（Google JWKSでは常に含まれる）

RSA鍵の場合、さらに以下が必須：
- n（Modulus）: 必須
- e（Exponent）: 必須

### 2. Base64URL形式のパラメータ
- n、eはBase64URL形式で保存
- Phase 3（署名検証）で使用時にデコード
- 今回はデコード機能は実装しない（Phase 3で実装）

### 3. エラーハンドリング
- JWK配列が空 → 警告ログを出すが、エラーにはしない
- 不正なJWK → スキップして次のJWKを処理
- 全JWKが不正 → エラーを返す

### 4. HTTPヘッダー
```moonbit
let headers : HttpHeaders = {}
headers["Accept"] = "application/json"
headers["User-Agent"] = "moonbit-oauth2/0.1.2"
```

## 実装順序

### Step 1: JsonWebKey構造体（30分）
1. `lib/oidc/jwks.mbt`ファイル作成
2. JsonWebKey構造体定義
3. ゲッターメソッド実装
4. is_rsa()等のヘルパーメソッド

### Step 2: JsonWebKeySet構造体（20分）
1. JsonWebKeySet構造体定義
2. get_all_keys()実装
3. 基本的な検索機能

### Step 3: JSONパース実装（1時間）
1. parse_jwk()関数実装
   - kty、kid、alg、use_の抽出
   - n、eの抽出（RSA鍵の場合）
2. parse_jwks()関数実装
   - keys配列の抽出
   - 各JWKのパース
3. エラーハンドリング
4. ユニットテスト（15-20テスト）

### Step 4: JWKS取得関数（30分）
1. fetch_jwks()関数実装
2. HTTP GET実行
3. パース処理
4. エラーハンドリング

### Step 5: 検索機能実装（30分）
1. find_by_kid()実装
2. find_rsa_key_by_kid()実装
3. テスト（5テスト）

### Step 6: 統合テスト（30分）
1. GoogleのJWKSを取得
2. パース成功の確認
3. RSA鍵の検索テスト
4. Discovery DocumentとJWKSの連携テスト

**合計推定工数: 3.5時間**

## テスト戦略

### ユニットテスト（20-25テスト）

1. **JWKパーステスト（正常系）**
   ```moonbit
   test "parse valid RSA JWK with all fields"
   test "parse valid RSA JWK with required fields only"
   test "parse valid JWK with optional use and alg"
   ```

2. **JWKパーステスト（異常系）**
   ```moonbit
   test "parse fails with missing kty"
   test "parse fails with missing kid"
   test "parse RSA JWK fails with missing n"
   test "parse RSA JWK fails with missing e"
   test "parse fails with invalid JSON"
   ```

3. **JWKSetパーステスト**
   ```moonbit
   test "parse valid JWKSet with multiple keys"
   test "parse valid JWKSet with single key"
   test "parse empty JWKSet (no keys)"
   test "parse fails with missing keys array"
   test "parse skips invalid JWKs in array"
   ```

4. **検索機能テスト**
   ```moonbit
   test "find_by_kid returns correct key"
   test "find_by_kid returns None for non-existent kid"
   test "find_rsa_key_by_kid returns RSA key"
   test "find_rsa_key_by_kid returns None for non-RSA key"
   test "get_all_keys returns all keys"
   ```

5. **RSA鍵検証テスト**
   ```moonbit
   test "is_rsa returns true for RSA key"
   test "is_rsa returns false for non-RSA key"
   test "rsa_modulus returns correct value"
   test "rsa_exponent returns correct value"
   ```

### 統合テスト

1. **GoogleのJWKS取得**
   ```moonbit
   // examples/google_jwks/main.mbt
   pub fn main {
     let http_client = @oauth2.OAuth2HttpClient::new()

     // Fetch discovery document
     let discovery = @oidc.fetch_google_discovery(http_client)
     match discovery {
       Err(e) => {
         println("Failed to fetch discovery: \{e.message()}")
         return
       }
       Ok(doc) => {
         println("JWKS URI: \{doc.jwks_uri}")

         // Fetch JWKS
         let jwks = @oidc.fetch_jwks(doc.jwks_uri, http_client)
         match jwks {
           Ok(keyset) => {
             let keys = keyset.get_all_keys()
             println("Found \{keys.length()} keys")

             for i = 0; i < keys.length(); i = i + 1 {
               let key = keys[i]
               println("Key \{i}: kid=\{key.kid}, kty=\{key.kty}")
             }
           }
           Err(e) => {
             println("Failed to fetch JWKS: \{e.message()}")
           }
         }
       }
     }
   }
   ```

2. **テストスクリプト**
   ```bash
   # scripts/test_jwks.sh
   #!/bin/bash
   set -e

   echo "Testing JWKS implementation..."

   # Run unit tests
   moon test --target native
   moon test --target js

   # Run integration test
   echo "Fetching Google JWKS..."
   moon run examples/google_jwks --target native

   echo "All tests passed!"
   ```

## 検証項目

実装完了時に以下を確認：

- [ ] JsonWebKey構造体が適切に定義されている
- [ ] JsonWebKeySet構造体が適切に定義されている
- [ ] JWKのJSONパースが正しく動作する（正常系・異常系）
- [ ] JWKSetのJSONパースが正しく動作する
- [ ] 検索機能が正しく動作する（find_by_kid等）
- [ ] RSA鍵の検証が正しく動作する
- [ ] GoogleのJWKSが取得できる
- [ ] Discovery DocumentとJWKSが連携できる
- [ ] 全ユニットテストがパスする（Native/JS両方）
- [ ] 統合テストがパスする
- [ ] ドキュメントコメントが適切に記述されている
- [ ] `moon fmt`でフォーマットされている
- [ ] `moon info`で`.mbti`の変更を確認

## 成功基準

1. ✅ GoogleのJWKSを取得し、パースできる
2. ✅ すべてのユニットテストがパスする（20-25テスト）
3. ✅ Native/JS両ターゲットで動作する
4. ✅ エラーハンドリングが適切に実装されている
5. ✅ 既存のテストが全てパスする（破壊的変更なし）
6. ✅ ドキュメントコメントが完備されている
7. ✅ Discovery Documentと連携できる

## サンプルJWKS（Google）

Googleの実際のJWKSの例（参考）：

```json
{
  "keys": [
    {
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "kid": "abc123",
      "n": "0vx7agoebG...（長いBase64URL文字列）",
      "e": "AQAB"
    },
    {
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "kid": "def456",
      "n": "xjlCRBqw4Q...（長いBase64URL文字列）",
      "e": "AQAB"
    }
  ]
}
```

## リスク・懸念事項

### リスク1: Base64URLパラメータの扱い
- **影響度**: 低
- **懸念**: n、eが非常に長い文字列（2048-bit RSA鍵の場合、約350文字）
- **対策**: String型で十分対応可能
- **影響**: なし

### リスク2: Google JWKSのローテーション
- **影響度**: 低
- **懸念**: Googleは定期的に鍵をローテーションする
- **対策**: 動的に取得するため問題なし
- **影響**: Phase 3.5（キャッシング）で考慮が必要

### リスク3: JWKSエンドポイントの可用性
- **影響度**: 極低
- **懸念**: Googleのエンドポイントがダウンする可能性
- **対策**: エラーハンドリングで対応、リトライは将来実装
- **影響**: ほぼなし（Googleのインフラは高可用性）

## 次のステップ

実装完了後：
1. 完了ドキュメント作成（`docs/completed/20260217_jwks_implementation.md`）
2. Phase 3（ID Token署名検証）のsteeringドキュメント作成
3. コードレビュー
4. Git commit

## 参考資料

### RFC仕様
- [RFC 7517: JSON Web Key (JWK)](https://datatracker.ietf.org/doc/html/rfc7517)
- [RFC 7518: JSON Web Algorithms (JWA)](https://datatracker.ietf.org/doc/html/rfc7518)

### Google固有のドキュメント
- [Google JWKS Endpoint](https://www.googleapis.com/oauth2/v3/certs)
- [OpenID Connect | Sign in with Google - Validating an ID token](https://developers.google.com/identity/openid-connect/openid-connect#validatinganidtoken)

### 既存実装の参考
- `lib/oidc/discovery.mbt` - JSONパースパターン（Phase 1）
- `lib/oidc/id_token.mbt` - JWTヘッダーパースの参考
- `lib/http_client.mbt` - HTTP GET実装
