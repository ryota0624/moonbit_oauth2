# Google OAuth2 Provider

This module provides convenience functions for Google OAuth2/OIDC integration.

## Overview

The Google provider wraps the core OAuth2 and OIDC functionality with Google-specific defaults,
making it easier to integrate Google Sign-In into your application.

## API Reference

### `google_issuer`

```moonbit
pub fn google_issuer() -> String
```

Returns Google's issuer URL: `"https://accounts.google.com"`

**Example:**
```moonbit
let issuer = @providers.google.google_issuer()
// Returns: "https://accounts.google.com"
```

---

### `fetch_discovery`

```moonbit
pub async fn fetch_discovery(
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[@oidc.DiscoveryDocument, @oauth2.OAuth2Error]
```

Fetches Google's OpenID Connect Discovery Document from:
`https://accounts.google.com/.well-known/openid-configuration`

**Parameters:**
- `http_client` - HTTP client for making requests

**Returns:**
- `Ok(DiscoveryDocument)` - Successfully fetched discovery document
- `Err(OAuth2Error)` - Failed to fetch or parse discovery document

**Example:**
```moonbit
let http_client = @oauth2.OAuth2HttpClient::new()

match @providers.google.fetch_discovery(http_client) {
  Ok(discovery) => {
    println("Authorization endpoint: \{discovery.authorization_endpoint()}")
    println("Token endpoint: \{discovery.token_endpoint()}")
    println("JWKS URI: \{discovery.jwks_uri()}")
  }
  Err(e) => println("Error: \{e.message()}")
}
```

---

### `verify_id_token`

```moonbit
pub async fn verify_id_token(
  id_token : @oidc.IdToken,
  client_id : String,
  http_client : @oauth2.OAuth2HttpClient,
  nonce : String?,
) -> Result[Unit, @oauth2.OAuth2Error]
```

Verifies a Google ID Token comprehensively:

1. **Claims verification**:
   - **Expiration check** (`exp`) - token must not be expired
   - **Audience check** (`aud`) - must match `client_id`
   - **Issuer check** (`iss`) - must be `https://accounts.google.com`
   - **Nonce check** - if provided, must match token's nonce

⚠️ **Important**: Signature verification is not yet implemented due to crypto library limitations.
For production use, you MUST verify signatures externally. See [Signature Verification Workarounds](#signature-verification-workarounds).

**Parameters:**
- `id_token` - Parsed ID Token to verify
- `client_id` - Your Google OAuth2 client ID
- `http_client` - HTTP client for fetching JWKS
- `nonce` - Optional nonce for replay attack protection

**Returns:**
- `Ok(())` - Token claims are valid
- `Err(OAuth2Error)` - Token is invalid (see error message for details)

**Example:**
```moonbit
let id_token_string = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
let client_id = "your-client-id.apps.googleusercontent.com"
let http_client = @oauth2.OAuth2HttpClient::new()

// Parse ID Token
let id_token = match @oidc.IdToken::parse(id_token_string) {
  Ok(token) => token
  Err(e) => {
    println("Failed to parse ID Token: \{e.message()}")
    return
  }
}

// Verify ID Token
match @providers.google.verify_id_token(id_token, client_id, http_client, None) {
  Ok(_) => {
    println("✓ Token is valid!")
    println("User ID: \{id_token.subject()}")
    println("Email: \{id_token.email().or(\"N/A\")}")
    println("Name: \{id_token.name().or(\"N/A\")}")
  }
  Err(e) => {
    println("✗ Token verification failed: \{e.message()}")
  }
}
```

---

## Signature Verification Workarounds

Since RS256 signature verification is not yet implemented, you must verify signatures externally:

### Option 1: Server-side verification
Verify tokens on your backend server (Node.js, Python, Go, etc.) before passing them to MoonBit code.

### Option 2: Use Google's tokeninfo endpoint
```moonbit
let response = http_client.get(
  "https://oauth2.googleapis.com/tokeninfo?id_token=\{id_token_string}",
  headers
)?
// If successful (200 OK), the token signature is valid
```

### Option 3: Client library with signature support
Use a full OAuth2 client library in your runtime environment (JavaScript, etc.) that supports signature verification.

---

## Complete Flow Example

```moonbit
async fn main {
  let http_client = @oauth2.OAuth2HttpClient::new()
  let client_id = "your-client-id.apps.googleusercontent.com"
  let client_secret = "your-client-secret"
  let redirect_uri = "http://localhost:3000/callback"

  // 1. Fetch Discovery Document
  let discovery = @providers.google.fetch_discovery(http_client)?

  // 2. Generate Authorization URL with PKCE
  let state = @oauth2.generate_csrf_token()
  let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
  let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)

  let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(
    discovery.authorization_url(),
    @oauth2.ClientId::new(client_id),
    @oauth2.RedirectUrl::new(redirect_uri),
    [
      @oauth2.Scope::new("openid"),
      @oauth2.Scope::new("email"),
      @oauth2.Scope::new("profile"),
    ],
    state,
    pkce_challenge,
  )

  let auth_url = auth_request.build_authorization_url()
  println("Visit: \{auth_url}")

  // 3. Exchange code for tokens (after user authorizes)
  let authorization_code = "..." // From callback URL

  let token_request = @oauth2.TokenRequest::new_with_pkce(
    discovery.token_url(),
    @oauth2.ClientId::new(client_id),
    @oauth2.ClientSecret::new(client_secret),
    authorization_code,
    @oauth2.RedirectUrl::new(redirect_uri),
    pkce_verifier,
  )

  let token_response = token_request.execute(http_client)?

  // 4. Verify ID Token
  let id_token = @oidc.get_id_token_from_response(token_response)?
  @providers.google.verify_id_token(id_token, client_id, http_client, None)?

  println("Authenticated user: \{id_token.email().or(\"N/A\")}")
}
```

---

## Usage

See `examples/google/` for complete usage examples and integration guides.

## Resources

- [Google OpenID Connect Documentation](https://developers.google.com/identity/openid-connect/openid-connect)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Google Discovery Document](https://accounts.google.com/.well-known/openid-configuration)
