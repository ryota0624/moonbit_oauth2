///| OIDC Token Response Helpers

///|
/// Parse ID Token from TokenResponse
/// Returns None if id_token is not present in the response
pub fn parse_id_token_from_response(
  response : @oauth2.TokenResponse,
) -> Result[IdToken?, @oauth2.OAuth2Error] {
  match response.id_token() {
    Some(token_str) =>
      IdToken::parse(token_str)
      .map(fn(id_token) { Some(id_token) })
      .map_err(fn(e) {
        @oauth2.OAuth2Error::new_other(
          "ID Token parsing failed: \{e.message()}",
        )
      })
    None => Ok(None)
  }
}

///|
/// Get ID Token from TokenResponse, or return error if not present
pub fn get_id_token_from_response(
  response : @oauth2.TokenResponse,
) -> Result[IdToken, @oauth2.OAuth2Error] {
  match response.id_token() {
    Some(token_str) =>
      IdToken::parse(token_str).map_err(fn(e) {
        @oauth2.OAuth2Error::new_other(
          "ID Token parsing failed: \{e.message()}",
        )
      })
    None =>
      Err(@oauth2.OAuth2Error::new_other("ID Token not present in response"))
  }
}
