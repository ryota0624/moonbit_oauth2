///|
/// Password Credentials Grant Tests
test "PasswordRequest::new creates correct instance with client_secret" {
  let token_url = TokenUrl::new("https://example.com/token")
  let client_id = ClientId::new("my-client-id")
  let client_secret = Some(ClientSecret::new("my-client-secret"))
  let username = "user@example.com"
  let password = "user-password"
  let scope = [Scope::new("read"), Scope::new("write")]

  let request = PasswordRequest::new(
    token_url, client_id, client_secret, username, password, scope,
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
      #|password
    ),
  )
  inspect(request.username, content="user@example.com")
  inspect(request.scope.length(), content="2")
}

///|
test "PasswordRequest::new creates correct instance without client_secret" {
  let token_url = TokenUrl::new("https://example.com/token")
  let client_id = ClientId::new("my-client-id")
  let username = "user@example.com"
  let password = "user-password"
  let scope : Array[Scope] = []

  let request = PasswordRequest::new(
    token_url,
    client_id,
    None,
    username,
    password,
    scope,
  )

  inspect(
    request.grant_type,
    content=(
      #|password
    ),
  )
  inspect(request.username, content="user@example.com")
  inspect(
    request.client_secret,
    content=(
      #|None
    ),
  )
}

///|
test "PasswordRequest::build_request_body includes grant_type" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user@example.com",
    "password123",
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("grant_type=password"))
}

///|
test "PasswordRequest::build_request_body includes username and password" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "testuser",
    "testpass",
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("username=testuser"))
  assert_true(body.contains("password=testpass"))
}

///|
test "PasswordRequest::build_request_body includes client_id" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user",
    "pass",
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("client_id=client123"))
}

///|
test "PasswordRequest::build_request_body includes client_secret when provided" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user",
    "pass",
    [],
  )

  let body = request.build_request_body()
  assert_true(body.contains("client_secret=secret456"))
}

///|
test "PasswordRequest::build_request_body excludes client_secret when not provided" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    None,
    "user",
    "pass",
    [],
  )

  let body = request.build_request_body()
  assert_false(body.contains("client_secret="))
}

///|
test "PasswordRequest::build_request_body with no scope" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user",
    "pass",
    [],
  )

  let body = request.build_request_body()
  assert_false(body.contains("scope="))
}

///|
test "PasswordRequest::build_request_body with single scope" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user",
    "pass",
    [Scope::new("read")],
  )

  let body = request.build_request_body()
  assert_true(body.contains("scope=read"))
}

///|
test "PasswordRequest::build_request_body with multiple scopes" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user",
    "pass",
    [Scope::new("read"), Scope::new("write")],
  )

  let body = request.build_request_body()
  // Scopes are joined with space, then URL-encoded
  assert_true(body.contains("scope=read%20write"))
}

///|
test "PasswordRequest::get_auth_header returns Basic auth when client_secret is provided" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user",
    "pass",
    [],
  )

  let auth_header = request.get_auth_header()
  match auth_header {
    Some(header) => assert_true(header.has_prefix("Basic "))
    None => assert_true(false)
  }
}

///|
test "PasswordRequest::get_auth_header returns None when client_secret is not provided" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    None,
    "user",
    "pass",
    [],
  )

  let auth_header = request.get_auth_header()
  inspect(
    auth_header,
    content=(
      #|None
    ),
  )
}

///|
test "PasswordRequest::build_request_body properly encodes special characters in credentials" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("client123"),
    Some(ClientSecret::new("secret456")),
    "user@example.com",
    "pass&word",
    [],
  )

  let body = request.build_request_body()
  // @ should be encoded as %40
  assert_true(body.contains("username=user%40example.com"))
  // & should be encoded as %26
  assert_true(body.contains("password=pass%26word"))
}

///|
test "PasswordRequest::build_request_body URL encoding consistency" {
  let request = PasswordRequest::new(
    TokenUrl::new("https://example.com/token"),
    ClientId::new("test+client"),
    None,
    "user name",
    "pass word",
    [Scope::new("api:read")],
  )

  let body = request.build_request_body()
  // + should be encoded as %2B
  assert_true(body.contains("client_id=test%2Bclient"))
  // Space should be encoded as %20
  assert_true(body.contains("username=user%20name"))
  assert_true(body.contains("password=pass%20word"))
  // : in scope should be encoded as %3A
  assert_true(body.contains("scope=api%3Aread"))
}
