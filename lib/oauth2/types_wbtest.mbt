///| Tests for OAuth2 Basic Types

test "ClientId creation and retrieval" {
  let client_id = ClientId::new("test_client_id")
  assert_eq(client_id.to_string(), "test_client_id")
}

test "ClientSecret creation and retrieval" {
  let client_secret = ClientSecret::new("test_secret")
  assert_eq(client_secret.to_string(), "test_secret")
}

test "AuthUrl creation and retrieval" {
  let auth_url = AuthUrl::new("https://example.com/oauth/authorize")
  assert_eq(auth_url.to_string(), "https://example.com/oauth/authorize")
}

test "TokenUrl creation and retrieval" {
  let token_url = TokenUrl::new("https://example.com/oauth/token")
  assert_eq(token_url.to_string(), "https://example.com/oauth/token")
}

test "RedirectUrl creation and retrieval" {
  let redirect_url = RedirectUrl::new("https://myapp.com/callback")
  assert_eq(redirect_url.to_string(), "https://myapp.com/callback")
}

test "Scope creation and retrieval" {
  let scope = Scope::new("read write")
  assert_eq(scope.to_string(), "read write")
}

test "AccessToken creation and retrieval" {
  let access_token = AccessToken::new("sample_access_token")
  assert_eq(access_token.to_string(), "sample_access_token")
}

test "RefreshToken creation and retrieval" {
  let refresh_token = RefreshToken::new("sample_refresh_token")
  assert_eq(refresh_token.to_string(), "sample_refresh_token")
}

test "CsrfToken creation and retrieval" {
  let csrf_token = CsrfToken::new("random_state_value")
  assert_eq(csrf_token.to_string(), "random_state_value")
}

test "TokenResponse with all fields" {
  let access_token = AccessToken::new("test_access_token")
  let refresh_token = RefreshToken::new("test_refresh_token")

  let response = TokenResponse::new(
    access_token,
    "Bearer",
    Some(3600),
    Some(refresh_token),
    Some("read write"),
  )

  assert_eq(response.access_token().to_string(), "test_access_token")
  assert_eq(response.token_type(), "Bearer")
  assert_eq(response.expires_in(), Some(3600))
  assert_eq(
    response.refresh_token().map(fn(t) { t.to_string() }),
    Some("test_refresh_token"),
  )
  assert_eq(response.scope(), Some("read write"))
}

test "TokenResponse with minimal fields" {
  let access_token = AccessToken::new("test_access_token")
  let response = TokenResponse::new(
    access_token,
    "Bearer",
    None,
    None,
    None,
  )

  assert_eq(response.access_token().to_string(), "test_access_token")
  assert_eq(response.token_type(), "Bearer")
  assert_eq(response.expires_in(), None)
  assert_eq(response.refresh_token(), None)
  assert_eq(response.scope(), None)
}

test "ClientId equality" {
  let id1 = ClientId::new("same_id")
  let id2 = ClientId::new("same_id")
  let id3 = ClientId::new("different_id")

  assert_eq(id1, id2)
  assert_false(id1 == id3)
}
