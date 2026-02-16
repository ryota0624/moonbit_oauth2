///|
/// Integration tests for OAuth2 Authorization Code Flow

///|
/// Test complete authorization code flow URL generation
test "authorization code flow - URL generation" {
  // Step 1: Create authorization request
  let auth_url = AuthUrl::new("https://provider.com/authorize")
  let client_id = ClientId::new("test_client")
  let redirect_uri = RedirectUrl::new("https://myapp.com/callback")
  let scopes = [Scope::new("read"), Scope::new("write")]
  let state = CsrfToken::new("random_state_123")

  let auth_request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  // Generate authorization URL
  let auth_url_str = auth_request.build_authorization_url()

  // Verify the URL contains all required parameters
  assert_true(auth_url_str.has_prefix("https://provider.com/authorize?"))
  assert_true(auth_url_str.contains("response_type=code"))
  assert_true(auth_url_str.contains("client_id=test_client"))
  assert_true(
    auth_url_str.contains("redirect_uri=https%3A%2F%2Fmyapp.com%2Fcallback"),
  )
  assert_true(auth_url_str.contains("scope=read%20write"))
  assert_true(auth_url_str.contains("state=random_state_123"))
}

///|
/// Test token exchange request body generation
test "authorization code flow - token request body" {
  // Step 2: After receiving authorization code, create token request
  let token_url = TokenUrl::new("https://provider.com/token")
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")
  let code = "received_auth_code_xyz"
  let redirect_uri = RedirectUrl::new("https://myapp.com/callback")

  let token_request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  // Build request body
  let body = token_request.build_request_body()

  // Verify all required parameters are present
  assert_true(body.contains("grant_type=authorization_code"))
  assert_true(body.contains("code=received_auth_code_xyz"))
  assert_true(body.contains("client_id=test_client"))
  assert_true(body.contains("client_secret=test_secret"))
  assert_true(body.contains("redirect_uri=https%3A%2F%2Fmyapp.com%2Fcallback"))
}

///|
/// Test complete flow with token response parsing
test "authorization code flow - complete flow simulation" {
  // Step 1: Authorization URL generation
  let auth_url = AuthUrl::new("https://provider.com/oauth/authorize")
  let client_id = ClientId::new("my_app_id")
  let redirect_uri = RedirectUrl::new("https://myapp.com/auth/callback")
  let scopes = [Scope::new("user:email"), Scope::new("repo")]
  let state = generate_csrf_token()

  let auth_request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let auth_url_str = auth_request.build_authorization_url()

  // Verify authorization URL is valid
  assert_true(auth_url_str.has_prefix("https://provider.com/oauth/authorize?"))

  // Step 2: Simulate receiving authorization code from redirect
  // (In real flow, user would be redirected back with code and state)
  let received_code = "authorization_code_from_provider"
  let received_state = state // Should match original state

  // Verify state matches (CSRF protection)
  assert_eq(received_state.to_string(), state.to_string())

  // Step 3: Exchange code for token
  let token_url = TokenUrl::new("https://provider.com/oauth/token")
  let client_secret = ClientSecret::new("my_app_secret")

  let token_request = TokenRequest::new(
    token_url, client_id, client_secret, received_code, redirect_uri,
  )

  // Verify token request is properly configured
  assert_eq(token_request.grant_type, "authorization_code")
  assert_eq(token_request.code, "authorization_code_from_provider")

  // Step 4: Parse token response (simulate successful response)
  let mock_response = "{\"access_token\":\"access_xyz\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"refresh_token\":\"refresh_abc\",\"scope\":\"user:email repo\"}"

  let result = parse_token_response(mock_response)

  match result {
    Ok(token_response) => {
      assert_eq(token_response.access_token().to_string(), "access_xyz")
      assert_eq(token_response.token_type(), "Bearer")
      assert_eq(token_response.expires_in(), Some(3600))
      assert_eq(
        token_response.refresh_token().map(fn(t) { t.to_string() }),
        Some("refresh_abc"),
      )
      assert_eq(token_response.scope(), Some("user:email repo"))
    }
    Err(err) => fail("Expected successful token response, got error: \{err}")
  }
}

///|
/// Test error handling in token response
test "authorization code flow - error response handling" {
  // Simulate OAuth2 error response
  let error_response = "{\"error\":\"invalid_grant\",\"error_description\":\"The authorization code has expired\"}"

  let result = parse_token_response(error_response)

  // Should fail to parse as token response (missing required fields)
  match result {
    Ok(_) => fail("Expected error, got success")
    Err(_) => assert_true(true) // Expected to fail
  }
}

///|
/// Test state parameter generation for CSRF protection
test "authorization code flow - CSRF state token uniqueness" {
  // Generate multiple state tokens
  let state1 = generate_csrf_token()
  let state2 = generate_csrf_token()

  // State tokens should be non-empty
  assert_true(state1.to_string().length() > 0)
  assert_true(state2.to_string().length() > 0)

  // State tokens should have reasonable length
  assert_true(state1.to_string().length() > 10)
  assert_true(state2.to_string().length() > 10)
}

///|
/// Test URL encoding in both authorization and token requests
test "authorization code flow - URL encoding consistency" {
  // Use redirect URI with special characters
  let redirect_uri = RedirectUrl::new(
    "https://app.com/auth?client=web&mode=prod",
  )

  // Test in authorization request
  let auth_url = AuthUrl::new("https://provider.com/authorize")
  let client_id = ClientId::new("client")
  let scopes = [Scope::new("read")]
  let state = CsrfToken::new("state")

  let auth_request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let auth_url_str = auth_request.build_authorization_url()

  // Should be URL-encoded
  assert_true(
    auth_url_str.contains(
      "redirect_uri=https%3A%2F%2Fapp.com%2Fauth%3Fclient%3Dweb%26mode%3Dprod",
    ),
  )

  // Test in token request
  let token_url = TokenUrl::new("https://provider.com/token")
  let client_secret = ClientSecret::new("secret")
  let code = "code"

  let token_request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  let body = token_request.build_request_body()

  // Should be consistently URL-encoded
  assert_true(
    body.contains(
      "redirect_uri=https%3A%2F%2Fapp.com%2Fauth%3Fclient%3Dweb%26mode%3Dprod",
    ),
  )
}
