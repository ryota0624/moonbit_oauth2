# Google OAuth2 Integration Guide

This guide explains how to integrate Google OAuth2/OIDC with your MoonBit application.

## Prerequisites

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google+ API (or Google People API)

### 2. Create OAuth 2.0 Credentials

1. Navigate to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Select **Web application** as the application type
4. Configure:
   - **Name**: Your app name
   - **Authorized JavaScript origins**: `http://localhost:3000` (for development)
   - **Authorized redirect URIs**: `http://localhost:3000/callback`
5. Click **Create**
6. Save your **Client ID** and **Client Secret**

⚠️ **Important**: In production, use HTTPS URLs and keep your client secret secure.

---

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

### 2. Configure environment variables

Copy `.env.example` to `.env` and fill in your values:

```bash
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=http://localhost:3000/callback
GOOGLE_SCOPES=openid email profile
```

### 3. Run the executable sample

This directory includes a complete, executable OAuth2 flow example:

```bash
# Set environment variables
export GOOGLE_CLIENT_ID='your-client-id.apps.googleusercontent.com'
export GOOGLE_CLIENT_SECRET='your-client-secret'
export GOOGLE_REDIRECT_URI='http://localhost:3000/callback'

# Run the sample (first time - generates authorization URL)
moon run -p examples/google

# The program will display an authorization URL
# Open it in your browser, authorize the app, and get the authorization code

# Set the authorization code and run again
export AUTHORIZATION_CODE='the-code-from-redirect-url'
moon run -p examples/google
```

The sample demonstrates:
- ✅ Fetching Google's Discovery Document
- ✅ Generating authorization URL with PKCE
- ✅ Exchanging authorization code for tokens
- ✅ Verifying ID Token
- ✅ Extracting user information

---

## Authorization Code Flow with PKCE

The most secure flow for web applications:

```moonbit
async fn main {
  let http_client = @oauth2.OAuth2HttpClient::new()
  let client_id = "your-client-id.apps.googleusercontent.com"
  let client_secret = "your-client-secret"
  let redirect_uri = "http://localhost:3000/callback"

  // Step 1: Fetch Google Discovery Document
  let discovery = @providers.google.fetch_discovery(http_client)?
  println("✓ Discovery document fetched")

  // Step 2: Generate authorization URL with PKCE
  let state = @oauth2.generate_csrf_token()
  let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
  let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)

  let scopes = [
    @oauth2.Scope::new("openid"),
    @oauth2.Scope::new("email"),
    @oauth2.Scope::new("profile"),
  ]

  let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(
    discovery.authorization_url(),
    @oauth2.ClientId::new(client_id),
    @oauth2.RedirectUrl::new(redirect_uri),
    scopes,
    state,
    pkce_challenge,
  )

  let auth_url = auth_request.build_authorization_url()
  println("\\nVisit this URL to authorize:")
  println("\{auth_url}")

  // Step 3: Exchange authorization code for tokens
  // (After user authorizes and is redirected back)
  let authorization_code = "..." // Extract from callback URL

  let token_request = @oauth2.TokenRequest::new_with_pkce(
    discovery.token_url(),
    @oauth2.ClientId::new(client_id),
    @oauth2.ClientSecret::new(client_secret),
    authorization_code,
    @oauth2.RedirectUrl::new(redirect_uri),
    pkce_verifier,
  )

  let token_response = token_request.execute(http_client)?
  println("✓ Tokens received")

  // Step 4: Verify ID Token
  let id_token = @oidc.get_id_token_from_response(token_response)?
  @providers.google.verify_id_token(id_token, client_id, http_client, None)?
  println("✓ ID Token verified")

  // Step 5: Access user information
  println("\\nUser Information:")
  println("  User ID: \{id_token.subject()}")
  println("  Email: \{id_token.email().or(\"N/A\")}")
  println("  Name: \{id_token.name().or(\"N/A\")}")
}
```

---

## ID Token Verification

Verify a Google ID Token:

```moonbit
async fn main {
  let http_client = @oauth2.OAuth2HttpClient::new()
  let client_id = "your-client-id.apps.googleusercontent.com"
  let id_token_string = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

  // Parse ID Token
  let id_token = @oidc.IdToken::parse(id_token_string)?

  // Verify ID Token
  @providers.google.verify_id_token(id_token, client_id, http_client, None)?

  println("✓ Token is valid!")
  println("User: \{id_token.email().or(\"N/A\")}")
}
```

⚠️ **Important**: Signature verification is not yet implemented. For production use, verify signatures externally:
- Option 1: Use Google's tokeninfo endpoint
- Option 2: Verify on server-side before passing to MoonBit
- See [lib/oidc/README.md](../../lib/oidc/README.md) for details

---

## Get User Information

Fetch additional user information from the UserInfo endpoint:

