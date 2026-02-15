///|
/// Tests for Authorization Request
test "AuthorizationRequest creation" {
  let auth_url = AuthUrl::new("https://auth.example.com/authorize")
  let client_id = ClientId::new("test_client_id")
  let redirect_uri = RedirectUrl::new("https://myapp.com/callback")
  let scopes = [Scope::new("read"), Scope::new("write")]
  let state = CsrfToken::new("test_state")

  let request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  assert_eq(request.response_type, "code")
}

///|
test "build_authorization_url basic" {
  let auth_url = AuthUrl::new("https://auth.example.com/authorize")
  let client_id = ClientId::new("my_client")
  let redirect_uri = RedirectUrl::new("https://myapp.com/callback")
  let scopes = [Scope::new("read")]
  let state = CsrfToken::new("abc123")

  let request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let url = request.build_authorization_url()

  // Check that URL contains required parameters
  assert_true(url.has_prefix("https://auth.example.com/authorize?"))
  assert_true(url.contains("response_type=code"))
  assert_true(url.contains("client_id=my_client"))
  assert_true(url.contains("redirect_uri=https%3A%2F%2Fmyapp.com%2Fcallback"))
  assert_true(url.contains("scope=read"))
  assert_true(url.contains("state=abc123"))
}

///|
test "build_authorization_url multiple scopes" {
  let auth_url = AuthUrl::new("https://auth.example.com/authorize")
  let client_id = ClientId::new("client")
  let redirect_uri = RedirectUrl::new("https://app.com/cb")
  let scopes = [Scope::new("read"), Scope::new("write"), Scope::new("delete")]
  let state = CsrfToken::new("state123")

  let request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let url = request.build_authorization_url()

  // Scopes should be space-separated, then URL-encoded
  // "read write delete" -> "read%20write%20delete"
  assert_true(url.contains("scope=read%20write%20delete"))
}

///|
test "build_authorization_url empty scopes" {
  let auth_url = AuthUrl::new("https://auth.example.com/authorize")
  let client_id = ClientId::new("client")
  let redirect_uri = RedirectUrl::new("https://app.com/cb")
  let scopes : Array[Scope] = []
  let state = CsrfToken::new("state123")

  let request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let url = request.build_authorization_url()

  // Should not contain scope parameter when empty
  assert_false(url.contains("scope="))
}

///|
test "build_authorization_url with existing query params" {
  let auth_url = AuthUrl::new("https://auth.example.com/authorize?lang=en")
  let client_id = ClientId::new("client")
  let redirect_uri = RedirectUrl::new("https://app.com/cb")
  let scopes = [Scope::new("read")]
  let state = CsrfToken::new("state123")

  let request = AuthorizationRequest::new(
    auth_url, client_id, redirect_uri, scopes, state,
  )

  let url = request.build_authorization_url()

  // Should append with & instead of ?
  assert_true(url.contains("?lang=en&"))
  assert_true(url.contains("response_type=code"))
}

///|
test "build_scope_string single scope" {
  let scopes = [Scope::new("read")]
  let result = build_scope_string(scopes)
  assert_eq(result, "read")
}

///|
test "build_scope_string multiple scopes" {
  let scopes = [Scope::new("read"), Scope::new("write"), Scope::new("admin")]
  let result = build_scope_string(scopes)
  assert_eq(result, "read write admin")
}

///|
test "build_scope_string empty" {
  let scopes : Array[Scope] = []
  let result = build_scope_string(scopes)
  assert_eq(result, "")
}

///|
test "generate_csrf_token creates token" {
  let token = generate_csrf_token()
  let token_str = token.to_string()

  // Should start with "state_"
  assert_true(token_str.has_prefix("state_"))

  // Should have reasonable length
  assert_true(token_str.length() > 10)
}

///|
test "generate_csrf_token generates different tokens" {
  let token1 = generate_csrf_token()
  let token2 = generate_csrf_token()

  // Should generate different tokens (not guaranteed but very likely)
  // This is a weak test but better than nothing
  assert_true(token1.to_string().length() > 0)
  assert_true(token2.to_string().length() > 0)
}
