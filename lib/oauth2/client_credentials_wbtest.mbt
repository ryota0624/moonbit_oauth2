///|
/// Client Credentials Grant Tests
test "ClientCredentialsRequest::new creates correct instance" {
  let token_url = TokenUrl::new("https://example.com/token")
  let client_id = ClientId::new("my-client-id")
  let client_secret = ClientSecret::new("my-client-secret")
  let scope = [Scope::new("read"), Scope::new("write")]

  let request = ClientCredentialsRequest::new(
    token_url, client_id, client_secret, scope,
  )

  inspect(
    request.token_url,
    content=(
      #|{value: "https://example.com/token"}
    ),
  )
  inspect(
    request.client_id,
    content=(
      #|{value: "my-client-id"}
    ),
  )
  inspect(
    request.grant_type,
    content=(
      #|client_credentials
    ),
  )
  inspect(request.scope.length(), content="2")
}

///|
test "ClientCredentialsRequest::build_request_body includes grant_type" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("grant_type=client_credentials"))
}

///|
test "ClientCredentialsRequest::build_request_body includes client_id" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("client_id=client123"))
}

///|
test "ClientCredentialsRequest::build_request_body includes client_secret" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("client_secret=secret456"))
}

///|
test "ClientCredentialsRequest::build_request_body with no scope" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [],
  )

  let body = request.build_request_body()
  assert_false(body.contains("scope="))
}

///|
test "ClientCredentialsRequest::build_request_body with single scope" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [Scope::new("read")],
  )

  let body = request.build_request_body()
  assert_true(body.contains("scope=read"))
}

///|
test "ClientCredentialsRequest::build_request_body with multiple scopes" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [Scope::new("read"), Scope::new("write")],
  )

  let body = request.build_request_body()
  // Scopes are joined with space, then URL-encoded
  // Space is encoded as %20
  assert_true(body.contains("scope=read%20write"))
}

///|
test "ClientCredentialsRequest::get_auth_header returns Basic auth" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    ClientSecret::new("secret456"),
    [],
  )

  let auth_header = request.get_auth_header()
  // Basic auth format: "Basic " + base64(client_id:client_secret)
  assert_true(auth_header.has_prefix("Basic "))
}

///|
test "ClientCredentialsRequest::build_request_body properly encodes special characters" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client+special"),
    ClientSecret::new("secret&pass"),
    [],
  )

  let body = request.build_request_body()
  // + should be encoded as %2B
  assert_true(body.contains("client_id=client%2Bspecial"))
  // & should be encoded as %26
  assert_true(body.contains("client_secret=secret%26pass"))
}

///|
test "ClientCredentialsRequest::build_request_body URL encoding consistency" {
  let request = ClientCredentialsRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("test@example.com"),
    ClientSecret::new("my-secret"),
    [Scope::new("api:read"), Scope::new("api:write")],
  )

  let body = request.build_request_body()
  // @ should be encoded
  assert_true(body.contains("test%40example.com"))
  // : in scope should be encoded as %3A
  assert_true(body.contains("api%3Aread"))
  assert_true(body.contains("api%3Awrite"))
}