```moonbit
async fn main {
  let http_client = @oauth2.OAuth2HttpClient::new()
  let access_token = "ya29.a0AfH6SMB..." // From token response

  // Fetch Discovery Document
  let discovery = @providers.google.fetch_discovery(http_client)?

  // Fetch UserInfo
  match discovery.userinfo_url() {
    Some(userinfo_url) => {
      let request = @oidc.UserInfoRequest::new(
        userinfo_url,
        @oauth2.AccessToken::new(access_token),
      )

      let userinfo = request.execute(http_client)?
      println("✓ UserInfo retrieved")
      println("\\nUser Information:")
      println("  Subject: \{userinfo.subject()}")
      println("  Name: \{userinfo.name().or(\"N/A\")}")
      println("  Email: \{userinfo.email().or(\"N/A\")}")
      println("  Picture: \{userinfo.picture().or(\"N/A\")}")
    }
    None => println("UserInfo endpoint not available")
  }
}
```

---

## Security Best Practices

### 1. Always use PKCE
PKCE (Proof Key for Code Exchange) prevents authorization code interception attacks:

```moonbit
let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)
```

### 2. Always verify ID Tokens
Never trust an ID Token without verification:

```moonbit
@providers.google.verify_id_token(id_token, client_id, http_client, None)?
```

Checks performed:
- ✅ Expiration time (`exp`)
- ✅ Audience (`aud` matches your client_id)
- ✅ Issuer (`iss` is `https://accounts.google.com`)
- ✅ Nonce (if provided)
- ⚠️ Signature (must verify externally)

### 3. Use HTTPS in production
```moonbit
let redirect_uri = "https://yourdomain.com/callback" // Not http://
```

### 4. Keep client_secret secure
- Never expose in client-side code
- Use environment variables
- Rotate regularly

### 5. Validate state parameter
Protects against CSRF attacks:

```moonbit
let state = @oauth2.generate_csrf_token()
// Store state in session
// After callback, verify state matches
```

### 6. Use nonce for replay protection
```moonbit
let nonce = generate_random_nonce()
// Include in authorization request
// Verify in ID Token
@providers.google.verify_id_token(id_token, client_id, http_client, Some(nonce))?
```

---

## OAuth2 Scopes

Common Google OAuth2 scopes:

| Scope | Description |
|-------|-------------|
| `openid` | Required for OIDC - enables ID Token |
| `email` | Access to user's email address |
| `profile` | Access to user's basic profile (name, picture) |
| `https://www.googleapis.com/auth/userinfo.email` | Email access (alternative) |
| `https://www.googleapis.com/auth/userinfo.profile` | Profile access (alternative) |

See [Google OAuth2 Scopes](https://developers.google.com/identity/protocols/oauth2/scopes) for complete list.

---

## Troubleshooting

### "Invalid client" error

**Problem**: Google returns "invalid_client" error

**Solutions**:
1. Check client_id and client_secret are correct
2. Verify credentials in Google Cloud Console
3. Ensure OAuth client type is "Web application"

### "Redirect URI mismatch" error

**Problem**: `redirect_uri_mismatch` error during authorization

**Solutions**:
1. Redirect URI must match exactly (including `http`/`https`, port, path)
2. Add URI to **Authorized redirect URIs** in Google Cloud Console
3. Check for trailing slashes: `http://localhost:3000/callback` vs `http://localhost:3000/callback/`

### "Invalid token" error

**Problem**: ID Token verification fails

**Solutions**:
1. Token may be expired - check `exp` claim
2. Verify with correct `client_id` (must match token's `aud`)
3. Check issuer is `https://accounts.google.com`
4. For signature issues, verify externally (see lib/oidc/README.md)

### "Access denied" error

**Problem**: User denied authorization

**Solutions**:
1. This is expected behavior - handle gracefully
2. Provide clear explanation why permissions are needed
3. Allow user to retry authorization

### Discovery Document fetch fails

**Problem**: Cannot fetch `https://accounts.google.com/.well-known/openid-configuration`

**Solutions**:
1. Check network connectivity
2. Verify HTTP client configuration
3. Check for firewall/proxy issues
4. Try in browser: https://accounts.google.com/.well-known/openid-configuration

---

## Complete Flow Diagram

```
1. User clicks "Sign in with Google"
   ↓
2. App generates authorization URL (with PKCE)
   ↓
3. User redirected to Google
   ↓
4. User authorizes app
   ↓
5. Google redirects back with authorization code
   ↓
6. App exchanges code for tokens (with PKCE verifier)
   ↓
7. App receives: access_token, id_token, refresh_token
   ↓
8. App verifies ID Token
   ↓
9. App extracts user information
   ↓
10. User is authenticated!
```

---

## API Reference

See [lib/providers/google/README.md](../../lib/providers/google/README.md) for detailed API documentation.

---

## Resources

### Google Documentation
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [OpenID Connect | Sign in with Google](https://developers.google.com/identity/openid-connect/openid-connect)
- [Google Discovery Document](https://accounts.google.com/.well-known/openid-configuration)

### OIDC Specifications
- [RFC 6749: OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc6749)
- [RFC 7636: PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)

### MoonBit OAuth2 Library
- [lib/oidc/README.md](../../lib/oidc/README.md) - OIDC implementation details
- [lib/providers/google/README.md](../../lib/providers/google/README.md) - Google Provider API

---

## Support

For issues and questions:
- GitHub Issues: https://github.com/ryota0624/moonbit_oauth2/issues
- MoonBit Documentation: https://docs.moonbitlang.com/
