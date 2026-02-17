# Steering: Google OAuth2統合サンプルとドキュメント（Phase 4）

## 目的・背景

Phase 1-3で実装したGoogle OAuth2/OIDC機能を実際に使用できるように、
包括的なサンプルコードとドキュメントを整備します。

これにより、ライブラリユーザーがGoogle OAuth2を簡単に統合でき、
ベストプラクティスに従った実装ができるようになります。

## ゴール

1. Google OAuth2の完全なAuthorization Code Flowサンプルを提供すること
2. ID Token検証のサンプルを提供すること
3. UserInfo取得のサンプルを提供すること
4. Google OAuth2統合ガイドドキュメントを作成すること
5. すべてのサンプルが実際に動作すること
6. README.mdにGoogle OAuth2の説明を追加すること

## 前提条件

- Phase 1（Discovery Document実装）が完了していること
- Phase 2（JWKS実装）が完了していること
- Phase 3（ID Token署名検証実装）が完了していること
- `lib/providers/google/`ディレクトリが作成されていること

## アプローチ

### 1. サンプルコードの構成

**Google OAuth2実装は専用ディレクトリに配置します**

```
examples/
└── google/                              # Google OAuth2サンプル
    ├── authorization_flow.mbt           # Authorization Code Flow
    ├── verify_id_token.mbt              # ID Token検証（Phase 3で作成済み）
    ├── userinfo.mbt                     # UserInfo取得
    ├── complete_flow.mbt                # 完全なフロー（統合例）
    ├── README.md                        # サンプルの説明
    └── .env.example                     # 環境変数のサンプル
```

### 2. Authorization Code Flowサンプル

```moonbit
// examples/google/authorization_flow.mbt

///|
/// Google OAuth2 Authorization Code Flow Example with PKCE
///
/// This example demonstrates how to implement Google Sign-In
/// using Authorization Code Flow with PKCE.

pub fn main {
  // Configuration (normally from environment variables)
  let client_id = "YOUR_CLIENT_ID.apps.googleusercontent.com"
  let client_secret = "YOUR_CLIENT_SECRET"
  let redirect_uri = "http://localhost:3000/callback"

  let http_client = @oauth2.OAuth2HttpClient::new()

  // Step 1: Fetch Google Discovery Document
  println("Fetching Google Discovery Document...")
  let discovery = @providers.google.fetch_discovery(http_client)
  match discovery {
    Err(e) => {
      println("Failed to fetch discovery: \{e.message()}")
      return
    }
    Ok(doc) => {
      println("✓ Discovery document fetched")

      // Step 2: Generate authorization URL
      let state = @oauth2.generate_csrf_token()
      let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
      let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)

      let scopes = [
        @oauth2.Scope::new("openid"),
        @oauth2.Scope::new("profile"),
        @oauth2.Scope::new("email"),
      ]

      let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(
        doc.authorization_url(),
        @oauth2.ClientId::new(client_id),
        @oauth2.RedirectUrl::new(redirect_uri),
        scopes,
        state,
        pkce_challenge,
      )

      let auth_url = auth_request.build_authorization_url()
      println("\\nAuthorization URL:")
      println("\{auth_url}")
      println("\\nPlease visit this URL in your browser and authorize the application.")
      println("After authorization, you will be redirected to the callback URL.")
      println("Copy the 'code' parameter from the callback URL.")

      // Step 3: Exchange authorization code for tokens
      println("\\nEnter the authorization code:")
      let code = read_line() // Placeholder: read from stdin

      let token_request = @oauth2.TokenRequest::new_with_pkce(
        doc.token_url(),
        @oauth2.ClientId::new(client_id),
        @oauth2.ClientSecret::new(client_secret),
        code,
        @oauth2.RedirectUrl::new(redirect_uri),
        pkce_verifier,
      )

      println("\\nExchanging authorization code for tokens...")
      let token_response = token_request.execute(http_client)
      match token_response {
        Ok(response) => {
          println("✓ Tokens received")
          println("Access Token: \{response.access_token().to_string()}")

          // Step 4: Parse and verify ID Token
          match @oidc.get_id_token_from_response(response) {
            Ok(id_token) => {
              println("\\n✓ ID Token parsed")

              // Verify ID Token
              match @providers.google.verify_id_token(
                id_token,
                client_id,
                http_client,
                None, // No nonce in this example
              ) {
                Ok(_) => {
                  println("✓ ID Token verified")
                  println("\\nUser Information from ID Token:")
                  println("  Subject (User ID): \{id_token.subject()}")
                  println("  Email: \{id_token.email().or("N/A")}")
                  println("  Name: \{id_token.name().or("N/A")}")
                }
                Err(e) => {
                  println("✗ ID Token verification failed: \{e.message()}")
                }
              }
            }
            Err(e) => {
              println("✗ Failed to parse ID Token: \{e.message()}")
            }
          }
        }
        Err(e) => {
          println("✗ Token exchange failed: \{e.message()}")
        }
      }
    }
  }
}

// Placeholder: read line from stdin
fn read_line() -> String {
  // Implementation depends on MoonBit's I/O API
  ""
}
```

