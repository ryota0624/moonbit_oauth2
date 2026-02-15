///| Resource Owner Password Credentials Grant Implementation (RFC 6749 Section 4.3)

///|
/// WARNING: Resource Owner Password Credentials Grant is deprecated
/// and should only be used for legacy systems. Consider using
/// Authorization Code Grant with PKCE instead.
///
/// PasswordRequest represents an OAuth2 password credentials request
/// Used when the resource owner has a trust relationship with the client
pub struct PasswordRequest {
  token_url : TokenUrl
  client_id : ClientId
  client_secret : ClientSecret?
  username : String
  password : String
  scope : Array[Scope]
  grant_type : String
} derive(Show)

///|
/// Create a new PasswordRequest
/// WARNING: This grant type is deprecated. Use Authorization Code Flow with PKCE instead.
pub fn PasswordRequest::new(
  token_url : TokenUrl,
  client_id : ClientId,
  client_secret : ClientSecret?,
  username : String,
  password : String,
  scope : Array[Scope],
) -> PasswordRequest {
  {
    token_url,
    client_id,
    client_secret,
    username,
    password,
    scope,
    grant_type: "password",
  }
}

///|
/// Build the request body for password credentials request
/// Returns application/x-www-form-urlencoded format
pub fn PasswordRequest::build_request_body(self : PasswordRequest) -> String {
  let params : Map[String, String] = {}

  // grant_type (required)
  params["grant_type"] = self.grant_type

  // username (required)
  params["username"] = self.username

  // password (required)
  params["password"] = self.password

  // client_id (required)
  params["client_id"] = self.client_id.to_string()

  // client_secret (optional)
  match self.client_secret {
    Some(secret) => params["client_secret"] = secret.to_string()
    None => ()
  }

  // scope (optional)
  if self.scope.length() > 0 {
    let scope_str = build_scope_string(self.scope)
    params["scope"] = scope_str
  }

  build_form_urlencoded_body(params)
}

///|
/// Get authorization header for Basic authentication
/// Returns None if client_secret is not provided
pub fn PasswordRequest::get_auth_header(self : PasswordRequest) -> String? {
  match self.client_secret {
    Some(secret) => Some(build_basic_auth_header(self.client_id, secret))
    None => None
  }
}

///|
/// Execute the password credentials request using HTTP client
/// Returns TokenResponse on success, OAuth2Error on failure
/// WARNING: This grant type is deprecated and should only be used for legacy systems.
pub async fn PasswordRequest::execute(
  self : PasswordRequest,
  http_client : OAuth2HttpClient,
) -> Result[TokenResponse, OAuth2Error] {
  // Build request body
  let body = self.build_request_body()

  // Set up headers
  let headers : HttpHeaders = {}
  headers["Content-Type"] = "application/x-www-form-urlencoded"
  // Optional: Use Basic authentication if client_secret is provided
  // match self.get_auth_header() {
  //   Some(auth) => headers["Authorization"] = auth
  //   None => ()
  // }

  // Send POST request
  let response = match
    http_client.post(self.token_url.to_string(), headers, body) {
    Ok(resp) => resp
    Err(err) => return Err(err)
  }

  // Check if response is successful (2xx status code)
  if response.is_error() {
    // Parse OAuth2 error from response body
    let error = parse_oauth2_error(response.body)
    return Err(error)
  }

  // Parse token response
  parse_token_response(response.body)
}
