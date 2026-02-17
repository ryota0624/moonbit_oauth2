///| OpenID Connect Discovery Document Implementation (RFC 8414)

///|
/// DiscoveryDocument represents OpenID Connect Discovery metadata
/// See: https://openid.net/specs/openid-connect-discovery-1_0.html
pub struct DiscoveryDocument {
  // Required fields (OpenID Connect Discovery)
  issuer : String // Issuer URL (e.g., "https://accounts.google.com")
  authorization_endpoint : String // Authorization endpoint URL
  token_endpoint : String // Token endpoint URL
  jwks_uri : String // JWKS endpoint URL
  // Recommended fields
  userinfo_endpoint : String? // UserInfo endpoint URL (optional)
  scopes_supported : Array[String]? // Supported scopes (optional)
  response_types_supported : Array[String]? // Supported response types (optional)
  // Optional fields (useful for future features)
  revocation_endpoint : String? // Token revocation endpoint (optional)
  introspection_endpoint : String? // Token introspection endpoint (optional)
  code_challenge_methods_supported : Array[String]? // PKCE methods (optional)
} derive(Show)

///|
/// DiscoveryError represents errors that occur during Discovery Document parsing
pub enum DiscoveryError {
  InvalidJson(String) // JSON parsing failed
  InvalidStructure(String) // Structure validation failed
  InvalidFieldType(String) // Field has wrong type
  MissingRequiredField(String) // Required field is missing
} derive(Show, Eq)

///|
/// Convert DiscoveryError to string message
pub fn DiscoveryError::message(self : DiscoveryError) -> String {
  match self {
    InvalidJson(msg) => "Failed to parse JSON: \{msg}"
    InvalidStructure(msg) => "Invalid discovery document structure: \{msg}"
    InvalidFieldType(msg) => "Invalid field type: \{msg}"
    MissingRequiredField(msg) => "Missing required field: \{msg}"
  }
}

///|
/// Fetch Discovery Document from issuer URL
///
/// Fetches the OpenID Connect Discovery Document from the well-known endpoint:
/// {issuer_url}/.well-known/openid-configuration
///
/// # Arguments
/// * `issuer_url` - The issuer URL (e.g., "https://accounts.google.com")
/// * `http_client` - HTTP client for making requests
///
/// # Returns
/// * `Ok(DiscoveryDocument)` - Successfully fetched and parsed discovery document
/// * `Err(OAuth2Error)` - Failed to fetch or parse discovery document
///
/// # Example
/// ```moonbit nocheck
/// let http_client = @oauth2.OAuth2HttpClient::new()
/// let discovery = fetch_discovery_document("https://accounts.google.com", http_client)?
/// println("Authorization endpoint: \{discovery.authorization_endpoint}")
/// ```
pub async fn fetch_discovery_document(
  issuer_url : String,
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[DiscoveryDocument, @oauth2.OAuth2Error] {
  // Construct well-known URL
  let discovery_url = "\{issuer_url}/.well-known/openid-configuration"

  // Set up headers
  let headers : @oauth2.HttpHeaders = {}
  headers["Accept"] = "application/json"
  headers["User-Agent"] = "moonbit-oauth2/0.1.2"

  // Send GET request
  let response = match http_client.get(discovery_url, headers) {
    Ok(resp) => resp
    Err(err) =>
      return Err(
        @oauth2.OAuth2Error::new_other(
          "Failed to fetch discovery document: \{err.message()}",
        ),
      )
  }

  // Check if response is successful
  if response.is_error() {
    return Err(
      @oauth2.OAuth2Error::new_other(
        "Discovery document request failed with status \{response.status_code}",
      ),
    )
  }

  // Parse discovery document and convert DiscoveryError to OAuth2Error
  parse_discovery_document(response.body).map_err(fn(disc_err) {
    @oauth2.OAuth2Error::new_other(
      "Discovery document parsing failed: \{disc_err.message()}",
    )
  })
}

///|
/// Parse Discovery Document from JSON string
///
/// # Arguments
/// * `json_str` - JSON string containing discovery document
///
/// # Returns
/// * `Ok(DiscoveryDocument)` - Successfully parsed discovery document
/// * `Err(DiscoveryError)` - Failed to parse or missing required fields
fn parse_discovery_document(
  json_str : String,
) -> Result[DiscoveryDocument, DiscoveryError] {
  // Parse JSON
  let json = @json.parse(json_str) catch {
    e => return Err(InvalidJson(e.to_string()))
  }

  let obj = match json {
    Object(o) => o
    _ =>
      return Err(InvalidStructure("Discovery document must be a JSON object"))
  }

  // Extract required fields
  let issuer = match obj.get("issuer") {
    Some(String(s)) => s
    Some(_) => return Err(InvalidFieldType("'issuer' must be a string"))
    None => return Err(MissingRequiredField("'issuer'"))
  }

  let authorization_endpoint = match obj.get("authorization_endpoint") {
    Some(String(s)) => s
    Some(_) =>
      return Err(InvalidFieldType("'authorization_endpoint' must be a string"))
    None => return Err(MissingRequiredField("'authorization_endpoint'"))
  }

  let token_endpoint = match obj.get("token_endpoint") {
    Some(String(s)) => s
    Some(_) => return Err(InvalidFieldType("'token_endpoint' must be a string"))
    None => return Err(MissingRequiredField("'token_endpoint'"))
  }

  let jwks_uri = match obj.get("jwks_uri") {
    Some(String(s)) => s
    Some(_) => return Err(InvalidFieldType("'jwks_uri' must be a string"))
    None => return Err(MissingRequiredField("'jwks_uri'"))
  }

  // Extract optional fields
  let userinfo_endpoint = match obj.get("userinfo_endpoint") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let scopes_supported = match obj.get("scopes_supported") {
    Some(Array(arr)) => {
      let scopes : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => scopes.push(s)
          _ => ()
        }
      }
      if scopes.length() > 0 {
        Some(scopes)
      } else {
        None
      }
    }
    _ => None
  }

  let response_types_supported = match obj.get("response_types_supported") {
    Some(Array(arr)) => {
      let types : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => types.push(s)
          _ => ()
        }
      }
      if types.length() > 0 {
        Some(types)
      } else {
        None
      }
    }
    _ => None
  }

  let revocation_endpoint = match obj.get("revocation_endpoint") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let introspection_endpoint = match obj.get("introspection_endpoint") {
    Some(String(s)) => Some(s)
    _ => None
  }

  let code_challenge_methods_supported = match
    obj.get("code_challenge_methods_supported") {
    Some(Array(arr)) => {
      let methods : Array[String] = []
      for i = 0; i < arr.length(); i = i + 1 {
        match arr[i] {
          String(s) => methods.push(s)
          _ => ()
        }
      }
      if methods.length() > 0 {
        Some(methods)
      } else {
        None
      }
    }
    _ => None
  }

  // Return parsed discovery document
  Ok({
    issuer,
    authorization_endpoint,
    token_endpoint,
    jwks_uri,
    userinfo_endpoint,
    scopes_supported,
    response_types_supported,
    revocation_endpoint,
    introspection_endpoint,
    code_challenge_methods_supported,
  })
}

