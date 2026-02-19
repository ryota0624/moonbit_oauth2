# ryota0624/oauth2

[![Test](https://github.com/ryota0624/oauth2/actions/workflows/test.yml/badge.svg)](https://github.com/ryota0624/oauth2/actions/workflows/test.yml)

> **⚠️ ALPHA VERSION**
> This library is currently in alpha stage. APIs may change without notice.
> Not recommended for production use yet.

OAuth2 client library for MoonBit with support for Native and JS targets.

## Features

- ✅ **Authorization Code Flow** with PKCE support
- ✅ **Client Credentials Flow** (Machine-to-Machine)
- ✅ **Password Grant Flow** (Resource Owner Password Credentials)
- ✅ **Refresh Token** support
- ✅ **OpenID Connect (OIDC)** support with ID Token verification
- ✅ **Google OAuth2** integration with discovery document and JWKS
- ✅ **CSRF protection** with secure token generation
- ✅ **Cryptographically secure random** number generation (Chacha8 CSPRNG)
- ✅ **Type-safe** API with proper error handling
- ✅ **Cross-platform** (Native and JS targets)

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "ryota0624/oauth2": "*"
  }
}
```

## Quick Start

### Client Credentials Flow

```moonbit
let token_url = @oauth2.TokenUrl::new("https://oauth.example.com/token")
let client_id = @oauth2.ClientId::new("your-client-id")
let client_secret = @oauth2.ClientSecret::new("your-client-secret")
let scopes = [@oauth2.Scope::new("read"), @oauth2.Scope::new("write")]

let request = @oauth2.ClientCredentialsRequest::new(
  token_url,
  client_id,
  client_secret,
  scopes,
)

let http_client = @oauth2.OAuth2HttpClient::new()
let result = request.execute(http_client)

match result {
  Ok(response) => {
    let access_token = response.access_token()
    println("Access Token: \{access_token}")
  }
  Err(error) => {
    println("Error: \{error.message()}")
  }
}
```

### Authorization Code Flow with PKCE

```moonbit
// 1. Generate authorization URL
let auth_url = @oauth2.AuthUrl::new("https://oauth.example.com/authorize")
let client_id = @oauth2.ClientId::new("your-client-id")
let redirect_uri = @oauth2.RedirectUrl::new("http://localhost:3000/callback")
let scopes = [@oauth2.Scope::new("openid"), @oauth2.Scope::new("profile")]
let state = @oauth2.generate_csrf_token()

let pkce_verifier = @oauth2.PkceCodeVerifier::new_random()
let pkce_challenge = @oauth2.PkceCodeChallenge::from_verifier_s256(pkce_verifier)

let auth_request = @oauth2.AuthorizationRequest::new_with_pkce(
  auth_url,
  client_id,
  redirect_uri,
  scopes,
  state,
  pkce_challenge,
)

let authorization_url = auth_request.build_authorization_url()
// Redirect user to authorization_url

// 2. Exchange authorization code for token
let token_url = @oauth2.TokenUrl::new("https://oauth.example.com/token")
let client_secret = @oauth2.ClientSecret::new("your-client-secret")
let code = "authorization-code-from-callback"

let token_request = @oauth2.TokenRequest::new_with_pkce(
  token_url,
  client_id,
  client_secret,
  code,
  redirect_uri,
  pkce_verifier,
)

let http_client = @oauth2.OAuth2HttpClient::new()
let result = token_request.execute(http_client)
```

### Google OAuth2 Integration

```moonbit
let http_client = @oauth2.OAuth2HttpClient::new()
let client_id = "your-client-id.apps.googleusercontent.com"
let client_secret = "your-client-secret"
let redirect_uri = "http://localhost:3000/callback"

// 1. Fetch Google Discovery Document
let discovery = @providers.google.fetch_discovery(http_client)?

// 2. Generate authorization URL with PKCE
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
// Redirect user to auth_url

// 3. Exchange authorization code for tokens
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

println("User ID: \{id_token.subject()}")
println("Email: \{id_token.email().or(\"N/A\")}")
```

See [Google OAuth2 Integration Guide](examples/google/README.md) for detailed instructions.

## Testing

### Unit Tests

```bash
moon test
```

### Integration Tests with Keycloak

#### OAuth2 Tests

```bash
# Start Keycloak and setup test environment
./scripts/setup_keycloak.sh

# Run OAuth2 integration tests
./scripts/test_keycloak_moonbit.sh
```

#### OIDC Verification Tests

```bash
# Run OIDC verification tests
./scripts/verify_oidc.sh
```

See [OIDC Verification Guide](docs/verification/oidc_verification_guide.md) for detailed instructions.

## CI/CD

This project uses GitHub Actions for continuous integration:

- **Unit Tests**: Run on both Native and JS targets
- **Integration Tests**: Run with Keycloak using JS target after unit tests pass
- **Code Quality**: Formatting and type checking

The integration tests use the JS target to verify cross-platform compatibility.

See [`.github/workflows/test.yml`](.github/workflows/test.yml) for details.

## Documentation

- [Google OAuth2 Integration Guide](examples/google/README.md) - Complete guide for Google Sign-In
- [Google Provider API Reference](lib/providers/google/README.md) - API documentation
- [OIDC Library Documentation](lib/oidc/README.md) - OpenID Connect implementation
- [Keycloak Verification Guide](docs/testing/keycloak_verification_guide.md) - Comprehensive testing guide
- [CLAUDE.md](CLAUDE.md) - Development guidelines
- [Todo.md](Todo.md) - Implementation roadmap

## Architecture

- **lib/oauth2/** - Core OAuth2 library
  - `types.mbt` - Type definitions (ClientId, AccessToken, etc.)
  - `client_credentials.mbt` - Client Credentials Flow
  - `password_request.mbt` - Password Grant Flow
  - `authorization_request.mbt` - Authorization Code Flow
  - `token_request.mbt` - Token exchange
  - `pkce.mbt` - PKCE implementation
  - `http_client.mbt` - HTTP client abstraction

- **lib/oidc/** - OpenID Connect support
  - `discovery.mbt` - Discovery Document (RFC 8414)
  - `jwks.mbt` - JSON Web Key Set (RFC 7517)
  - `id_token.mbt` - ID Token parsing and verification
  - `userinfo.mbt` - UserInfo endpoint support

- **lib/providers/google/** - Google OAuth2 provider
  - `google_oauth2.mbt` - Google-specific helpers
  - See [Google Provider API](lib/providers/google/README.md)

- **lib/keycloak_test/** - Integration test suite
  - Tests all OAuth2 flows with real Keycloak server
  - Includes UserInfo endpoint verification

## Security

- PKCE (Proof Key for Code Exchange) for Authorization Code Flow
- CSRF protection with cryptographically secure tokens
- Chacha8 CSPRNG for random number generation
- Type-safe API prevents common security mistakes

## License

Apache-2.0

## Contributing

Contributions are welcome! Please see [CLAUDE.md](CLAUDE.md) for development guidelines.
