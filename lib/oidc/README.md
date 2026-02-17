# OIDC Package

OpenID Connect (OIDC) implementation for MoonBit.

## Features

✅ **Implemented:**
- Discovery Document fetching and parsing (RFC 8414)
- JWKS (JSON Web Key Set) fetching and parsing (RFC 7517)
- ID Token parsing (JWT format, RFC 7519)
- ID Token claims verification (exp, aud, iss, nonce)
- UserInfo endpoint support

⚠️ **Limitations:**
- **Signature verification not implemented**: RS256 signature verification requires RSA cryptographic operations not currently available in moonbitlang/x/crypto
  - **For production use**: You MUST verify ID Token signatures externally before trusting the token
  - See "Signature Verification Workarounds" section below

## Signature Verification Workarounds

Since RS256 signature verification is not yet implemented, you must verify signatures externally:

### Option 1: Server-side verification
Verify tokens on your backend server (Node.js, Python, Go, etc.) before passing them to MoonBit code.

### Option 2: Use Google's tokeninfo endpoint
```moonbit
// Verify token using Google's tokeninfo endpoint
let response = http_client.get(
  "https://oauth2.googleapis.com/tokeninfo?id_token=\{id_token_string}",
  headers
)?
// If successful (200 OK), the token is valid
```

### Option 3: Client library with signature support
Use a full OAuth2 client library in your runtime environment (JavaScript, etc.) that supports signature verification.

### When signature verification will be added
This library will implement RS256 verification once RSA signature operations become available in moonbitlang/x/crypto or through FFI.

## Error Handling Policy

**基本方針: OIDCパッケージは`OAuth2Error`を便利なエラーとして使用しません。**

OIDCパッケージの各モジュールは、それぞれ専用のエラー型を定義し、型安全なエラーハンドリングを実現します。

### 専用エラー型

- **`DiscoveryError`** - Discovery Document のパース・検証エラー
  - `InvalidJson` - JSON パース失敗
  - `InvalidStructure` - 構造検証失敗
  - `InvalidFieldType` - フィールド型不一致
  - `MissingRequiredField` - 必須フィールド欠損

- **`JWKError`** - JWKS のパース・検証エラー
  - `InvalidJson` - JSON パース失敗
  - `InvalidStructure` - 構造検証失敗
  - `InvalidFieldType` - フィールド型不一致
  - `MissingRequiredField` - 必須フィールド欠損
  - `NoValidKeys` - 有効なJWKが存在しない

- **`IdTokenError`** - ID Token のパース・検証エラー
  - `InvalidFormat` - JWT形式不正
  - `Base64DecodeError` - Base64URLデコード失敗
  - `InvalidJson` - JSON パース失敗
  - `InvalidStructure` - 構造検証失敗
  - `InvalidFieldType` - フィールド型不一致
  - `MissingRequiredField` - 必須フィールド欠損

### エラー変換

公開APIでは、必要に応じて専用エラー型を `OAuth2Error` に変換します。これにより：

1. **型安全性**: 内部実装では型レベルでエラーを区別
2. **互換性**: 外部APIは `OAuth2Error` で統一されたインターフェース
3. **詳細情報**: エラーメッセージに詳細な情報を含む

例：
```moonbit
// 内部実装
fn parse_jwks(json_str : String) -> Result[JsonWebKeySet, JWKError] { ... }

// 公開API
pub async fn fetch_jwks(
  jwks_uri : String,
  http_client : OAuth2HttpClient,
) -> Result[JsonWebKeySet, OAuth2Error] {
  // JWKError を OAuth2Error に変換
  parse_jwks(response.body).map_err(fn(jwk_err) {
    OAuth2Error::new_other("JWKS parsing failed: \{jwk_err.message()}")
  })
}
```

### エラー変換パターン

`Result`型の`map_err`メソッドを使用して、エラーのみを変換します：

```moonbit
// 推奨パターン
parse_something(data).map_err(fn(err) {
  OAuth2Error::new_other("Context: \{err.message()}")
})

// 非推奨パターン (冗長)
match parse_something(data) {
  Ok(result) => Ok(result)
  Err(err) => Err(OAuth2Error::new_other("Context: \{err.message()}"))
}
```

### 設計原則

1. **責任の分離**: 各モジュールは自身のエラー型を管理
2. **型安全性**: エラーの種類を型レベルで表現
3. **明確なメッセージ**: エラーの原因と文脈を明示
4. **段階的変換**: 内部→専用エラー型、外部API→OAuth2Error

この方針により、エラーハンドリングが明確で保守性の高いコードベースを実現します。
