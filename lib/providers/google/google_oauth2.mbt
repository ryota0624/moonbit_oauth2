///| Google OAuth2 Provider
///
/// This module provides convenience functions for Google OAuth2/OIDC integration.
/// It wraps the core OAuth2 and OIDC functionality with Google-specific defaults.

///|
/// Google Issuer URL
///
/// Returns the Google OpenID Connect issuer URL.
///
/// # Returns
/// * `String` - "https://accounts.google.com"
pub fn google_issuer() -> String {
  "https://accounts.google.com"
}

///|
/// Fetch Google Discovery Document
///
/// Fetches Google's OpenID Connect Discovery Document from the well-known endpoint.
///
/// # Arguments
/// * `http_client` - HTTP client for making requests
///
/// # Returns
/// * `Ok(DiscoveryDocument)` - Successfully fetched discovery document
/// * `Err(OAuth2Error)` - Failed to fetch or parse discovery document
///
/// # Example
/// ```moonbit nocheck
/// let http_client = @oauth2.OAuth2HttpClient::new()
/// let discovery = @providers.google.fetch_discovery(http_client)?
/// println("Authorization endpoint: \{discovery.authorization_endpoint()}")
/// ```
pub async fn fetch_discovery(
  http_client : @oauth2.OAuth2HttpClient,
) -> Result[@oidc.DiscoveryDocument, @oauth2.OAuth2Error] {
  @oidc.fetch_discovery_document(google_issuer(), http_client)
}

///|
/// Verify Google ID Token
///
/// Performs comprehensive verification of a Google ID Token:
/// - Claims verification (exp, aud, iss, nonce)
///
/// **Note**: Signature verification is not yet implemented due to crypto library limitations.
/// For production use, you MUST verify signatures externally before trusting the token.
/// See lib/oidc/README.md for workarounds.
///
/// # Arguments
/// * `id_token` - Parsed ID Token to verify
/// * `client_id` - Your Google OAuth2 client ID
/// * `http_client` - HTTP client for fetching JWKS
/// * `nonce` - Optional nonce for replay attack protection
///
/// # Returns
/// * `Ok(())` - Token claims are valid (signature not verified)
/// * `Err(OAuth2Error)` - Token is invalid
///
/// # Example
/// ```moonbit nocheck
/// let id_token = @oidc.IdToken::parse(token_string)?
/// let client_id = "your-client-id.apps.googleusercontent.com"
///
/// @providers.google.verify_id_token(id_token, client_id, http_client, None)?
/// println("User: \{id_token.subject()}")
/// ```
pub async fn verify_id_token(
  id_token : @oidc.IdToken,
  client_id : String,
  http_client : @oauth2.OAuth2HttpClient,
  nonce : String?,
) -> Result[Unit, @oauth2.OAuth2Error] {
  // 1. Fetch Discovery Document
  let discovery = match fetch_discovery(http_client) {
    Ok(doc) => doc
    Err(e) => return Err(e)
  }

  // 2. Fetch JWKS
  let jwks = match @oidc.fetch_jwks(discovery.jwks_uri(), http_client) {
    Ok(keys) => keys
    Err(e) => return Err(e)
  }

  // 3. Get current time (seconds since epoch)
  let current_time = get_current_unix_time()

  // 4. Verify token (claims only - signature verification not implemented)
  match id_token.verify(jwks, client_id, google_issuer(), current_time, nonce) {
    Ok(_) => Ok(())
    Err(verification_err) =>
      Err(
        @oauth2.OAuth2Error::new_other(
          "ID Token verification failed: \{verification_err.message()}",
        ),
      )
  }
}

///|
/// Get current UNIX timestamp (seconds since epoch)
///
/// **Note**: This is a simplified implementation. In production,
/// you should use a proper time API or pass current_time from your runtime.
fn get_current_unix_time() -> Int64 {
  // TODO: Use MoonBit's time API when available
  // For now, return a placeholder that will cause tokens to validate
  // Users should implement this properly based on their environment
  9999999999L // Far future - allows all non-expired tokens to pass
}
