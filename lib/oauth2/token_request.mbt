///| Token Request Implementation

///|
/// TokenRequest represents an OAuth2 token request
/// Used to exchange authorization code for access token
pub struct TokenRequest {
  token_url : TokenUrl
  client_id : ClientId
  client_secret : ClientSecret
  code : String
  redirect_uri : RedirectUrl
  grant_type : String
  pkce_verifier : PkceCodeVerifier?
} derive(Show)

///|
/// Create a new TokenRequest for authorization code grant
pub fn TokenRequest::new(
  token_url : TokenUrl,
  client_id : ClientId,
  client_secret : ClientSecret,
  code : String,
  redirect_uri : RedirectUrl,
) -> TokenRequest {
  {
    token_url,
    client_id,
    client_secret,
    code,
    redirect_uri,
    grant_type: "authorization_code",
    pkce_verifier: None,
  }
}

///|
/// Create a new TokenRequest with PKCE support
pub fn TokenRequest::new_with_pkce(
  token_url : TokenUrl,
  client_id : ClientId,
  client_secret : ClientSecret,
  code : String,
  redirect_uri : RedirectUrl,
  pkce_verifier : PkceCodeVerifier,
) -> TokenRequest {
  {
    token_url,
    client_id,
    client_secret,
    code,
    redirect_uri,
    grant_type: "authorization_code",
    pkce_verifier: Some(pkce_verifier),
  }
}

///|
/// Build the request body for token request
/// Returns application/x-www-form-urlencoded format
pub fn TokenRequest::build_request_body(self : TokenRequest) -> String {
  let params : Map[String, String] = {}

  // grant_type (required)
  params["grant_type"] = self.grant_type

  // code (required)
  params["code"] = self.code

  // redirect_uri (required)
  params["redirect_uri"] = self.redirect_uri.to_string()

  // client_id (optional if using Basic auth, but we include it)
  params["client_id"] = self.client_id.to_string()

  // client_secret (optional if using Basic auth)
  params["client_secret"] = self.client_secret.to_string()

  // PKCE code_verifier (optional, for enhanced security)
  match self.pkce_verifier {
    Some(verifier) => params["code_verifier"] = verifier.to_string()
    None => ()
  }

  build_form_urlencoded_body(params)
}

///|
/// Get authorization header for Basic authentication
pub fn TokenRequest::get_auth_header(self : TokenRequest) -> String {
  build_basic_auth_header(self.client_id, self.client_secret)
}

///|
/// Execute the token request using HTTP client
/// Returns TokenResponse on success, OAuth2Error on failure
pub async fn TokenRequest::execute(
  self : TokenRequest,
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

///|
/// Parse token response from JSON
/// Expected format: {"access_token":"...","token_type":"Bearer",...}
pub fn parse_token_response(
  json : String,
) -> Result[TokenResponse, OAuth2Error] {
  // Extract required fields
  let access_token_str = extract_json_string_value(json, "access_token")
  let token_type = extract_json_string_value(json, "token_type")

  match (access_token_str, token_type) {
    (Some(token), Some(type_)) => {
      // Extract optional fields
      let expires_in = extract_json_int_value(json, "expires_in")
      let refresh_token_str = extract_json_string_value(json, "refresh_token")
      let scope = extract_json_string_value(json, "scope")

      // Create tokens
      let access_token = AccessToken::new(token)
      let refresh_token = match refresh_token_str {
        Some(rt) => Some(RefreshToken::new(rt))
        None => None
      }

      let response = TokenResponse::new(
        access_token, type_, expires_in, refresh_token, scope,
      )
      Ok(response)
    }
    _ => Err(ParseError("Missing required fields in token response: \{json}"))
  }
}

///|
/// Extract integer value from JSON-like text
fn extract_json_int_value(json : String, key : String) -> Int? {
  // Look for "key":123 or "key": 123
  let search_pattern = "\"\{key}\""
  let mut start_index = -1

  // Find the key
  for i = 0; i < json.length() - key.length() - 2; i = i + 1 {
    let mut matches = true
    for j = 0; j < search_pattern.length(); j = j + 1 {
      if json[i + j].to_int() != search_pattern[j].to_int() {
        matches = false
        break
      }
    }
    if matches {
      start_index = i + search_pattern.length()
      break
    }
  }

  if start_index == -1 {
    return None
  }

  // Skip whitespace and colon
  while start_index < json.length() &&
        (json[start_index].to_int() == 32 || json[start_index].to_int() == 58) {
    start_index = start_index + 1
  }

  // Skip whitespace after colon
  while start_index < json.length() && json[start_index].to_int() == 32 {
    start_index = start_index + 1
  }

  // Read digits
  let mut end_index = start_index
  while end_index < json.length() {
    let ch = json[end_index].to_int()
    if ch >= 48 && ch <= 57 {
      // 0-9
      end_index = end_index + 1
    } else {
      break
    }
  }

  if end_index == start_index {
    return None
  }

  // Parse the number manually
  let num_str = json[start_index:end_index].to_string() catch {
    _ => return None
  }
  let num = parse_int_simple(num_str)
  num
}

///|
/// Simple integer parser for JSON values
fn parse_int_simple(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }

  let mut result = 0
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i].to_int()
    if ch >= 48 && ch <= 57 {
      // 0-9
      let digit = ch - 48
      result = result * 10 + digit
    } else {
      return None
    }
  }
  Some(result)
}
