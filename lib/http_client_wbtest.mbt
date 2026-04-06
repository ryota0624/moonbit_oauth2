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

///|
test "base64url_encode - basic strings" {
  // Base64URL encoding removes padding and uses URL-safe chars
  assert_eq(base64url_encode("hello"), "aGVsbG8") // No padding
  assert_eq(base64url_encode("Man"), "TWFu")
  assert_eq(base64url_encode("Ma"), "TWE") // No padding
  assert_eq(base64url_encode("M"), "TQ") // No padding
}

///|
test "base64url_encode - URL-safe characters" {
  // Standard Base64 uses + and /, Base64URL uses - and _
  // Test with data that would produce + and / in standard Base64

  // Character code 62 (>) maps to + in standard Base64, - in Base64URL
  // Character code 63 (?) maps to / in standard Base64, _ in Base64URL

  // Test string that produces + and / in standard Base64
  let test_str = "???>>>???"
  let result = base64url_encode(test_str)

  // Should not contain + or /
  assert_false(result.contains("+"))
  assert_false(result.contains("/"))

  // Should not contain = padding
  assert_false(result.contains("="))
}

///|
test "base64url_encode - no padding" {
  // Base64URL should not include padding characters
  let result1 = base64url_encode("M") // Would be "TQ==" in standard
  let result2 = base64url_encode("Ma") // Would be "TWE=" in standard

  assert_false(result1.contains("="))
  assert_false(result2.contains("="))
  assert_eq(result1, "TQ")
  assert_eq(result2, "TWE")
}

///|
test "base64url_encode - PKCE code_verifier example" {
  // Typical PKCE code_verifier is 43-128 characters
  // Test with a realistic example
  let code_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  let result = base64url_encode(code_verifier)

  // Should be valid Base64URL (no + / =)
  assert_false(result.contains("+"))
  assert_false(result.contains("/"))
  assert_false(result.contains("="))

  // Should have reasonable length
  assert_true(result.length() > 0)
}

///|
/// Tests for OAuth2HttpClientConfig
test "OAuth2HttpClientConfig::default creates correct config" {
  let config = OAuth2HttpClientConfig::default()

  assert_eq(config.max_retries, 3)
  assert_eq(config.base_delay_ms, 1000)
  assert_eq(config.custom_headers, None)
  assert_eq(config.user_agent, None)
  assert_eq(config.debug, false)
}

///|
test "OAuth2HttpClientConfig::builder creates default config" {
  let config = OAuth2HttpClientConfig::builder()

  assert_eq(config.max_retries, 3)
  assert_eq(config.base_delay_ms, 1000)
  assert_eq(config.custom_headers, None)
  assert_eq(config.user_agent, None)
  assert_eq(config.debug, false)
}

///|
test "OAuth2HttpClientConfig::with_max_retries updates max_retries" {
  let config = OAuth2HttpClientConfig::builder().with_max_retries(5)

  assert_eq(config.max_retries, 5)
  assert_eq(config.base_delay_ms, 1000) // Other fields unchanged
}

///|
test "OAuth2HttpClientConfig::with_base_delay_ms updates base_delay_ms" {
  let config = OAuth2HttpClientConfig::builder().with_base_delay_ms(2000)

  assert_eq(config.max_retries, 3) // Other fields unchanged
  assert_eq(config.base_delay_ms, 2000)
}

///|
test "OAuth2HttpClientConfig::with_custom_headers updates custom_headers" {
  let headers : HttpHeaders = {}
  headers["X-Custom-Header"] = "value"

  let config = OAuth2HttpClientConfig::builder().with_custom_headers(headers)

  match config.custom_headers {
    Some(h) => assert_eq(h["X-Custom-Header"], "value")
    None => fail("Expected Some(headers)")
  }
}

///|
test "OAuth2HttpClientConfig::with_user_agent updates user_agent" {
  let config = OAuth2HttpClientConfig::builder().with_user_agent("MyApp/1.0")

  match config.user_agent {
    Some(ua) => assert_eq(ua, "MyApp/1.0")
    None => fail("Expected Some(user_agent)")
  }
}

///|
test "OAuth2HttpClientConfig::with_debug updates debug" {
  let config = OAuth2HttpClientConfig::builder().with_debug(true)

  assert_eq(config.debug, true)
}

///|
test "OAuth2HttpClientConfig builder chain" {
  let headers : HttpHeaders = {}
  headers["Authorization"] = "Bearer token"

  let config = OAuth2HttpClientConfig::builder()
    .with_max_retries(5)
    .with_base_delay_ms(500)
    .with_custom_headers(headers)
    .with_user_agent("MyApp/1.0")
    .with_debug(true)

  assert_eq(config.max_retries, 5)
  assert_eq(config.base_delay_ms, 500)
  assert_eq(config.debug, true)

  match config.custom_headers {
    Some(h) => assert_eq(h["Authorization"], "Bearer token")
    None => fail("Expected Some(headers)")
  }

  match config.user_agent {
    Some(ua) => assert_eq(ua, "MyApp/1.0")
    None => fail("Expected Some(user_agent)")
  }
}

