# ryota0624/oauth2

[![Test](https://github.com/ryota0624/oauth2/actions/workflows/test.yml/badge.svg)](https://github.com/ryota0624/oauth2/actions/workflows/test.yml)

OAuth2 client library for MoonBit with support for Native and JS targets.

## Features

- ✅ **Authorization Code Flow** with PKCE support
- ✅ **Client Credentials Flow** (Machine-to-Machine)
- ✅ **Password Grant Flow** (Resource Owner Password Credentials)
- ✅ **Refresh Token** support
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

Then run:

```bash
moon install
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

## Testing

### Unit Tests

```bash
moon test
```

### Integration Tests with Keycloak

```bash
# Start Keycloak and setup test environment
./scripts/setup_keycloak.sh

# Run integration tests
./scripts/test_keycloak_moonbit.sh
```

## CI/CD

This project uses GitHub Actions for continuous integration:

- **Unit Tests**: Run on both Native and JS targets
- **Integration Tests**: Run with Keycloak using JS target after unit tests pass
- **Code Quality**: Formatting and type checking

The integration tests use the JS target to verify cross-platform compatibility.

See [`.github/workflows/test.yml`](.github/workflows/test.yml) for details.

## Documentation

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