///|
/// Get the issuer URL
pub fn DiscoveryDocument::issuer(self : DiscoveryDocument) -> String {
  self.issuer
}

///|
/// Get the authorization endpoint URL
pub fn DiscoveryDocument::authorization_endpoint(
  self : DiscoveryDocument,
) -> String {
  self.authorization_endpoint
}

///|
/// Get the token endpoint URL
pub fn DiscoveryDocument::token_endpoint(self : DiscoveryDocument) -> String {
  self.token_endpoint
}

///|
/// Get the JWKS URI
pub fn DiscoveryDocument::jwks_uri(self : DiscoveryDocument) -> String {
  self.jwks_uri
}

///|
/// Get the UserInfo endpoint URL if available
pub fn DiscoveryDocument::userinfo_endpoint(
  self : DiscoveryDocument,
) -> String? {
  self.userinfo_endpoint
}

///|
/// Get supported scopes if available
pub fn DiscoveryDocument::scopes_supported(
  self : DiscoveryDocument,
) -> Array[String]? {
  self.scopes_supported
}

///|
/// Get supported response types if available
pub fn DiscoveryDocument::response_types_supported(
  self : DiscoveryDocument,
) -> Array[String]? {
  self.response_types_supported
}

///|
/// Convert authorization endpoint to AuthUrl
pub fn DiscoveryDocument::authorization_url(
  self : DiscoveryDocument,
) -> @oauth2.AuthUrl {
  @oauth2.AuthUrl::new(self.authorization_endpoint)
}

///|
/// Convert token endpoint to TokenUrl
pub fn DiscoveryDocument::token_url(
  self : DiscoveryDocument,
) -> @oauth2.TokenUrl {
  @oauth2.TokenUrl::new(self.token_endpoint)
}

///|
/// Convert UserInfo endpoint to UserInfoUrl if available
pub fn DiscoveryDocument::userinfo_url(
  self : DiscoveryDocument,
) -> UserInfoUrl? {
  match self.userinfo_endpoint {
    Some(url) => Some(UserInfoUrl::new(url))
    None => None
  }
}

///|
/// Google issuer URL
pub fn google_issuer_url() -> String {
  "https://accounts.google.com"
}

///|
/// Fetch Google Discovery Document
///
/// Convenience function for fetching Google's OpenID Connect Discovery Document.
///
/// # Arguments
/// * `http_client` - HTTP client for making requests
///
/// # Returns
/// * `Ok(DiscoveryDocument)` - Successfully fetched Google discovery document
/// * `Err(OAuth2Error)` - Failed to fetch or parse discovery document
///
/// # Example
/// ```moonbit nocheck
/// let http_client = @oauth2.OAuth2HttpClient::new()
/// let discovery = fetch_google_discovery(http_client)?
/// println("Google authorization endpoint: \{discovery.authorization_endpoint}")
/// ```
pub async fn fetch_google_discovery(
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[DiscoveryDocument, @oauth2.OAuth2Error] {
  fetch_discovery_document(google_issuer_url(), http_client)
}