///|
test "OAuth2HttpClient::new creates client with default config" {
  let client = OAuth2HttpClient::new()

  assert_eq(client.config.max_retries, 3)
  assert_eq(client.config.base_delay_ms, 1000)
  assert_eq(client.config.debug, false)
}

///|
test "OAuth2HttpClient::new_with_config creates client with custom config" {
  let config = OAuth2HttpClientConfig::builder()
    .with_max_retries(5)
    .with_debug(true)

  let client = OAuth2HttpClient::new_with_config(config)

  assert_eq(client.config.max_retries, 5)
  assert_eq(client.config.debug, true)
}

///|
test "OAuth2HttpClient::new_with_debug creates client with debug enabled" {
  let client = OAuth2HttpClient::new_with_debug(true)

  assert_eq(client.config.debug, true)
  assert_eq(client.config.max_retries, 3) // Other fields are default
}

///|
/// Tests for merge_headers
test "merge_headers with no custom headers" {
  let base : HttpHeaders = {}
  base["Content-Type"] = "application/json"

  let result = merge_headers(base, None, None)

  assert_eq(result["Content-Type"], "application/json")
  assert_eq(result.length(), 1)
}

///|
test "merge_headers with custom headers" {
  let base : HttpHeaders = {}
  base["Content-Type"] = "application/json"

  let custom : HttpHeaders = {}
  custom["X-Custom-Header"] = "custom-value"

  let result = merge_headers(base, Some(custom), None)

  assert_eq(result["Content-Type"], "application/json")
  assert_eq(result["X-Custom-Header"], "custom-value")
  assert_eq(result.length(), 2)
}

///|
test "merge_headers with user agent" {
  let base : HttpHeaders = {}
  base["Content-Type"] = "application/json"

  let result = merge_headers(base, None, Some("MyApp/1.0"))

  assert_eq(result["Content-Type"], "application/json")
  assert_eq(result["User-Agent"], "MyApp/1.0")
  assert_eq(result.length(), 2)
}

///|
test "merge_headers base headers override custom headers" {
  let base : HttpHeaders = {}
  base["X-Header"] = "base-value"

  let custom : HttpHeaders = {}
  custom["X-Header"] = "custom-value"

  let result = merge_headers(base, Some(custom), None)

  // Base headers should override custom headers
  assert_eq(result["X-Header"], "base-value")
  assert_eq(result.length(), 1)
}

///|
test "merge_headers base headers override user agent" {
  let base : HttpHeaders = {}
  base["User-Agent"] = "BaseApp/1.0"

  let result = merge_headers(base, None, Some("CustomApp/1.0"))

  // Base headers should override user agent
  assert_eq(result["User-Agent"], "BaseApp/1.0")
  assert_eq(result.length(), 1)
}

///|
test "merge_headers with all parameters" {
  let base : HttpHeaders = {}
  base["Content-Type"] = "application/json"
  base["Authorization"] = "Bearer token"

  let custom : HttpHeaders = {}
  custom["X-Custom-Header"] = "custom-value"
  custom["X-Another-Header"] = "another-value"

  let result = merge_headers(base, Some(custom), Some("MyApp/1.0"))

  assert_eq(result["Content-Type"], "application/json")
  assert_eq(result["Authorization"], "Bearer token")
  assert_eq(result["X-Custom-Header"], "custom-value")
  assert_eq(result["X-Another-Header"], "another-value")
  assert_eq(result["User-Agent"], "MyApp/1.0")
  assert_eq(result.length(), 5)
}

///|
/// Tests for retry logic
test "calculate_backoff with retry_count=0" {
  let backoff = calculate_backoff(0, 1000)
  assert_eq(backoff, 1000) // 1000 * 2^0 = 1000
}

///|
test "calculate_backoff with retry_count=1" {
  let backoff = calculate_backoff(1, 1000)
  assert_eq(backoff, 2000) // 1000 * 2^1 = 2000
}

///|
test "calculate_backoff with retry_count=2" {
  let backoff = calculate_backoff(2, 1000)
  assert_eq(backoff, 4000) // 1000 * 2^2 = 4000
}

///|
test "calculate_backoff with retry_count=3" {
  let backoff = calculate_backoff(3, 1000)
  assert_eq(backoff, 8000) // 1000 * 2^3 = 8000
}

///|
test "calculate_backoff with different base_delay" {
  let backoff = calculate_backoff(2, 500)
  assert_eq(backoff, 2000) // 500 * 2^2 = 2000
}

///|
test "is_retryable_status 500 is retryable" {
  assert_true(is_retryable_status(500))
}

///|
test "is_retryable_status 503 is retryable" {
  assert_true(is_retryable_status(503))
}

///|
test "is_retryable_status 599 is retryable" {
  assert_true(is_retryable_status(599))
}

///|
test "is_retryable_status 400 is not retryable" {
  assert_false(is_retryable_status(400))
}

///|
test "is_retryable_status 404 is not retryable" {
  assert_false(is_retryable_status(404))
}

///|
test "is_retryable_status 200 is not retryable" {
  assert_false(is_retryable_status(200))
}

///|
test "is_retryable_status 600 is not retryable" {
  assert_false(is_retryable_status(600))
}
