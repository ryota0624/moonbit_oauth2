///| Tests for OAuth2 Error Types

test "OAuth2Error from_error_code with description" {
  let error = OAuth2Error::from_error_code(
    "invalid_request",
    Some("Missing required parameter"),
  )

  match error {
    InvalidRequest(msg) => assert_eq(msg, "Missing required parameter")
    _ => fail("Expected InvalidRequest error")
  }
}

test "OAuth2Error from_error_code without description" {
  let error = OAuth2Error::from_error_code("invalid_client", None)

  match error {
    InvalidClient(msg) => assert_eq(msg, "")
    _ => fail("Expected InvalidClient error")
  }
}

test "OAuth2Error message for InvalidRequest" {
  let error = InvalidRequest("Test error")
  assert_eq(error.message(), "Invalid request: Test error")
}

test "OAuth2Error message for AccessDenied" {
  let error = AccessDenied("User denied access")
  assert_eq(error.message(), "Access denied: User denied access")
}

test "OAuth2Error message for ServerError" {
  let error = ServerError("Internal server error")
  assert_eq(error.message(), "Server error: Internal server error")
}

test "OAuth2Error from unknown error code" {
  let error = OAuth2Error::from_error_code(
    "unknown_error",
    Some("Unknown error occurred"),
  )

  match error {
    Other(msg) =>
      assert_eq(msg, "Unknown error: unknown_error - Unknown error occurred")
    _ => fail("Expected Other error")
  }
}

test "OAuth2Error equality" {
  let error1 = InvalidRequest("Same error")
  let error2 = InvalidRequest("Same error")
  let error3 = InvalidRequest("Different error")

  assert_eq(error1, error2)
  assert_false(error1 == error3)
}

test "OAuth2Error all standard codes" {
  let test_cases : Array[(String, String)] = [
    ("invalid_request", "Invalid request: test"),
    ("invalid_client", "Invalid client: test"),
    ("invalid_grant", "Invalid grant: test"),
    ("unauthorized_client", "Unauthorized client: test"),
    ("unsupported_grant_type", "Unsupported grant type: test"),
    ("invalid_scope", "Invalid scope: test"),
    ("access_denied", "Access denied: test"),
    ("unsupported_response_type", "Unsupported response type: test"),
    ("server_error", "Server error: test"),
    ("temporarily_unavailable", "Temporarily unavailable: test"),
  ]

  for i = 0; i < test_cases.length(); i = i + 1 {
    let (code, expected_msg) = test_cases[i]
    let error = OAuth2Error::from_error_code(code, Some("test"))
    assert_eq(error.message(), expected_msg)
  }
}
