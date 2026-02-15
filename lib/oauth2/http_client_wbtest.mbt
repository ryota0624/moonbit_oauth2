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
  assert_true(body.contains("redirect_uri=https://example.com/callback"))
}

///|
test "build_basic_auth_header" {
  let client_id = ClientId::new("test_client")
  let client_secret = ClientSecret::new("test_secret")

  let header = build_basic_auth_header(client_id, client_secret)
  assert_eq(header, "Basic test_client:test_secret")
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
