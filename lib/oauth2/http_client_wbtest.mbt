///|
/// Tests for HTTP Client
test "build_form_urlencoded_body with single parameter" {
  let params : Map[String, String] = {}
  params["grant_type"] = "authorization_code"

  let body = build_form_urlencoded_body(params)
  assert_eq(body, "grant_type=authorization_code")
}

///|
test "build_form_urlencoded_body with multiple parameters" {
  let params : Map[String, String] = {}
  params["grant_type"] = "authorization_code"
  params["code"] = "test_code"
  params["redirect_uri"] = "https://example.com/callback"

  let body = build_form_urlencoded_body(params)
  // Note: Order might vary due to Map implementation
  assert_true(body.contains("grant_type=authorization_code"))
  assert_true(body.contains("code=test_code"))
  // URL encoding: : -> %3A, / -> %2F
  assert_true(
    body.contains("redirect_uri=https%3A%2F%2Fexample.com%2Fcallback"),
  )
}

///|
test "build_basic_auth_header" {
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")

  let header = build_basic_auth_header(client_id, client_secret)
  // "test_client:test_secret" in Base64 is "dGVzdF9jbGllbnQ6dGVzdF9zZWNyZXQ="
  assert_eq(header, "Basic dGVzdF9jbGllbnQ6dGVzdF9zZWNyZXQ=")
}

///|
test "base64_encode simple strings" {
  assert_eq(base64_encode("hello"), "aGVsbG8=")
  assert_eq(base64_encode("Man"), "TWFu")
  assert_eq(base64_encode("Ma"), "TWE=")
  assert_eq(base64_encode("M"), "TQ==")
}

///|
test "base64_encode oauth credentials" {
  // Common OAuth2 credential patterns
  assert_eq(base64_encode("client:secret"), "Y2xpZW50OnNlY3JldA==")
  assert_eq(base64_encode("user:pass"), "dXNlcjpwYXNz")
}

///|
test "HttpResponse is_success for 200" {
  let response = HttpResponse::new(200, {}, "")
  assert_true(response.is_success())
  assert_false(response.is_error())
}

///|
test "HttpResponse is_success for 201" {
  let response = HttpResponse::new(201, {}, "")
  assert_true(response.is_success())
  assert_false(response.is_error())
}

///|
test "HttpResponse is_error for 400" {
  let response = HttpResponse::new(400, {}, "")
  assert_false(response.is_success())
  assert_true(response.is_error())
}

///|
test "HttpResponse is_error for 500" {
  let response = HttpResponse::new(500, {}, "")
  assert_false(response.is_success())
  assert_true(response.is_error())
}

///|
test "HttpMethod to_string" {
  assert_eq(GET.to_string(), "GET")
  assert_eq(POST.to_string(), "POST")
  assert_eq(PUT.to_string(), "PUT")
  assert_eq(DELETE.to_string(), "DELETE")
}

///|
test "OAuth2HttpClient creation" {
  let _client = OAuth2HttpClient::new()
  // Just verify it can be created
  assert_true(true)
}

///|
test "url_encode basic characters" {
  assert_eq(url_encode("hello"), "hello")
  assert_eq(url_encode("Hello123"), "Hello123")
}

///|
test "url_encode special characters" {
  assert_eq(url_encode("hello world"), "hello%20world")
  assert_eq(url_encode("a+b"), "a%2Bb")
  assert_eq(url_encode("a=b"), "a%3Db")
  assert_eq(url_encode("a&b"), "a%26b")
}

///|
test "url_encode unreserved characters" {
  assert_eq(url_encode("A-Z_a.z~0"), "A-Z_a.z~0")
}

///|
test "url_encode special oauth characters" {
  // Common OAuth2 special characters
  assert_eq(
    url_encode("client_id=123&scope=read"),
    "client_id%3D123%26scope%3Dread",
  )
}

///|
test "parse_oauth2_error with error and description" {
  let json = "{\"error\":\"invalid_request\",\"error_description\":\"Missing parameter\"}"
  let error = parse_oauth2_error(json)

  match error {
    InvalidRequest(msg) => assert_eq(msg, "Missing parameter")
    _ => fail("Expected InvalidRequest error")
  }
}

///|
test "parse_oauth2_error with only error" {
  let json = "{\"error\":\"invalid_client\"}"
  let error = parse_oauth2_error(json)

  match error {
    InvalidClient(_) => assert_true(true)
    _ => fail("Expected InvalidClient error")
  }
}

///|
test "parse_oauth2_error with spaces" {
  let json = "{ \"error\" : \"access_denied\" , \"error_description\" : \"User denied\" }"
  let error = parse_oauth2_error(json)

  match error {
    AccessDenied(msg) => assert_eq(msg, "User denied")
    _ => fail("Expected AccessDenied error")
  }
}

///|
test "parse_oauth2_error invalid json" {
  let json = "not a json"
  let error = parse_oauth2_error(json)

  match error {
    ParseError(_) => assert_true(true)
    _ => fail("Expected ParseError")
  }
}

///|
test "extract_json_string_value basic" {
  assert_eq(
    extract_json_string_value("{\"key\":\"value\"}", "key"),
    Some("value"),
  )
  assert_eq(
    extract_json_string_value("{\"error\":\"invalid_request\"}", "error"),
    Some("invalid_request"),
  )
}

///|
test "extract_json_string_value with spaces" {
  assert_eq(
    extract_json_string_value("{ \"key\" : \"value\" }", "key"),
    Some("value"),
  )
}

///|
test "extract_json_string_value not found" {
  assert_eq(extract_json_string_value("{\"other\":\"value\"}", "key"), None)
}
