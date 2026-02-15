///|
/// Tests for Token Request
test "TokenRequest creation" {
  let token_url = TokenUrl::new("https://auth.example.com/token")
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")
  let code = "auth_code_123"
  let redirect_uri = RedirectUrl::new("https://myapp.com/callback")

  let request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  assert_eq(request.grant_type, "authorization_code")
  assert_eq(request.code, "auth_code_123")
}

///|
test "build_request_body" {
  let token_url = TokenUrl::new("https://auth.example.com/token")
  let client_id = ClientId::new("my_client")
  let client_secret = ClientSecret::new("my_secret")
  let code = "code123"
  let redirect_uri = RedirectUrl::new("https://app.com/callback")

  let request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  let body = request.build_request_body()

  // Check that body contains all required parameters
  assert_true(body.contains("grant_type=authorization_code"))
  assert_true(body.contains("code=code123"))
  assert_true(body.contains("client_id=my_client"))
  assert_true(body.contains("client_secret=my_secret"))
  assert_true(body.contains("redirect_uri=https%3A%2F%2Fapp.com%2Fcallback"))
}

///|
test "get_auth_header" {
  let token_url = TokenUrl::new("https://auth.example.com/token")
  let client_id = ClientId::new("client")
  let client_secret = ClientSecret::new("secret")
  let code = "code"
  let redirect_uri = RedirectUrl::new("https://app.com/cb")

  let request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  let auth_header = request.get_auth_header()

  // Should be Base64 encoded "client:secret"
  assert_true(auth_header.has_prefix("Basic "))
}

///|
test "parse_token_response success" {
  let json = "{\"access_token\":\"token123\",\"token_type\":\"Bearer\",\"expires_in\":3600}"

  let result = parse_token_response(json)

  match result {
    Ok(response) => {
      assert_eq(response.access_token().to_string(), "token123")
      assert_eq(response.token_type(), "Bearer")
      assert_eq(response.expires_in(), Some(3600))
      assert_eq(response.refresh_token(), None)
    }
    Err(_) => fail("Expected Ok result")
  }
}

///|
test "parse_token_response with all fields" {
  let json = "{\"access_token\":\"access\",\"token_type\":\"Bearer\",\"expires_in\":7200,\"refresh_token\":\"refresh\",\"scope\":\"read write\"}"

  let result = parse_token_response(json)

  match result {
    Ok(response) => {
      assert_eq(response.access_token().to_string(), "access")
      assert_eq(response.token_type(), "Bearer")
      assert_eq(response.expires_in(), Some(7200))
      assert_eq(
        response.refresh_token().map(fn(t) { t.to_string() }),
        Some("refresh"),
      )
      assert_eq(response.scope(), Some("read write"))
    }
    Err(_) => fail("Expected Ok result")
  }
}

///|
test "parse_token_response missing access_token" {
  let json = "{\"token_type\":\"Bearer\"}"

  let result = parse_token_response(json)

  match result {
    Ok(_) => fail("Expected Err result")
    Err(err) =>
      match err {
        ParseError(_) => assert_true(true)
        _ => fail("Expected ParseError")
      }
  }
}

///|
test "parse_token_response missing token_type" {
  let json = "{\"access_token\":\"token\"}"

  let result = parse_token_response(json)

  match result {
    Ok(_) => fail("Expected Err result")
    Err(err) =>
      match err {
        ParseError(_) => assert_true(true)
        _ => fail("Expected ParseError")
      }
  }
}

///|
test "extract_json_int_value" {
  assert_eq(
    extract_json_int_value("{\"expires_in\":3600}", "expires_in"),
    Some(3600),
  )
  assert_eq(extract_json_int_value("{\"count\":123}", "count"), Some(123))
  assert_eq(extract_json_int_value("{ \"number\" : 42 }", "number"), Some(42))
}

///|
test "extract_json_int_value not found" {
  assert_eq(extract_json_int_value("{\"other\":123}", "expires_in"), None)
}

///|
test "extract_json_int_value invalid" {
  assert_eq(
    extract_json_int_value("{\"expires_in\":\"abc\"}", "expires_in"),
    None,
  )
}

///|
test "parse_int_simple valid" {
  assert_eq(parse_int_simple("123"), Some(123))
  assert_eq(parse_int_simple("0"), Some(0))
  assert_eq(parse_int_simple("9999"), Some(9999))
}

///|
test "parse_int_simple invalid" {
  assert_eq(parse_int_simple("abc"), None)
  assert_eq(parse_int_simple("12a3"), None)
  assert_eq(parse_int_simple(""), None)
}

///|
test "TokenRequest with PKCE" {
  let token_url = TokenUrl::new("https://auth.example.com/token")
  let client_id = ClientId::new("client")
  let client_secret = ClientSecret::new("secret")
  let code = "auth_code"
  let redirect_uri = RedirectUrl::new("https://app.com/callback")

  // Create PKCE verifier
  let verifier = PkceCodeVerifier::new(
    "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
  )

  let request = TokenRequest::new_with_pkce(
    token_url, client_id, client_secret, code, redirect_uri, verifier,
  )

  let body = request.build_request_body()

  // Should contain PKCE code_verifier parameter
  assert_true(
    body.contains("code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
  )
}

///|
test "TokenRequest without PKCE" {
  let token_url = TokenUrl::new("https://auth.example.com/token")
  let client_id = ClientId::new("client")
  let client_secret = ClientSecret::new("secret")
  let code = "auth_code"
  let redirect_uri = RedirectUrl::new("https://app.com/callback")

  let request = TokenRequest::new(
    token_url, client_id, client_secret, code, redirect_uri,
  )

  let body = request.build_request_body()

  // Should NOT contain code_verifier parameter
  assert_false(body.contains("code_verifier"))
}

///|
test "TokenRequest with PKCE - complete flow" {
  // Simulate complete PKCE flow
  // 1. Generate code_verifier
  let verifier = PkceCodeVerifier::new(
    "test_verifier_1234567890_abcdefghijklmno",
  )

  // 2. Create code_challenge (this would be sent in authorization request)
  let _challenge = PkceCodeChallenge::from_verifier_s256(verifier)

  // 3. Create token request with verifier
  let token_url = TokenUrl::new("https://provider.com/token")
  let client_id = ClientId::new("my_client")
  let client_secret = ClientSecret::new("my_secret")
  let code = "received_auth_code"
  let redirect_uri = RedirectUrl::new("https://app.com/callback")

  let request = TokenRequest::new_with_pkce(
    token_url, client_id, client_secret, code, redirect_uri, verifier,
  )

  let body = request.build_request_body()

  // Verify all parameters are present
  assert_true(body.contains("grant_type=authorization_code"))
  assert_true(body.contains("code=received_auth_code"))
  assert_true(
    body.contains("code_verifier=test_verifier_1234567890_abcdefghijklmno"),
  )
}
