///| OAuth2 Error Types

///|
/// OAuth2Error represents errors that can occur during OAuth2 flow
pub enum OAuth2Error {
  /// Invalid request error (RFC 6749 Section 5.2)
  InvalidRequest(String)
  /// Invalid client error (RFC 6749 Section 5.2)
  InvalidClient(String)
  /// Invalid grant error (RFC 6749 Section 5.2)
  InvalidGrant(String)
  /// Unauthorized client error (RFC 6749 Section 5.2)
  UnauthorizedClient(String)
  /// Unsupported grant type error (RFC 6749 Section 5.2)
  UnsupportedGrantType(String)
  /// Invalid scope error (RFC 6749 Section 5.2)
  InvalidScope(String)
  /// Access denied error (RFC 6749 Section 4.1.2.1)
  AccessDenied(String)
  /// Unsupported response type error (RFC 6749 Section 4.1.2.1)
  UnsupportedResponseType(String)
  /// Server error (RFC 6749 Section 4.1.2.1)
  ServerError(String)
  /// Temporarily unavailable error (RFC 6749 Section 4.1.2.1)
  TemporarilyUnavailable(String)
  /// HTTP client error
  HttpError(String)
  /// JSON parse error
  ParseError(String)
  /// Generic error
  Other(String)
} derive(Show, Eq)

///|
/// Create an OAuth2Error from error code and description
pub fn OAuth2Error::from_error_code(
  error_code : String,
  error_description : String?,
) -> OAuth2Error {
  let desc = match error_description {
    Some(d) => d
    None => ""
  }

  match error_code {
    "invalid_request" => InvalidRequest(desc)
    "invalid_client" => InvalidClient(desc)
    "invalid_grant" => InvalidGrant(desc)
    "unauthorized_client" => UnauthorizedClient(desc)
    "unsupported_grant_type" => UnsupportedGrantType(desc)
    "invalid_scope" => InvalidScope(desc)
    "access_denied" => AccessDenied(desc)
    "unsupported_response_type" => UnsupportedResponseType(desc)
    "server_error" => ServerError(desc)
    "temporarily_unavailable" => TemporarilyUnavailable(desc)
    _ => Other("Unknown error: \{error_code} - \{desc}")
  }
}

///|
/// Get error message
pub fn OAuth2Error::message(self : OAuth2Error) -> String {
  match self {
    InvalidRequest(msg) => "Invalid request: \{msg}"
    InvalidClient(msg) => "Invalid client: \{msg}"
    InvalidGrant(msg) => "Invalid grant: \{msg}"
    UnauthorizedClient(msg) => "Unauthorized client: \{msg}"
    UnsupportedGrantType(msg) => "Unsupported grant type: \{msg}"
    InvalidScope(msg) => "Invalid scope: \{msg}"
    AccessDenied(msg) => "Access denied: \{msg}"
    UnsupportedResponseType(msg) => "Unsupported response type: \{msg}"
    ServerError(msg) => "Server error: \{msg}"
    TemporarilyUnavailable(msg) => "Temporarily unavailable: \{msg}"
    HttpError(msg) => "HTTP error: \{msg}"
    ParseError(msg) => "Parse error: \{msg}"
    Other(msg) => msg
  }
}
