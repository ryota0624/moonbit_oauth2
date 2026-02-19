///| OIDC Token Response Helpers

///|
/// Parse ID Token from TokenResponse
/// Returns None if id_token is not present in the response
pub fn parse_id_token_from_response(
  response : @oauth2.TokenResponse,
) -> Result[IdToken?, IdTokenError] {
  match response.id_token() {
    Some(token_str) =>
      IdToken::parse(token_str).map(fn(id_token) { Some(id_token) })
    None => Ok(None)
  }
}

///|
/// Get ID Token from TokenResponse, or return error if not present
pub fn get_id_token_from_response(
  response : @oauth2.TokenResponse,
) -> Result[IdToken, IdTokenError] {
  match response.id_token() {
    Some(token_str) => IdToken::parse(token_str)
    None => Err(MissingIdToken)
  }
}
