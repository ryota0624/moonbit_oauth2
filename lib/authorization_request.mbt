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
  pkce_challenge : PkceCodeChallenge?
  nonce : Nonce? // OIDC: nonce parameter for replay attack protection
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
  {
    auth_url,
    client_id,
    redirect_uri,
    scope,
    state,
    response_type: "code",
    pkce_challenge: None,
    nonce: None,
  }
}

///|
/// Create a new AuthorizationRequest with PKCE support
pub fn AuthorizationRequest::new_with_pkce(
  auth_url : AuthUrl,
  client_id : ClientId,
  redirect_uri : RedirectUrl,
  scope : Array[Scope],
  state : CsrfToken,
  pkce_challenge : PkceCodeChallenge,
) -> AuthorizationRequest {
  {
    auth_url,
    client_id,
    redirect_uri,
    scope,
    state,
    response_type: "code",
    pkce_challenge: Some(pkce_challenge),
    nonce: None,
  }
}

///|
/// Generate a random CSRF token
/// Uses cryptographically secure random number generator (Chacha8 CSPRNG)
pub fn generate_csrf_token() -> CsrfToken {
  let timestamp = "@builtin.timestamp_now"
  let random_suffix = generate_random_suffix()
  CsrfToken::new("state_\{timestamp}_\{random_suffix}")
}

///|
/// Generate a random nonce for OIDC
/// Uses cryptographically secure random number generator (Chacha8 CSPRNG)
pub fn generate_nonce() -> Nonce {
  let timestamp = "@builtin.timestamp_now"
  let random_suffix = generate_random_suffix()
  Nonce::new("nonce_\{timestamp}_\{random_suffix}")
}

///|
/// Add nonce to an existing AuthorizationRequest (OIDC)
pub fn AuthorizationRequest::with_nonce(
  self : AuthorizationRequest,
  nonce : Nonce,
) -> AuthorizationRequest {
  { ..self, nonce: Some(nonce) }
}

///|
/// Generate a random suffix for state parameter
/// Uses cryptographically secure random number generator (Chacha8 CSPRNG)
fn generate_random_suffix() -> String {
  let r = @random.Rand::new()
  let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
  let char_count = chars.length()
  let result = StringBuilder::new()

  for i = 0; i < 16; i = i + 1 {
    let idx = r
      .uint(limit=char_count.reinterpret_as_uint())
      .reinterpret_as_int()
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

  // PKCE parameters (optional, for enhanced security)
  match self.pkce_challenge {
    Some(challenge) => {
      // code_challenge
      let encoded_challenge = url_encode(challenge.to_string())
      params.push("code_challenge=\{encoded_challenge}")

      // code_challenge_method
      params.push("code_challenge_method=\{challenge.method_string()}")
    }
    None => ()
  }

  // Nonce parameter (OIDC, for replay attack protection)
  match self.nonce {
    Some(nonce) => {
      let encoded_nonce = url_encode(nonce.to_string())
      params.push("nonce=\{encoded_nonce}")
    }
    None => ()
  }

  // Combine base URL with query parameters
  let query_string = params.join("&")
  if base_url.contains("?") {
    "\{base_url}&\{query_string}"
  } else {
    "\{base_url}?\{query_string}"
  }
}
