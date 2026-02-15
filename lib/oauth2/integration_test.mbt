///|
/// Integration tests for Authorization Code Flow
/// Requires mock-oauth2-server running on localhost:8081
///
/// To run these tests:
/// 1. Start mock server: docker compose up -d mock-oauth2
/// 2. Run tests: moon test

///|
/// Test token exchange with mock OAuth2 server
test "integration: token exchange request structure" {
  // Mock server configuration
  let token_url = TokenUrl::new("http://localhost:8081/default/token")
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")
  let code = "test_auth_code"
  let redirect_uri = RedirectUrl::new("http://localhost:3000/callback")

  // Create token request
  let token_request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  // Verify request body structure
  let body = token_request.build_request_body()
  assert_true(body.contains("grant_type=authorization_code"))
  assert_true(body.contains("code=test_auth_code"))
  assert_true(body.contains("client_id=test_client"))
}

///|
/// Test authorization URL generation for mock server
test "integration: authorization URL for mock server" {
  let auth_url = AuthUrl::new("http://localhost:8081/default/authorize")
  let client_id = ClientId::new("test_client")
  let redirect_uri = RedirectUrl::new("http://localhost:3000/callback")
  let scopes = [Scope::new("openid"), Scope::new("profile")]
  let state = CsrfToken::new("random_state_123")

  let request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let url = request.build_authorization_url()

  // Verify URL structure
  assert_true(url.has_prefix("http://localhost:8081/default/authorize?"))
  assert_true(url.contains("response_type=code"))
  assert_true(url.contains("client_id=test_client"))
  assert_true(url.contains("state=random_state_123"))
}

///|
/// Test PKCE flow with mock server
test "integration: PKCE authorization URL" {
  let auth_url = AuthUrl::new("http://localhost:8081/default/authorize")
  let client_id = ClientId::new("test_client")
  let redirect_uri = RedirectUrl::new("http://localhost:3000/callback")
  let scopes = [Scope::new("openid")]
  let state = CsrfToken::new("state123")

  // Generate PKCE verifier and challenge
  let verifier = PkceCodeVerifier::new_random()
  let challenge = PkceCodeChallenge::from_verifier_s256(verifier)

  let request = AuthorizationRequest::new_with_pkce(
    auth_url, client_id, redirect_uri, scopes, state, challenge,
  )

  let url = request.build_authorization_url()

  // Verify PKCE parameters are included
  assert_true(url.contains("code_challenge="))
  assert_true(url.contains("code_challenge_method=S256"))
}

///|
/// Test PKCE token request
test "integration: PKCE token request body" {
  let token_url = TokenUrl::new("http://localhost:8081/default/token")
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")
  let code = "test_code"
  let redirect_uri = RedirectUrl::new("http://localhost:3000/callback")

  // Use a known verifier
  let verifier = PkceCodeVerifier::new(
    "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
  )

  let request = TokenRequest::new_with_pkce(
    token_url, client_id, client_secret, code, redirect_uri, verifier,
  )

  let body = request.build_request_body()

  // Verify code_verifier is included
  assert_true(
    body.contains("code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
  )
  assert_true(body.contains("grant_type=authorization_code"))
}

///|
/// Test Client Credentials Grant request structure
test "integration: client credentials request structure" {
  let token_url = TokenUrl::new("http://localhost:8081/default/token")
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")
  let scopes = [Scope::new("api:read"), Scope::new("api:write")]

  let request = ClientCredentialsRequest::new(
    token_url, client_id, client_secret, scopes,
  )

  let body = request.build_request_body()

  // Verify request body structure
  assert_true(body.contains("grant_type=client_credentials"))
  assert_true(body.contains("client_id=test_client"))
  assert_true(body.contains("client_secret=test_secret"))
  assert_true(body.contains("scope=api%3Aread%20api%3Awrite"))
}

///|
/// Test Client Credentials Grant without scope
test "integration: client credentials without scope" {
  let token_url = TokenUrl::new("http://localhost:8081/default/token")
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")

  let request = ClientCredentialsRequest::new(
    token_url, client_id, client_secret, [],
  )

  let body = request.build_request_body()

  // Verify request body structure
  assert_true(body.contains("grant_type=client_credentials"))
  assert_true(body.contains("client_id=test_client"))
  assert_false(body.contains("scope="))
}

///|
/// Test Password Grant request structure
test "integration: password grant request structure" {
  let token_url = TokenUrl::new("http://localhost:8081/default/token")
  let client_id = ClientId::new("test_client")
  let client_secret = Some(ClientSecret::new("test_secret"))
  let username = "test_user@example.com"
  let password = "test_password"
  let scopes = [Scope::new("openid"), Scope::new("profile")]

  let request = PasswordRequest::new(
    token_url, client_id, client_secret, username, password, scopes,
  )

  let body = request.build_request_body()

  // Verify request body structure
  assert_true(body.contains("grant_type=password"))
  assert_true(body.contains("username=test_user%40example.com"))
  assert_true(body.contains("password=test_password"))
  assert_true(body.contains("client_id=test_client"))
  assert_true(body.contains("client_secret=test_secret"))
  assert_true(body.contains("scope=openid%20profile"))
}

///|
/// Test Password Grant without client_secret
test "integration: password grant without client_secret" {
  let token_url = TokenUrl::new("http://localhost:8081/default/token")
  let client_id = ClientId::new("public_client")
  let username = "test_user"
  let password = "test_password"

  let request = PasswordRequest::new(
    token_url, client_id, None, username, password, [],
  )

  let body = request.build_request_body()

  // Verify request body structure
  assert_true(body.contains("grant_type=password"))
  assert_true(body.contains("username=test_user"))
  assert_true(body.contains("password=test_password"))
  assert_true(body.contains("client_id=public_client"))
  assert_false(body.contains("client_secret="))
}