### 3. UserInfo取得サンプル

```moonbit
// examples/google/userinfo.mbt

///|
/// Google UserInfo Endpoint Example
///
/// This example demonstrates how to retrieve user information
/// from Google's UserInfo endpoint using an access token.

pub fn main {
  let access_token = "YOUR_ACCESS_TOKEN"
  let http_client = @oauth2.OAuth2HttpClient::new()

  // Step 1: Fetch Discovery Document
  println("Fetching Google Discovery Document...")
  let discovery = @providers.google.fetch_discovery(http_client)
  match discovery {
    Err(e) => {
      println("Failed to fetch discovery: \{e.message()}")
      return
    }
    Ok(doc) => {
      println("✓ Discovery document fetched")

      // Step 2: Fetch UserInfo
      match doc.userinfo_url() {
        Some(userinfo_url) => {
          let userinfo_request = @oidc.UserInfoRequest::new(
            userinfo_url,
            @oauth2.AccessToken::new(access_token),
          )

          println("\\nFetching UserInfo...")
          let userinfo = userinfo_request.execute(http_client)
          match userinfo {
            Ok(info) => {
              println("✓ UserInfo retrieved")
              println("\\nUser Information:")
              println("  Subject: \{info.subject()}")
              println("  Name: \{info.name().or("N/A")}")
              println("  Email: \{info.email().or("N/A")}")
              println("  Email Verified: \{info.email_verified().or(false)}")
              println("  Picture: \{info.picture().or("N/A")}")
            }
            Err(e) => {
              println("✗ Failed to fetch UserInfo: \{e.message()}")
            }
          }
        }
        None => {
          println("✗ UserInfo endpoint not available")
        }
      }
    }
  }
}
```

### 4. 完全なフローサンプル（統合例）

```moonbit
// examples/google/complete_flow.mbt

///|
/// Complete Google OAuth2 Flow Example
///
/// This example demonstrates the complete flow:
/// 1. Authorization URL generation
/// 2. Token exchange
/// 3. ID Token verification
/// 4. UserInfo retrieval

pub fn main {
  // ... (authorization_flow.mbtとuserinfo.mbtを組み合わせた完全な実装)
}
```

### 5. Google OAuth2統合ガイド

```markdown
// examples/google/README.md

# Google OAuth2 Integration Guide

This guide explains how to integrate Google OAuth2/OIDC with your MoonBit application.

## Prerequisites

1. Create a Google Cloud Project
2. Enable Google+ API
3. Create OAuth 2.0 credentials (OAuth Client ID)
4. Add authorized redirect URIs

See [Google Cloud Console](https://console.cloud.google.com/)

## Quick Start

### 1. Install the library

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "ryota0624/oauth2": "*"
  }
}
```

### 2. Authorization Code Flow with PKCE

```moonbit
// See examples/google/authorization_flow.mbt for complete example

let http_client = @oauth2.OAuth2HttpClient::new()
let discovery = @providers.google.fetch_discovery(http_client)

// Generate authorization URL
let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(...)
let auth_url = auth_request.build_authorization_url()

// Exchange code for tokens
let token_request = @oauth2.TokenRequest::new_with_pkce(...)
let token_response = token_request.execute(http_client)

// Verify ID Token
let id_token = @oidc.get_id_token_from_response(token_response)?
@providers.google.verify_id_token(id_token, client_id, http_client, None)?
```

### 3. Verify ID Token

```moonbit
// See examples/google/verify_id_token.mbt for complete example

let id_token = @oidc.IdToken::parse(id_token_string)?
@providers.google.verify_id_token(id_token, client_id, http_client, None)?
```

