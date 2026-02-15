///| Authorization Request Implementation

///|
/// AuthorizationRequest represents an OAuth2 authorization request
pub struct AuthorizationRequest {
  auth_url : AuthUrl
  client_id : ClientId
  redirect_uri : RedirectUrl
  scope : Array[Scope]
  state : CsrfToken
  response_type : String
} derive(Show)

///|
/// Create a new AuthorizationRequest
pub fn AuthorizationRequest::new(
  auth_url : AuthUrl,
  client_id : ClientId,
  redirect_uri : RedirectUrl,
  scope : Array[Scope],
  state : CsrfToken,
) -> AuthorizationRequest {
  { auth_url, client_id, redirect_uri, scope, state, response_type: "code" }
}

///|
/// Generate a random CSRF token
pub fn generate_csrf_token() -> CsrfToken {
  // Simple random token generation using timestamp and counter
  // In production, use a cryptographically secure random generator
  let timestamp = "@builtin.timestamp_now"
  let random_suffix = generate_random_suffix()
  CsrfToken::new("state_\{timestamp}_\{random_suffix}")
}

///|
/// Generate a random suffix for state parameter
fn generate_random_suffix() -> String {
  // Simple counter-based approach for now
  // TODO: Use proper random number generator in production
  let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
  let result = StringBuilder::new()
  for i = 0; i < 16; i = i + 1 {
    let idx = (i * 7 + 13) % chars.length()
    result.write_char(chars[idx].unsafe_to_char())
  }
  result.to_string()
}

///|
/// Build the authorization URL with all parameters
pub fn AuthorizationRequest::build_authorization_url(
  self : AuthorizationRequest,
) -> String {
  let base_url = self.auth_url.to_string()

  // Build query parameters
  let params : Array[String] = []

  // response_type=code (required)
  params.push("response_type=\{self.response_type}")

  // client_id (required)
  let encoded_client_id = url_encode(self.client_id.to_string())
  params.push("client_id=\{encoded_client_id}")

  // redirect_uri (required)
  let encoded_redirect = url_encode(self.redirect_uri.to_string())
  params.push("redirect_uri=\{encoded_redirect}")

  // scope (optional, but usually provided)
  if self.scope.length() > 0 {
    let scope_str = build_scope_string(self.scope)
    let encoded_scope = url_encode(scope_str)
    params.push("scope=\{encoded_scope}")
  }

  // state (recommended for CSRF protection)
  let encoded_state = url_encode(self.state.to_string())
  params.push("state=\{encoded_state}")

  // Combine base URL with query parameters
  let query_string = params.join("&")
  if base_url.contains("?") {
    "\{base_url}&\{query_string}"
  } else {
    "\{base_url}?\{query_string}"
  }
}

///|
/// Build scope string from array of Scope
fn build_scope_string(scopes : Array[Scope]) -> String {
  let scope_strs : Array[String] = []
  for i = 0; i < scopes.length(); i = i + 1 {
    scope_strs.push(scopes[i].to_string())
  }
  scope_strs.join(" ")
}
