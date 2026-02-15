///| Client Credentials Grant Implementation (RFC 6749 Section 4.4)

///|
/// ClientCredentialsRequest represents an OAuth2 client credentials request
/// Used for machine-to-machine (M2M) authentication
pub struct ClientCredentialsRequest {
  token_url : TokenUrl
  client_id : ClientId
  client_secret : ClientSecret
  scope : Array[Scope]
  grant_type : String
} derive(Show)

///|
/// Create a new ClientCredentialsRequest
pub fn ClientCredentialsRequest::new(
  token_url : TokenUrl,
  client_id : ClientId,
  client_secret : ClientSecret,
  scope : Array[Scope],
) -> ClientCredentialsRequest {
  {
    token_url,
    client_id,
    client_secret,
    scope,
    grant_type: "client_credentials",
  }
}

///|
/// Build the request body for client credentials request
/// Returns application/x-www-form-urlencoded format
pub fn ClientCredentialsRequest::build_request_body(
  self : ClientCredentialsRequest,
) -> String {
  let params : Map[String, String] = {}

  // grant_type (required)
  params["grant_type"] = self.grant_type

  // client_id (required)
  params["client_id"] = self.client_id.to_string()

  // client_secret (required)
  params["client_secret"] = self.client_secret.to_string()

  // scope (optional)
  if self.scope.length() > 0 {
    let scope_str = build_scope_string(self.scope)
    params["scope"] = scope_str
  }

  build_form_urlencoded_body(params)
}

///|
/// Get authorization header for Basic authentication
pub fn ClientCredentialsRequest::get_auth_header(
  self : ClientCredentialsRequest,
) -> String {
  build_basic_auth_header(self.client_id, self.client_secret)
}

///|
/// Execute the client credentials request using HTTP client
/// Returns TokenResponse on success, OAuth2Error on failure
pub async fn ClientCredentialsRequest::execute(
  self : ClientCredentialsRequest,
  http_client : OAuth2HttpClient,
) -> Result[TokenResponse, OAuth2Error] {
  // Build request body
  let body = self.build_request_body()

  // Set up headers
  let headers : HttpHeaders = {}
  headers["Content-Type"] = "application/x-www-form-urlencoded"
  // Optional: Use Basic authentication
  // headers["Authorization"] = self.get_auth_header()

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