### 4. Get User Information

```moonbit
// See examples/google/userinfo.mbt for complete example

let userinfo_request = @oidc.UserInfoRequest::new(userinfo_url, access_token)
let userinfo = userinfo_request.execute(http_client)?
```

## Configuration

### Environment Variables

Create a `.env` file (see `.env.example`):

```
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3000/callback
```

## Security Best Practices

1. **Always use PKCE** for Authorization Code Flow
2. **Always verify ID Tokens** - signature, exp, aud, iss
3. **Use HTTPS** in production (redirect URIs)
4. **Keep client_secret secure** - never expose in client-side code
5. **Validate state parameter** - CSRF protection
6. **Check nonce** if using it (replay attack protection)

## Scopes

Common Google OAuth2 scopes:

- `openid` - Required for OIDC
- `profile` - Access to user's basic profile info
- `email` - Access to user's email address

See [Google OAuth2 Scopes](https://developers.google.com/identity/protocols/oauth2/scopes)

## Troubleshooting

### "Invalid client" error
- Check client_id and client_secret
- Verify OAuth credentials in Google Cloud Console

### "Redirect URI mismatch" error
- Ensure redirect_uri matches exactly (including http/https, port, path)
- Add the URI to authorized redirect URIs in Google Cloud Console

### "Invalid token" error
- Token may be expired
- Verify token with correct client_id
- Check if token is from the correct issuer

## API Reference

See `lib/providers/google/README.md` for detailed API documentation.

## Examples

- `authorization_flow.mbt` - Authorization Code Flow with PKCE
- `verify_id_token.mbt` - ID Token verification
- `userinfo.mbt` - UserInfo retrieval
- `complete_flow.mbt` - Complete flow integration

## Resources

- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google Discovery Document](https://accounts.google.com/.well-known/openid-configuration)
```

### 6. lib/providers/google/README.md（API Reference）

```markdown
// lib/providers/google/README.md

# Google OAuth2 Provider

This module provides convenience functions for Google OAuth2/OIDC integration.

## Overview

The Google provider wraps the core OAuth2 and OIDC functionality with Google-specific defaults,
making it easier to integrate Google Sign-In into your application.

## API Reference

### google_issuer

```moonbit
pub fn google_issuer() -> String
```

Returns Google's issuer URL: `"https://accounts.google.com"`

### fetch_discovery

```moonbit
pub async fn fetch_discovery(
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[@oidc.DiscoveryDocument, @oauth2.OAuth2Error]
```

Fetches Google's OpenID Connect Discovery Document from:
`https://accounts.google.com/.well-known/openid-configuration`

**Returns:**
- `Ok(DiscoveryDocument)` - Successfully fetched discovery document
- `Err(OAuth2Error)` - Failed to fetch or parse discovery document

### verify_id_token

```moonbit
pub async fn verify_id_token(
  id_token : @oidc.IdToken,
  client_id : String,
  http_client : @oauth2.OAuth2HttpClient,
  nonce : String?,
) -> Result[Unit, @oauth2.OAuth2Error]
```

Verifies a Google ID Token comprehensively:

1. **Signature verification** - using Google's public keys (JWKS)
2. **Expiration check** - token must not be expired
3. **Audience check** - `aud` must match `client_id`
4. **Issuer check** - `iss` must be `https://accounts.google.com`
5. **Nonce check** - if provided, must match token's nonce

**Parameters:**
- `id_token` - Parsed ID Token to verify
- `client_id` - Your Google OAuth2 client ID
- `http_client` - HTTP client for fetching JWKS
- `nonce` - Optional nonce for replay attack protection

**Returns:**
- `Ok(())` - Token is valid
- `Err(OAuth2Error)` - Token is invalid (see error message for details)

**Example:**

```moonbit
let id_token = @oidc.IdToken::parse(token_string)?
let client_id = "your-client-id.apps.googleusercontent.com"

match @providers.google.verify_id_token(id_token, client_id, http_client, None) {
  Ok(_) => println("Token is valid!")
  Err(e) => println("Token verification failed: \{e.message()}")
}
```

## Usage

See `examples/google/` for complete usage examples.
```

### 7. README.md（プロジェクトルート）への追加

既存の`README.mbt.md`にGoogle OAuth2セクションを追加：

```markdown
## Google OAuth2 Integration

### Quick Example

```moonbit
// Fetch Google Discovery Document
let http_client = @oauth2.OAuth2HttpClient::new()
let discovery = @providers.google.fetch_discovery(http_client)?

// Generate authorization URL with PKCE
let state = @oauth2.generate_csrf_token()
let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)

let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(
  discovery.authorization_url(),
  @oauth2.ClientId::new("your-client-id.apps.googleusercontent.com"),
  @oauth2.RedirectUrl::new("http://localhost:3000/callback"),
  [@oauth2.Scope::new("openid"), @oauth2.Scope::new("email")],
  state,
  pkce_challenge,
)

let auth_url = auth_request.build_authorization_url()
// Redirect user to auth_url

// After callback, exchange code for tokens
let token_request = @oauth2.TokenRequest::new_with_pkce(
  discovery.token_url(),
  @oauth2.ClientId::new("your-client-id.apps.googleusercontent.com"),
  @oauth2.ClientSecret::new("your-client-secret"),
  authorization_code,
  @oauth2.RedirectUrl::new("http://localhost:3000/callback"),
  pkce_verifier,
)

let response = token_request.execute(http_client)?

// Verify ID Token
let id_token = @oidc.get_id_token_from_response(response)?
@providers.google.verify_id_token(id_token, "your-client-id.apps.googleusercontent.com", http_client, None)?

println("User ID: \{id_token.subject()}")
println("Email: \{id_token.email().or("N/A")}")
```

See [Google OAuth2 Integration Guide](examples/google/README.md) for detailed instructions.
```

## スコープ

### 含むもの
- Authorization Code Flowサンプル（PKCE付き）
- ID Token検証サンプル（Phase 3で作成済み）
- UserInfo取得サンプル
- 完全なフローサンプル（統合例）
- Google OAuth2統合ガイド（examples/google/README.md）
- Google Provider APIリファレンス（lib/providers/google/README.md）
- README.mdへのGoogle OAuth2セクション追加
- .env.exampleファイル（環境変数サンプル）
- すべてのサンプルの動作確認

### 含まないもの
- Webサーバーの実装
  - 理由: ライブラリのスコープ外、ユーザーが実装
- フロントエンド実装
  - 理由: バックエンドライブラリとして提供
- プロダクション対応のエラーハンドリング
  - 理由: サンプルコードのため、シンプルに保つ

## 影響範囲

### 新規ファイル
- `examples/google/authorization_flow.mbt` - Authorization Code Flowサンプル
- `examples/google/userinfo.mbt` - UserInfo取得サンプル
- `examples/google/complete_flow.mbt` - 完全なフローサンプル
- `examples/google/README.md` - Google OAuth2統合ガイド
- `examples/google/.env.example` - 環境変数サンプル
- `lib/providers/google/README.md` - Google Provider APIリファレンス

### 変更ファイル
- `README.mbt.md` - Google OAuth2セクションの追加
  - Quick Example追加
  - ドキュメントリンク追加

### 最終的なディレクトリ構造
```
moonbit_oauth2/
├── lib/
│   ├── oauth2/               # コアOAuth2機能
│   ├── oidc/                 # OIDC機能
│   │   ├── discovery.mbt     # Phase 1
│   │   ├── jwks.mbt          # Phase 2
│   │   ├── verification.mbt  # Phase 3
│   │   ├── id_token.mbt
│   │   └── ...
│   └── providers/
│       └── google/           # Google専用（Phase 3-4）
│           ├── google_oauth2.mbt
│           ├── google_oauth2_wbtest.mbt
│           └── README.md     # API Reference
├── examples/
│   └── google/               # Google使用例（Phase 4）
│       ├── authorization_flow.mbt
│       ├── verify_id_token.mbt
│       ├── userinfo.mbt
│       ├── complete_flow.mbt
│       ├── README.md         # 統合ガイド
│       └── .env.example
├── docs/
│   ├── steering/
│   │   ├── 20260217_google_oauth2_support.md
│   │   ├── 20260217_discovery_document_implementation.md
│   │   ├── 20260217_jwks_implementation.md
│   │   ├── 20260217_id_token_verification.md
│   │   └── 20260217_google_integration_samples.md
│   └── completed/
│       └── (完了ドキュメント)
└── README.mbt.md            # プロジェクトREADME
```

## 技術的決定事項

### 1. サンプルコードのスタイル
- 実際に動作するコード（コピー&ペーストで使える）
- 詳細なコメント（各ステップの説明）
- エラーハンドリングの例
- 標準出力でステータス表示

### 2. 環境変数の扱い
- .env.exampleファイルで推奨設定を示す
- コード内ではプレースホルダー（"YOUR_CLIENT_ID"等）
- 実装はユーザーの責任（MoonBitの環境変数APIに依存）

### 3. ドキュメントの構成
- examples/google/README.md - 統合ガイド（ユーザー向け）
- lib/providers/google/README.md - API Reference（開発者向け）
- README.mbt.md - Quick Start（プロジェクト全体）

## 実装順序

### Step 1: Authorization Flow サンプル（1.5時間）
1. `examples/google/authorization_flow.mbt`作成
2. Discovery Document取得
3. Authorization URL生成
4. Token交換
5. ID Token検証
6. 動作確認

### Step 2: UserInfo サンプル（45分）
1. `examples/google/userinfo.mbt`作成
2. Discovery Document取得
3. UserInfo取得
4. 動作確認

### Step 3: Complete Flow サンプル（1時間）
1. `examples/google/complete_flow.mbt`作成
2. 全フローの統合
3. エラーハンドリング
4. 動作確認

### Step 4: ドキュメント作成（2時間）
1. `examples/google/README.md`作成
   - Quick Start
   - Configuration
   - Security Best Practices
   - Troubleshooting
2. `lib/providers/google/README.md`作成
   - API Reference
   - 使用例
3. `.env.example`作成
4. README.mbt.mdにGoogle OAuth2セクション追加

### Step 5: 動作確認とテスト（1時間）
1. すべてのサンプルコードをテスト
2. ドキュメントのリンク確認
3. コードフォーマット
4. 最終レビュー

**合計推定工数: 6.25時間**

## 検証項目

実装完了時に以下を確認：

- [ ] Authorization Flow サンプルが動作する
- [ ] UserInfo サンプルが動作する
- [ ] Complete Flow サンプルが動作する
- [ ] すべてのサンプルがフォーマットされている
- [ ] examples/google/README.mdが完成している
- [ ] lib/providers/google/README.mdが完成している
- [ ] .env.exampleが作成されている
- [ ] README.mbt.mdにGoogle OAuth2セクションが追加されている
- [ ] すべてのドキュメントリンクが有効である
- [ ] コードがベストプラクティスに従っている
- [ ] エラーハンドリングが適切である

## 成功基準

1. ✅ すべてのサンプルコードが動作する
2. ✅ ドキュメントが完備されている
3. ✅ Quick Startで簡単に始められる
4. ✅ セキュリティベストプラクティスが記載されている
5. ✅ トラブルシューティングガイドが提供されている
6. ✅ API Referenceが完備されている
7. ✅ 実際のGoogle OAuth2で動作確認済み

## リスク・懸念事項

### リスク1: MoonBitの標準入力/出力API
- **影響度**: 低
- **懸念**: サンプルコードで標準入力を使用する場合、APIが不明
- **対策**: プレースホルダー関数で対応
- **代替案**: コメントでユーザーに実装を任せる

### リスク2: 環境変数の読み込み
- **影響度**: 低
- **懸念**: MoonBitの環境変数APIが不明
- **対策**: ハードコードのプレースホルダーで対応
- **影響**: ドキュメントで説明

### リスク3: Google OAuth2の設定手順
- **影響度**: 低
- **懸念**: Google Cloud Consoleの手順が複雑
- **対策**: 詳細なステップバイステップガイドを提供
- **影響**: ユーザーエクスペリエンス向上

## 次のステップ

実装完了後：
1. 完了ドキュメント作成（`docs/completed/20260217_google_oauth2_complete.md`）
2. 全体のコードレビュー
3. Git commit
4. バージョンタグ（v0.2.0等）
5. リリースノート作成

## 参考資料

### Google公式ドキュメント
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [OpenID Connect | Sign in with Google](https://developers.google.com/identity/openid-connect/openid-connect)

### サンプルコード参考
- 他のOAuth2ライブラリのサンプル
- Keycloak統合テスト（既存）

### 既存実装
- `lib/providers/google/google_oauth2.mbt` - Google Provider（Phase 3）
- `lib/keycloak_test/` - 既存の統合テスト参考
